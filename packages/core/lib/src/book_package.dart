import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'audio_repository.dart';
import 'delivery.dart';
import 'local_store.dart';
import 'models/book.dart';
import 'models/cast.dart';
import 'models/script.dart';
import 'models/voice.dart';
import 'performance.dart';
import 'script_repository.dart';
import 'synthesizer.dart';

/// What a package carries beyond the book's own text.
enum BookPackageKind {
  /// The text, the cast and the scripts directed so far. Whoever imports it
  /// voices it with their own engines, without directing anything again.
  script,

  /// A script package plus the audio already voiced, ready to listen to.
  audio,
}

/// What a package holds, read from its manifest alone.
class BookPackageSummary {
  BookPackageSummary({
    required this.kind,
    required this.bookId,
    required this.title,
    required this.language,
    required this.chapterCount,
    required List<int> scriptChapters,
    required List<int> audioChapters,
  }) : scriptChapters = List.unmodifiable(scriptChapters),
       audioChapters = List.unmodifiable(audioChapters);
  final BookPackageKind kind;
  final String bookId;
  final String title;
  final String language;
  final int chapterCount;
  final List<int> scriptChapters;
  final List<int> audioChapters;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'bookId': bookId,
    'title': title,
    'language': language,
    'chapters': chapterCount,
    'scriptChapters': scriptChapters,
    'audioChapters': audioChapters,
  };
}

class BookPackageImport {
  const BookPackageImport(this.book, this.summary, {required this.replaced});
  final Book book;

  /// What was installed, which may be less than the package declared when
  /// some of it did not match the book's text.
  final BookPackageSummary summary;
  final bool replaced;
}

/// The package's book is already on the shelf; importing it again replaces
/// that book's cast, scripts and audio.
class BookPackageConflict implements Exception {
  const BookPackageConflict(this.bookId, this.title);
  final String bookId;
  final String title;
}

/// Turns chapter audio into another container before it is packed, such as
/// AAC on a desktop; returns the new file.
typedef AudioTranscoder = Future<File> Function(File wav, Directory scratch);

/// Writes and reads `.pagestage` packages: one book with its text, cast and
/// scripts, optionally with audio, as a single file to move between devices
/// and people. Importing never calls an engine.
///
/// The file is a ZIP holding `manifest.json`, `book.json`, `cast.json`,
/// `voices.json`, `scripts/<chapter>.json` and, for audio packages,
/// `audio/<chapter>-<mode>.<ext>` beside its `.json` playlist.
class BookPackages {
  BookPackages(this.store);
  final LocalStore store;

  static const extension = '.pagestage';
  static const _format = 'pagestage-package';
  static const _version = 1;
  static final _bookId = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');
  static final _audioName = RegExp(
    r'^audio/[0-9]{6}-(audiobook|drama)\.(wav|m4a|mp3|flac)$',
  );

  static String _chapterName(int chapter) => chapter.toString().padLeft(6, '0');

