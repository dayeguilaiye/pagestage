import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'encoding/gb18030.dart';
import 'package:path/path.dart' as p;

import 'local_store.dart';
import 'epub.dart';
import 'example_library.dart';
import 'models/book.dart';
import 'models/cast.dart';
import 'bookshelf.dart';
import 'audio_repository.dart';
import 'book_package.dart';
import 'performance.dart';
import 'script_repository.dart';
import 'synthesizer.dart';

/// Imports local TXT/EPUB novels and merges subsequent editions atomically.
class Library implements Bookshelf {
  Library(this.store, {this.pickFile});
  final LocalStore store;

  /// App supplies the system picker; CLI supplies a path to [importTxt].
  final Future<String?> Function()? pickFile;

  /// App coordinates playback and scheduler checkpoints around an update.
  Future<void> Function(String bookId, Future<void> Function() action)?
  editBook;
  Future<void> _imports = Future.value();

  @override
  void addListener(void Function() listener) => store.addListener(listener);
  @override
  void removeListener(void Function() listener) =>
      store.removeListener(listener);

  @override
  Future<List<ShelfBook>> books() async {
    final rows = await store.list('books');
    rows.sort(
      (a, b) => ((b['importedAt'] as int?) ?? 0).compareTo(
        (a['importedAt'] as int?) ?? 0,
      ),
    );
    return rows.map((row) => _shelfBook(Book.fromJson(row))).toList();
  }

  ShelfBook _shelfBook(Book book) => ShelfBook(
    id: book.id,
    title: book.title,
    language: book.language == 'zh'
        ? BookLanguage.chinese
        : BookLanguage.english,
    chapterCount: book.chapters.length,
  );

  @override
  Future<ImportOutcome> importBook({
    Future<bool> Function(String title)? confirmReplace,
  }) => _import(pickFile, confirmReplace);

  @override
  Future<ImportOutcome> importPath(
    String path, {
    Future<bool> Function(String title)? confirmReplace,
  }) => _import(() async => path, confirmReplace);

  Future<ImportOutcome> _import(
    Future<String?> Function()? choose,
    Future<bool> Function(String title)? confirmReplace,
  ) async {
    String? path;
    try {
      path = await choose?.call();
      if (path == null) return const ImportCancelled();
      final extension = p.extension(path).toLowerCase();
      if (extension == BookPackages.extension) {
        return await _importPackage(path, confirmReplace);
      }
      if (!['.txt', '.epub'].contains(extension)) {
        return ImportFailed(p.basename(path), ImportFailure.unsupportedFormat);
      }
      final result = await importFile(path);
      return result.updated
          ? BookUpdated(
              _shelfBook(result.book),
              addedChapters: result.addedChapters,
              changedChapters: result.changedChapters,
            )
          : BookImported(_shelfBook(result.book));
    } on ProtectedEpub {
      return ImportFailed(
        path == null ? '' : p.basename(path),
        ImportFailure.drmProtected,
      );
    } on FormatException catch (error) {
      return ImportFailed(
        path == null ? '' : p.basename(path),
        error.message == 'The book is empty.'
            ? ImportFailure.empty
            : ImportFailure.unreadable,
      );
    } catch (_) {
      return ImportFailed(
        path == null ? '' : p.basename(path),
        ImportFailure.unreadable,
      );
    }
  }

  Future<ImportOutcome> _importPackage(
    String path,
    Future<bool> Function(String title)? confirmReplace,
  ) async {
    try {
      final imported = await importPackage(
        path,
        confirmReplace: confirmReplace,
      );
      if (imported == null) return const ImportCancelled();
      return PackageImported(
        _shelfBook(imported.book),
        scriptChapters: imported.summary.scriptChapters.length,
        audioChapters: imported.summary.audioChapters.length,
        replaced: imported.replaced,
      );
    } catch (_) {
      return ImportFailed(p.basename(path), ImportFailure.invalidPackage);
    }
  }

