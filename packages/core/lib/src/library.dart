import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'encoding/gb18030.dart';
import 'package:path/path.dart' as p;

import 'local_store.dart';
import 'epub.dart';
import 'models/book.dart';
import 'models/cast.dart';
import 'bookshelf.dart';
import 'audio_repository.dart';
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
  Future<ImportOutcome> importBook() async {
    String? path;
    try {
      path = await pickFile?.call();
      if (path == null) return const ImportCancelled();
      if (!['.txt', '.epub'].contains(p.extension(path).toLowerCase())) {
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

  @override
  Future<List<ChapterEntry>> chapters(String bookId) async {
    final book = await getBook(bookId);
    final cast = await CastRepository(store).get(bookId);
    final audio = AudioRepository(store);
    final modeName = (await store.get('performance', bookId))?['mode'];
    final mode = modeName == 'drama'
        ? PerformanceMode.drama
        : PerformanceMode.audiobook;
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
    } else {
      throw const FormatException('Supported formats are TXT and EPUB.');
    }
    final id = sha256
        .convert(utf8.encode(identity))
        .toString()
        .substring(0, 24);
    final books = await listBooks();
    Book? previous = books.where((b) => b.id == id).firstOrNull;
    if (previous == null && chapters.length >= 3) {
      final matches = books
          .where(
            (b) =>
                b.chapters.length >= 3 &&
                List.generate(
                  3,
                  (i) => _body(b.chapters[i].text) == _body(chapters[i].text),
                ).every((same) => same),
          )
          .toList();
      if (matches.length == 1) previous = matches.single;
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

  List<Chapter> _chapters(String text) {
    final headings = RegExp(
      r'^[ \t\u3000]*(?:第[〇零一二三四五六七八九十百千万两0-9]+[章回](?:[ \t\u3000:：.、—-]+[^\r\n]*)?|Chapter[ \t]+(?:[0-9]+|[IVXLCDM]+)(?:[. :—-][^\r\n]*)?)[ \t]*(?:\r?\n|$)',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(text).toList();
    final volumes = RegExp(
      r'^[ \t\u3000]*第[〇零一二三四五六七八九十百千万两0-9]+卷(?:[ \t\u3000:：.、—-]+[^\r\n]*)?[ \t]*(?:\r?\n|$)',
      multiLine: true,
    ).allMatches(text).toList();
    final chapters = <Chapter>[];
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
      chapters.add(
        Chapter(
          number: i + 1,
          title: heading.group(0)!.trim(),
          text: text.substring(heading.end, end),
          volume: volume,
        ),
      );
    }
    if (chapters.isNotEmpty) return chapters;
    final characters = text.runes.toList();
    for (var offset = 0; offset < characters.length; offset += 5000) {
      final end = offset + 5000 < characters.length
          ? offset + 5000
          : characters.length;
      final number = chapters.length + 1;
      chapters.add(
        Chapter(
          number: number,
          title: RegExp(r'[\u3400-\u9fff]').hasMatch(text)
              ? '第$number章'
              : 'Chapter $number',
          text: String.fromCharCodes(characters.sublist(offset, end)),
        ),
      );
    }
    return chapters;
  }
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