  /// Packs [bookId] into [path]. An audio package holds the chapters whose
  /// audio is complete in [mode], the book's own mode by default.
  Future<BookPackageSummary> export(
    String bookId,
    String path, {
    required BookPackageKind kind,
    PerformanceMode? mode,
    AudioTranscoder? transcode,
  }) async {
    final bookJson = await store.get('books', bookId);
    if (bookJson == null) throw StateError('Book not found: $bookId');
    final book = Book.fromJson(bookJson);
    final cast = await CastRepository(store).get(bookId);
    final performance = await PerformanceRepository(store).get(bookId);
    final audioMode = mode ?? performance.mode;
    final audio = AudioRepository(store);

    final voices = <Map<String, Object?>>[];
    for (final id in {for (final speaker in cast.speakers) ?speaker.voiceId}) {
      final voice = await store.get('voices', id);
      // Samples are local files; whoever imports auditions their own.
      if (voice != null) voices.add({...voice}..remove('samplePath'));
    }
    final casting = await store.get('casting', bookId);

    final scripts = <Script>[];
    for (final chapter in book.chapters) {
      final script = await ScriptRepository(store).get(bookId, chapter.number);
      if (script != null && script.sourceTextHash == chapter.textHash) {
        scripts.add(script);
      }
    }

    final output = File(path);
    await output.parent.create(recursive: true);
    final scratch = await output.parent.createTemp('.package-');
    final staging = File(p.join(scratch.path, 'package.zip'));
    final encoder = ZipFileEncoder()..create(staging.path);
    void addJson(String name, Object? value) {
      final bytes = utf8.encode(jsonEncode(value));
      encoder.addArchiveFile(ArchiveFile(name, bytes.length, bytes));
    }

    try {
      final audioEntries = <Map<String, Object?>>[];
      if (kind == BookPackageKind.audio) {
        for (final script in scripts) {
          final playlist = await audio.get(
            bookId,
            script.chapterNumber,
            mode: audioMode,
          );
          final source = playlist?.path;
          if (playlist == null ||
              source == null ||
              !await audio.isComplete(script, mode: audioMode) ||
              !await File(source).exists()) {
            continue;
          }
          var file = File(source);
          if (transcode != null && p.extension(source) == '.wav') {
            file = await transcode(file, scratch);
          }
          final name =
              'audio/${_chapterName(script.chapterNumber)}-${audioMode.name}'
              '${p.extension(file.path).toLowerCase()}';
          if (!_audioName.hasMatch(name)) {
            throw const FormatException('Unsupported audio container.');
          }
          // Speech is already compact or incompressible; store it as is.
          await encoder.addFile(file, name, ZipFileEncoder.STORE);
          addJson('${p.withoutExtension(name)}.json', {
            ...playlist.toJson(),
            'path': null,
            'utterances': [
              for (final utterance in playlist.utterances)
                {...utterance.toJson(), 'audioPath': '', 'rawAudioPath': ''},
            ],
          });
          audioEntries.add({
            'chapter': script.chapterNumber,
            'mode': audioMode.name,
            'file': name,
            'bytes': await file.length(),
            'sha256': (await sha256.bind(file.openRead()).first).toString(),
            'durationUs': playlist.duration.inMicroseconds,
          });
        }
      }
      addJson('book.json', {
        ...book.toJson(),
        'sourcePath': p.basename(book.sourcePath),
      });
      addJson('cast.json', cast.toJson());
      addJson('voices.json', {
        'voices': voices,
        if (casting != null)
          'casting': {
            'exclusiveCount': casting['exclusiveCount'],
            'exclusiveSpeakerIds': casting['exclusiveSpeakerIds'],
          },
      });
      for (final script in scripts) {
        addJson(
          'scripts/${_chapterName(script.chapterNumber)}.json',
          script.toJson(),
        );
      }
      final summary = BookPackageSummary(
        kind: kind,
        bookId: book.id,
        title: book.title,
        language: book.language,
        chapterCount: book.chapters.length,
        scriptChapters: [for (final script in scripts) script.chapterNumber],
        audioChapters: [for (final e in audioEntries) e['chapter'] as int],
      );
      // Written last, so a package cut short has no manifest and is refused.
      addJson('manifest.json', {
        'format': _format,
        'version': _version,
        'kind': kind.name,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'book': {
          'id': book.id,
          'title': book.title,
          'language': book.language,
          'chapters': book.chapters.length,
        },
        'performance': {
          'mode': audioMode.name,
          'expressiveness': performance.expressiveness.name,
        },
        'scripts': summary.scriptChapters,
        'audio': audioEntries,
      });
      await encoder.close();
      await staging.rename(output.path);
      return summary;
    } catch (_) {
      try {
        await encoder.close();
      } catch (_) {
        // The staging file is discarded below either way.
      }
      rethrow;
    } finally {
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
  }

  /// Reads what the package at [path] holds without installing anything.
  Future<BookPackageSummary> inspect(String path) async {
    final input = InputFileStream(path);
    try {
      return _summary(_manifest(_entries(input)));
    } finally {
      await input.close();
    }
  }

  /// Installs the package at [path]. When its book is already on the shelf
  /// this throws [BookPackageConflict] unless [replace] is set, and then
  /// replaces the book's cast, scripts and audio, keeping the reader's place.
  /// [edit] wraps the replacement, as `Library.editBook` does.
  Future<BookPackageImport> import(
    String path, {
    bool replace = false,
    Future<void> Function(String bookId, Future<void> Function() action)? edit,
  }) async {
    final input = InputFileStream(path);
    try {
      final entries = _entries(input);
      final manifest = _manifest(entries);
      final declared = _summary(manifest);
      final book = Book.fromJson(_json(entries, 'book.json'));
      if (book.id != declared.bookId ||
          book.chapters.isEmpty ||
          !['zh', 'en'].contains(book.language)) {
        throw const FormatException('Invalid package book.');
      }
      for (final (index, chapter) in book.chapters.indexed) {
        if (chapter.number != index + 1) {
          throw const FormatException('Invalid package chapters.');
        }
      }
      final cast = Cast.fromJson(_json(entries, 'cast.json'));
      if (cast.bookId != book.id ||
          cast.profiledThrough < 0 ||
          cast.profiledThrough > book.chapters.length) {
        throw const FormatException('Invalid package cast.');
      }
      final voiceJson = _json(entries, 'voices.json');
      final voices = [
        for (final row in voiceJson['voices'] as List)
          Voice.fromJson({
            ...Map<String, Object?>.from(row as Map),
            'samplePath': null,
          }),
      ];
      if (voices.any((voice) => voice.bookId != book.id)) {
        throw const FormatException('Invalid package voices.');
      }
      final voiceIds = {for (final voice in voices) voice.id};
      final speakers = [
        for (final speaker in cast.speakers)
          if (speaker.voiceId == null || voiceIds.contains(speaker.voiceId))
            speaker
          else
            // A voice the package left out is cast again here.
            Speaker.fromJson({...speaker.toJson(), 'voiceId': null}),
      ];

      final scripts = <int, Script>{};
      for (final number in declared.scriptChapters) {
        final script = Script.fromJson(
          _json(entries, 'scripts/${_chapterName(number)}.json'),
        );
        if (script.bookId != book.id ||
            script.chapterNumber != number ||
            number < 1 ||
            number > book.chapters.length) {
          throw const FormatException('Invalid package script.');
        }
        final chapter = book.chapter(number);
        // A script for other text, or one that does not cover it, is left
        // out; that chapter is simply directed again.
        if (script.sourceTextHash == chapter.textHash &&
            _covers(script, chapter.text)) {
          scripts[number] = script;
        }
      }

      final existing = await store.get('books', book.id);
      if (existing != null && !replace) {
        throw BookPackageConflict(book.id, existing['title'] as String);
      }
      final performanceJson = manifest['performance'] as Map? ?? const {};
      final performance = Performance(
        mode: PerformanceMode.values.byName(
          performanceJson['mode'] as String? ?? 'audiobook',
        ),
        expressiveness: Expressiveness.values.byName(
          performanceJson['expressiveness'] as String? ?? 'natural',
        ),
      );
      final casting = voiceJson['casting'] as Map?;
      final savedCasting = casting == null
          ? null
          : <String, Object?>{
              'exclusiveCount': casting['exclusiveCount'] as int? ?? 20,
              // Which engines to cast from is this device's choice.
              'providers': null,
              'exclusiveSpeakerIds':
                  (casting['exclusiveSpeakerIds'] as List? ?? const [])
                      .cast<String>()
                      .toList(),
              'warnings': const <String>[],
            };

      final repository = AudioRepository(store);
      final directory = repository.bookDirectory(book.id);
      final installed = <ChapterAudio>[];
      await directory.parent.create(recursive: true);
      final scratch = await directory.parent.createTemp('.package-');
      final staged = await Directory(p.join(scratch.path, 'audio')).create();
      final backup = Directory(p.join(scratch.path, 'previous'));

      // Read and verify every incoming file before touching the current book.
      Future<void> prepare() async {
        for (final entry in (manifest['audio'] as List? ?? const [])) {
          final row = Map<String, Object?>.from(entry as Map);
          final name = row['file'] as String;
          final chapter = row['chapter'] as int;
          final script = scripts[chapter];
          if (!_audioName.hasMatch(name) || script == null) continue;
          final playlist = ChapterAudio.fromJson(
            _json(entries, '${p.withoutExtension(name)}.json'),
          );
          if (playlist.bookId != book.id ||
              playlist.chapter != chapter ||
              playlist.mode.name != row['mode'] ||
              !playlist.complete ||
              playlist.utterances.isEmpty ||
              playlist.scriptHash != AudioRepository.hashScript(script) ||
              playlist.utterances.any(
                (u) =>
                    u.lineIndices.isEmpty ||
                    u.lineIndices.any(
                      (i) => i < 0 || i >= script.lines.length,
                    ) ||
                    u.duration.isNegative ||
                    u.pauseBefore.isNegative,
              )) {
            continue;
          }
          final file = File(p.join(staged.path, 'package-${p.basename(name)}'));
          final content = entries[name];
          if (content == null) continue;
          final sink = OutputFileStream(file.path);
          try {
            content.writeContent(sink);
          } finally {
            await sink.close();
          }
          if ((await sha256.bind(file.openRead()).first).toString() !=
              row['sha256']) {
            throw const FormatException('Corrupt package audio.');
          }
          installed.add(
            ChapterAudio(
              bookId: book.id,
              chapter: chapter,
              mode: playlist.mode,
              scriptHash: playlist.scriptHash,
              complete: true,
              path: p.join(directory.path, p.basename(file.path)),
              imported: true,
              utterances: [
                for (final utterance in playlist.utterances)
                  SynthesizedUtterance.fromJson({
                    ...utterance.toJson(),
                    'audioPath': p.join(directory.path, p.basename(file.path)),
                    'rawAudioPath': p.join(
                      directory.path,
                      p.basename(file.path),
                    ),
                    'cacheHit': false,
                  }),
              ],
            ),
          );
        }
      }

      Future<void> install() async {
        var movedPrevious = false;
        var movedIncoming = false;
        try {
          if (await directory.exists()) {
            await directory.rename(backup.path);
            movedPrevious = true;
          }
          await staged.rename(directory.path);
          movedIncoming = true;
          await store.transaction(() async {
            if (existing != null) await _clear(book.id);
            await store.put('books', book.id, {
              ...book.toJson(),
              'sourcePath': 'package:${p.basename(path)}',
              'importedAt':
                  existing?['importedAt'] ??
                  DateTime.now().microsecondsSinceEpoch,
            });
            await CastRepository(store).save(cast.copyWith(speakers: speakers));
            for (final voice in voices) {
              await store.put('voices', voice.id, voice.toJson());
            }
            if (savedCasting != null) {
              await store.put('casting', book.id, savedCasting);
            }
            for (final script in scripts.values) {
              await ScriptRepository(store).save(script);
            }
            await PerformanceRepository(store).save(book.id, performance);
            for (final chapterAudio in installed) {
              await repository.save(chapterAudio);
            }
          });
        } catch (_) {
          if (movedIncoming) await directory.delete(recursive: true);
          if (movedPrevious) await backup.rename(directory.path);
          rethrow;
        }
        // The committed database now refers only to the new audio directory.
        if (await backup.exists()) await backup.delete(recursive: true);
      }

      try {
        await prepare();
        if (existing != null && edit != null) {
          await edit(book.id, install);
        } else {
          await install();
        }
      } finally {
        // Preserve a backup if restoring it failed at the filesystem boundary.
        if (!await backup.exists() && await scratch.exists()) {
          await scratch.delete(recursive: true);
        }
      }
      return BookPackageImport(
        book,
        BookPackageSummary(
          kind: declared.kind,
          bookId: book.id,
          title: book.title,
          language: book.language,
          chapterCount: book.chapters.length,
          scriptChapters: scripts.keys.toList()..sort(),
          audioChapters: [for (final a in installed) a.chapter]..sort(),
        ),
        replaced: existing != null,
      );
    } on ArchiveException {
      throw const FormatException('Invalid package archive.');
    } on TypeError {
      throw const FormatException('Invalid package contents.');
    } on ArgumentError {
      throw const FormatException('Invalid package contents.');
    } finally {
      await input.close();
    }
  }

  /// Removes what an earlier copy of the book generated, keeping the
  /// reader's place and settings.
  Future<void> _clear(String bookId) async {
    for (final collection in const [
      'scripts',
      'audio',
      'voices',
      'voiceCandidates',
      'tasks',
    ]) {
      for (final row in await store.list(collection)) {
        final owner = collection == 'voiceCandidates'
            ? (row['voice'] as Map)['bookId']
            : row['bookId'];
        if (owner != bookId) continue;
        final key = switch (collection) {
          'scripts' => '$bookId:${row['chapterNumber']}',
          'audio' => '$bookId:${row['chapter']}:${row['mode']}',
          _ => row['id'] as String,
        };
        await store.delete(collection, key);
      }
    }
    await store.delete('casting', bookId);
  }

  static Map<String, ArchiveFile> _entries(InputFileStream input) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBuffer(input);
    } catch (_) {
      throw const FormatException('Invalid package archive.');
    }
    if (archive.length > 100000) {
      throw const FormatException('Invalid package archive.');
    }
    return {
      for (final file in archive)
        if (file.isFile) file.name: file,
    };
  }

  static Map<String, Object?> _json(
    Map<String, ArchiveFile> entries,
    String name,
  ) {
    final file = entries[name];
    // Text and records only; audio never passes through here.
    if (file == null || file.size > 512 * 1024 * 1024) {
      throw const FormatException('Incomplete package.');
    }
    final value = jsonDecode(utf8.decode(file.content as List<int>));
    file.clear();
    if (value is! Map) throw const FormatException('Invalid package record.');
    return Map<String, Object?>.from(value);
  }

  static Map<String, Object?> _manifest(Map<String, ArchiveFile> entries) {
    final manifest = _json(entries, 'manifest.json');
    final version = manifest['version'];
    if (manifest['format'] != _format || version is! int || version < 1) {
      throw const FormatException('Not a pagestage package.');
    }
    if (version > _version) {
      throw const FormatException('The package needs a newer pagestage.');
    }
    return manifest;
  }

  static BookPackageSummary _summary(Map<String, Object?> manifest) {
    try {
      final book = manifest['book'] as Map;
      final id = book['id'] as String;
      if (!_bookId.hasMatch(id)) throw const FormatException('Invalid book.');
      return BookPackageSummary(
        kind: BookPackageKind.values.byName(manifest['kind'] as String),
        bookId: id,
        title: book['title'] as String,
        language: book['language'] as String,
        chapterCount: book['chapters'] as int,
        scriptChapters: (manifest['scripts'] as List).cast<int>().toList(),
        audioChapters: [
          for (final entry in manifest['audio'] as List? ?? const [])
            (entry as Map)['chapter'] as int,
        ],
      );
    } on TypeError {
      throw const FormatException('Invalid package manifest.');
    } on ArgumentError {
      throw const FormatException('Invalid package manifest.');
    }
  }

  /// Whether [script]'s lines cover [source] in order, as readers and the
  /// synthesizer assume of every stored script.
  static bool _covers(Script script, String source) {
    var end = 0;
    for (final line in script.lines) {
      if (line.start != end || line.end <= line.start) return false;
      if (line.end > source.length) return false;
      if (line.direction.cues.any((cue) => cue.offset < 0)) return false;
      end = line.end;
    }
    return end == source.length ||
        (script.lines.isEmpty && source.trim().isEmpty);
  }
}