  /// Installs a script or audio package, after any other import under way.
  /// Returns null when its book is on the shelf and [confirmReplace] is
  /// missing or declines.
  Future<BookPackageImport?> importPackage(
    String path, {
    Future<bool> Function(String title)? confirmReplace,
  }) {
    final packages = BookPackages(store);
    final result = _imports.then((_) async {
      try {
        return await packages.import(path, edit: editBook);
      } on BookPackageConflict catch (conflict) {
        if (confirmReplace == null || !await confirmReplace(conflict.title)) {
          return null;
        }
        return packages.import(path, replace: true, edit: editBook);
      }
    });
    _imports = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<List<ChapterEntry>> chapters(String bookId) async {
    final book = await getBook(bookId);
    final cast = await CastRepository(store).get(bookId);
    final audio = AudioRepository(store);
    final mode = (await PerformanceRepository(store).get(bookId)).mode;
    return [
      for (final chapter in book.chapters)
        ChapterEntry(
          number: chapter.number,
          title: chapter.title,
          volume: chapter.volume,
          state: await _state(
            bookId,
            chapter,
            cast.profiledThrough,
            audio,
            mode,
          ),
        ),
    ];
  }

  Future<ChapterState> _state(
    String bookId,
    Chapter chapter,
    int profiledThrough,
    AudioRepository audio,
    PerformanceMode mode,
  ) async {
    final script = await ScriptRepository(store).get(bookId, chapter.number);
    if (script != null && script.sourceTextHash == chapter.textHash) {
      return await audio.isComplete(script, mode: mode)
          ? ChapterState.synthesized
          : ChapterState.directed;
    }
    return chapter.number <= profiledThrough
        ? ChapterState.profiled
        : ChapterState.unprofiled;
  }

  @override
  Future<List<String>> paragraphs(String bookId, int chapter) async =>
      (await getBook(bookId))
          .chapter(chapter)
          .text
          .split(RegExp(r'\r?\n'))
          .where((paragraph) => paragraph.trim().isNotEmpty)
          .toList();

  @override
  Future<void> deleteBook(String bookId) async {
    // Collect referenced files before removing their ownership records. Shared
    // legacy caches remain if another book's playlist references them.
    final owned = <String>{};
    final shared = <String>{};
    for (final row in await store.list('audio')) {
      final target = row['bookId'] == bookId ? owned : shared;
      final audio = ChapterAudio.fromJson(row);
      if (audio.path != null) target.add(audio.path!);
      for (final item in audio.utterances) {
        target.addAll([item.audioPath, item.rawAudioPath]);
      }
    }
    for (final collection in ['voices', 'voiceCandidates']) {
      for (final row in await store.list(collection)) {
        final voice = collection == 'voices' ? row : (row['voice'] as Map);
        final path = voice['samplePath'] as String?;
        if (path != null) {
          (voice['bookId'] == bookId ? owned : shared).add(path);
        }
      }
    }
    // Only generated files in the data directory are owned by the library.
    // User-selected source files and external CLI exports remain user-owned.
    final root = p.normalize(p.absolute(p.dirname(store.path)));
    for (final path in owned.difference(shared)) {
      final absolute = p.normalize(p.absolute(path));
      if (p.isWithin(root, absolute) && p.extension(absolute) == '.wav') {
        final file = File(absolute);
        if (await file.exists()) await file.delete();
      }
    }
    final directory = AudioRepository(store).bookDirectory(bookId);
    if (await directory.exists()) await directory.delete(recursive: true);
    await store.deleteBook(bookId);
  }

  Future<Book> importTxt(String path, {String? title}) async =>
      (await importFile(path, title: title)).book;

  Future<LibraryImport> importFile(String path, {String? title}) {
    final result = _imports.then((_) => _importFile(path, title: title));
    _imports = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<LibraryImport> _importFile(String path, {String? title}) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    late List<Chapter> chapters;
    late String identity;
    // A TXT's decoded text, to recognise chapters split from it before.
    String? source;
    if (p.extension(path).toLowerCase() == '.epub') {
      final epub = EpubReader(bytes).read();
      chapters = epub.chapters;
      title ??= epub.title;
      identity = jsonEncode(chapters.map((c) => c.text).toList());
    } else if (p.extension(path).toLowerCase() == '.txt') {
      String text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        text = decodeGb18030(bytes);
      }
      if (text.startsWith('\ufeff')) text = text.substring(1);
      if (text.trim().isEmpty) {
        throw const FormatException('The book is empty.');
      }
      chapters = _chapters(text);
      identity = text;
      source = text;
    } else {
      throw const FormatException('Supported formats are TXT and EPUB.');
    }
    final examples = await ExampleLibrary.bookIds(store);
    var id = _bookId(identity);
    // A reader's copy of a bundled example is a book of its own: the sample
    // keeps its one narrated chapter, and this file keeps updating the copy.
    if (examples.contains(id)) id = _bookId('copy of $id');
    final books = await listBooks();
    Book? previous = books.where((b) => b.id == id).firstOrNull;
    var shift = 0;
    if (previous != null) {
      // The same file again. If an earlier version split it into chapters
      // differently, keep that split so scripts and audio keep their chapter.
      if (source != null && _splits(source, previous.chapters)) {
        chapters = previous.chapters;
      }
    } else {
      final opening = source != null && _opens(chapters);
      final matches = [
        for (final book in books)
          if (!examples.contains(book.id))
            if (_alignment(book.chapters, chapters, opening: opening)
                case final shift?)
              (book: book, shift: shift),
      ];
      if (matches.length == 1) {
        previous = matches.single.book;
        shift = matches.single.shift;
      }
    }
    // An opening only one edition has never moves the other chapters: a new
    // one is left out, an old one is kept.
    if (shift < 0) {
      chapters = [for (final c in chapters.skip(1)) _renumbered(c, -1)];
    } else if (shift > 0) {
      chapters = [
        previous!.chapters.first,
        for (final c in chapters) _renumbered(c, 1),
      ];
    }
    final changed = <int>[];
    final merged = <Chapter>[];
    for (final chapter in chapters) {
      final old = previous != null && chapter.number <= previous.chapters.length
          ? previous.chapter(chapter.number)
          : null;
      if (old != null && _body(old.text) == _body(chapter.text)) {
        merged.add(
          Chapter(
            number: old.number,
            title: chapter.title,
            text: old.text,
            volume: chapter.volume,
          ),
        );
      } else {
        merged.add(chapter);
        if (old != null) changed.add(chapter.number);
      }
    }
    // A shorter copy never discards the reader's already-imported tail.
    if (previous != null) {
      merged.addAll(previous.chapters.skip(chapters.length));
    }
    final book = Book(
      id: previous?.id ?? id,
      title: title?.isNotEmpty == true
          ? title!
          : previous?.title ?? p.basenameWithoutExtension(path),
      language:
          RegExp(r'[\u3400-\u9fff]').hasMatch(merged.map((c) => c.text).join())
          ? 'zh'
          : 'en',
      sourcePath: file.absolute.path,
      chapters: merged,
    );
    final added = previous == null
        ? 0
        : (chapters.length - previous.chapters.length).clamp(
            0,
            chapters.length,
          );
    Future<void> save() => store.transaction(() async {
      for (final number in changed) {
        await store.delete('scripts', '${book.id}:$number');
        for (final mode in PerformanceMode.values) {
          await store.delete('audio', '${book.id}:$number:${mode.name}');
        }
        for (final row in await store.list('tasks')) {
          if (row['bookId'] == book.id &&
              row['chapter'] == number &&
              row['kind'] != 'profile') {
            await store.delete('tasks', row['id'] as String);
          }
        }
      }
      if (changed.isNotEmpty) {
        final bookmark = await store.get('listening', book.id);
        if (bookmark != null && changed.contains(bookmark['chapter'])) {
          await store.put('listening', book.id, {
            ...bookmark,
            'line': 0,
            'sourceOffset': 0,
          });
        }
      }
      await store.put('books', book.id, {
        ...book.toJson(),
        'importedAt': DateTime.now().microsecondsSinceEpoch,
      });
    });
    if (previous != null && editBook != null) {
      await editBook!(book.id, save);
    } else {
      await save();
    }
    return LibraryImport(
      book,
      updated: previous != null,
      addedChapters: added,
      changedChapters: List.unmodifiable(changed),
    );
  }

  String _body(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

  static String _bookId(String identity) =>
      sha256.convert(utf8.encode(identity)).toString().substring(0, 24);

  static Chapter _renumbered(Chapter chapter, int by) => Chapter(
    number: chapter.number + by,
    title: chapter.title,
    text: chapter.text,
    volume: chapter.volume,
  );

  /// Whether [chapters] are pieces of [text] in order: what an import of
  /// this text made, even under earlier splitting rules.
  static bool _splits(String text, List<Chapter> chapters) {
    var offset = 0;
    for (final chapter in chapters) {
      final at = text.indexOf(chapter.text, offset);
      if (at < 0) return false;
      offset = at + chapter.text.length;
    }
    return true;
  }

  /// How [fresh]'s chapter numbers line up with [old]'s when their first
  /// three chapters agree, or null when they are different books. An opening
  /// may be on one side only ([opening] says whether [fresh] has one): the
  /// result is then -1 (leave the new one out) or 1 (keep the old one).
  int? _alignment(
    List<Chapter> old,
    List<Chapter> fresh, {
    required bool opening,
  }) {
    bool agree(int o, int f) =>
        old.length >= o + 3 &&
        fresh.length >= f + 3 &&
        List.generate(
          3,
          (i) => _body(old[o + i].text) == _body(fresh[f + i].text),
        ).every((same) => same);
    if (agree(0, 0)) return 0;
    final oldOpening = _opens(old);
    if (opening && oldOpening && agree(1, 1)) return 0;
    if (opening && agree(0, 1)) return -1;
    if (oldOpening && agree(1, 0)) return 1;
    return null;
  }

  /// Text before a TXT's first heading, kept as chapter one when it says more
  /// than a title line: a synopsis, or a prologue without a heading.
  static const _openings = {'开篇', 'Opening'};
  static bool _opens(List<Chapter> chapters) =>
      chapters.isNotEmpty && _openings.contains(chapters.first.title);

  Future<Book> getBook(String id) async {
    final data = await store.get('books', id);
    if (data == null) throw StateError('Book not found: $id');
    return Book.fromJson(data);
  }

  /// Chapter count without decoding the book's text.
  Future<int> chapterCount(String id) async {
    final count = await store.arrayLength('books', id, r'$.chapters');
    if (count == null) throw StateError('Book not found: $id');
    return count;
  }

  Future<List<Book>> listBooks() async =>
      (await store.list('books')).map(Book.fromJson).toList();

  /// 「第X章」「第X回」 and 「Chapter N」 heading lines.
  static final _numberedHeading = RegExp(
    r'^[ \t\u3000]*(?:第[〇零一二三四五六七八九十百千万两0-9]+[章回](?:[ \t\u3000:：.、—-]+[^\r\n]*)?|Chapter[ \t]+(?:[0-9]+|[IVXLCDM]+)(?:[. :—-][^\r\n]*)?)[ \t]*(?:\r?\n|$)',
    multiLine: true,
    caseSensitive: false,
  );

  /// Sections that web novels head with a word on a line of its own, maybe
  /// numbered or titled: 「楔子」「番外一 重逢」「尾声：归来」「Epilogue」.
  /// Only a short line is a heading, so a paragraph opening with 序言 stays
  /// body text.
  static final _namedHeading = RegExp(
    r'^[ \t\u3000]*(?:最终章|序章|序言|序|楔子|引子|前言|后记|尾声|终章|番外篇?|Prologue|Epilogue|Interlude)[〇零一二三四五六七八九十百千万两0-9]*(?:[ \t\u3000:：.．、·・—–-]+[^\r\n]*)?[ \t]*(?:\r?\n|$)',
    multiLine: true,
    caseSensitive: false,
  );
  static const _namedHeadingLength = 30;

  /// 「第X卷」 lines group chapters and are neither a chapter nor its text.
  static final _volumeHeading = RegExp(
    r'^[ \t\u3000]*第[〇零一二三四五六七八九十百千万两0-9]+卷(?:[ \t\u3000:：.、—-]+[^\r\n]*)?[ \t]*(?:\r?\n|$)',
    multiLine: true,
  );
  static final _cjk = RegExp(r'[\u3400-\u9fff]');

  List<Chapter> _chapters(String text) {
    final chinese = _cjk.hasMatch(text);
    final numbered = _numberedHeading.allMatches(text).toList();
    // Named lines only frame numbered chapters. In text without them (say
    // "Chapter One" headings), a lone Prologue would make the whole book one
    // chapter, so that text is split by length instead.
    final named = {
      if (numbered.isNotEmpty)
        for (final match in _namedHeading.allMatches(text))
          if (match.group(0)!.trim().runes.length <= _namedHeadingLength) match,
    };
    final headings = [...numbered, ...named]
      ..sort((a, b) => a.start.compareTo(b.start));
    final volumes = _volumeHeading.allMatches(text).toList();
    final chapters = <Chapter>[];
    if (headings.isNotEmpty) {
      final first =
          volumes.isNotEmpty && volumes.first.start < headings.first.start
          ? volumes.first.start
          : headings.first.start;
      final opening = text.substring(0, first);
      if (opening.replaceAll(RegExp(r'\s'), '').runes.length >= 20) {
        chapters.add(
          Chapter(number: 1, title: chinese ? '开篇' : 'Opening', text: opening),
        );
      }
    }
    for (var i = 0; i < headings.length; i++) {
      final heading = headings[i];
      var end = i + 1 < headings.length ? headings[i + 1].start : text.length;
      String? volume;
      for (final grouping in volumes) {
        if (grouping.start < heading.start) volume = grouping.group(0)!.trim();
        if (grouping.start >= heading.end && grouping.start < end) {
          end = grouping.start;
        }
      }
      final body = text.substring(heading.end, end);
      // A named line with nothing under it only labels what follows.
      if (body.trim().isEmpty && named.contains(heading)) continue;
      chapters.add(
        Chapter(
          number: chapters.length + 1,
          title: heading.group(0)!.trim(),
          text: body,
          volume: volume,
        ),
      );
    }
    if (chapters.isNotEmpty) return chapters;
    final runes = text.runes.toList();
    for (var start = 0; start < runes.length;) {
      var end = _untitledEnd(runes, start);
      // Trailing blank space joins the last chapter instead of being one.
      if (runes.skip(end).every(_isSpace)) end = runes.length;
      final number = chapters.length + 1;
      chapters.add(
        Chapter(
          number: number,
          title: chinese ? '第$number章' : 'Chapter $number',
          text: String.fromCharCodes(runes, start, end),
        ),
      );
      start = end;
    }
    return chapters;
  }

  static const _untitledLength = 5000;
  static const _untitledReach = 1500;
  static final _stops = '。！？.!?'.runes.toSet();
  static final _closers = '"\'”’」』》）)]】'.runes.toSet();

  /// Where a chapter of a TXT without headings, starting at [start], ends:
  /// near [_untitledLength] code points (so a surrogate pair is never split),
  /// at the nearest line break within [_untitledReach], looking back first
  /// and then ahead; else at the nearest sentence end, the same way; else
  /// right at the mark.
  static int _untitledEnd(List<int> runes, int start) {
    if (runes.length - start <= _untitledLength) return runes.length;
    final mark = start + _untitledLength;
    final last = min(runes.length, mark + _untitledReach);
    final candidates = [
      for (var i = mark; i > mark - _untitledReach; i--) i,
      for (var i = mark + 1; i <= last; i++) i,
    ];
    for (final (endsAt, trailing) in [
      // Blank lines after a line break stay with it, so the next chapter
      // starts with text; so do the spaces after a sentence.
      (_lineEnd, const {0x0A, 0x0D}),
      (_sentenceEnd, const {0x20, 0x09}),
    ]) {
      for (var end in candidates) {
        if (!endsAt(runes, end)) continue;
        while (end < runes.length && trailing.contains(runes[end])) {
          end++;
        }
        return end;
      }
    }
    return mark;
  }

  /// Whether a line ends just before [i]; a CRLF pair is never split.
  static bool _lineEnd(List<int> runes, int i) =>
      runes[i - 1] == 0x0A ||
      (runes[i - 1] == 0x0D && (i == runes.length || runes[i] != 0x0A));

  /// Whether a sentence ends just before [i]: a stop such as 。 or ! and any
  /// closing quotes. A Latin stop also needs a space after it, so "3.14" and
  /// "e.g." are not sentence ends.
  static bool _sentenceEnd(List<int> runes, int i) {
    if (i < runes.length &&
        (_stops.contains(runes[i]) || _closers.contains(runes[i]))) {
      return false;
    }
    var stop = i - 1;
    while (stop > 0 && _closers.contains(runes[stop])) {
      stop--;
    }
    if (!_stops.contains(runes[stop])) return false;
    return runes[stop] > 0x7f || i == runes.length || _isSpace(runes[i]);
  }

  static bool _isSpace(int rune) => String.fromCharCode(rune).trim().isEmpty;
}

class LibraryImport {
  const LibraryImport(
    this.book, {
    required this.updated,
    required this.addedChapters,
    required this.changedChapters,
  });
  final Book book;
  final bool updated;
  final int addedChapters;
  final List<int> changedChapters;
}
