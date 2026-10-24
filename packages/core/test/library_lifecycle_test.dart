import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

import 'support/generation_fakes.dart';

void main() {
  late Directory dir;
  late LocalStore store;
  late Library library;
  late String source;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('library-life-');
    store = LocalStore('${dir.path}/db.sqlite');
    source = (await File('${dir.path}/book.txt').writeAsString(
      'Chapter 1\nWind.\nHome.\nChapter 2\nRain.\nChapter 3\nSun.\n',
    )).path;
    library = Library(store, pickFile: () async => source);
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  test('picker import matches the CLI library for UTF-8 and GBK', () async {
    for (final bytes in [
      [0xe7, 0xac, 0xac, 0x31, 0xe7, 0xab, 0xa0, 0x0a, 0xe9, 0xa3, 0x8e],
      [0xb5, 0xda, 0x31, 0xd5, 0xc2, 0x0a, 0xb7, 0xe7],
    ]) {
      await File(source).writeAsBytes(bytes);
      final outcome = await library.importBook() as BookImported;
      final cli = await Library(store).importTxt(source);
      expect(outcome.book.id, cli.id);
      expect(outcome.book.language, BookLanguage.chinese);
      expect(await library.paragraphs(cli.id, 1), ['风']);
    }
  });

  test('reports cancellation and failures without partial books', () async {
    expect(await Library(store).importBook(), isA<ImportCancelled>());
    source = '${dir.path}/no.txt';
    expect(
      (await library.importBook() as ImportFailed).reason,
      ImportFailure.unreadable,
    );
    source = '${dir.path}/no.epub';
    expect(
      (await library.importBook() as ImportFailed).reason,
      ImportFailure.unsupportedFormat,
    );
    source = (await File('${dir.path}/empty.txt').writeAsString(' \n')).path;
    expect(
      (await library.importBook() as ImportFailed).reason,
      ImportFailure.empty,
    );
    expect(await library.books(), isEmpty);
  });

  test(
    'chapter states follow profiling, valid scripts and actual audio files',
    () async {
      final book = await library.importTxt(source);
      final llm = GenerationLlm();
      final tts = GenerationTts();
      final scheduler = await Scheduler.open(
        store: store,
        profileLlm: llm,
        directorLlm: llm,
        ttsAdapters: {'minimax': tts},
      );
      addTearDown(scheduler.close);
      expect(
        (await library.chapters(book.id)).map((c) => c.state),
        everyElement(ChapterState.unprofiled),
      );
      await scheduler.enqueue(book.id, TaskKind.profile, through: 2);
      await scheduler.idle;
      await Casting(store).recommend(book, providers: {'minimax'});
      await scheduler.enqueue(book.id, TaskKind.direct, through: 1);
      await scheduler.idle;
      expect((await library.chapters(book.id)).map((c) => c.state), [
        ChapterState.directed,
        ChapterState.profiled,
        ChapterState.unprofiled,
      ]);
      await scheduler.enqueue(book.id, TaskKind.synthesize, through: 1);
      await scheduler.idle;
      expect(
        (await library.chapters(book.id)).first.state,
        ChapterState.synthesized,
      );
      final audio = (await AudioRepository(store).get(book.id, 1))!;
      await File(audio.utterances.first.audioPath).delete();
      expect(
        (await library.chapters(book.id)).first.state,
        ChapterState.directed,
      );
      await scheduler.enqueue(book.id, TaskKind.synthesize, through: 1);
      await scheduler.idle;
      expect(
        (await library.chapters(book.id)).first.state,
        ChapterState.synthesized,
      );
      expect(tts.requests, hasLength(2)); // Raw audio cache was reused.
    },
  );

  test(
    'migrates shared CLI audio into book storage without new synthesis requests',
    () async {
      final book = await library.importTxt(source);
      final llm = GenerationLlm();
      final tts = GenerationTts();
      await Profiler(store, llm).profile(book, throughChapter: 1);
      await Casting(store).recommend(book, providers: {'minimax'});
      final script = (await Director(store, llm).direct(book, 1)).script;
      final audio = AudioRepository(store);
      final bindings = await Casting(store).prepareChapterBindings(
        book,
        1,
        speakerIds: script.lines.map((line) => line.direction.speakerId),
      );
      final shared =
          await Synthesizer(
            adapters: {'minimax': tts},
            cacheDirectory: audio.legacyCacheDirectory,
          ).synthesize(
            chapter: book.chapter(1),
            script: script,
            language: book.language,
            voices: bindings,
            outputPath: '${dir.path}/legacy.wav',
          );
      expect(tts.requests, hasLength(2));
      final s = await Scheduler.open(
        store: store,
        profileLlm: llm,
        directorLlm: llm,
        ttsAdapters: {'minimax': tts},
      );
      await s.enqueue(book.id, TaskKind.synthesize, through: 1);
      await s.idle;
      await s.close();
      expect(tts.requests, hasLength(2));
      final migrated = (await audio.get(book.id, 1))!.utterances.first;
      expect(migrated.rawAudioPath, contains(book.id));
      expect(await File(migrated.rawAudioPath).exists(), isTrue);
      expect(await File(shared.utterances.first.rawAudioPath).exists(), isTrue);
    },
  );

  test(
    'deleting a book removes its generated artifacts and preserves other books and source',
    () async {
      final book = await library.importTxt(source);
      final otherPath = (await File(
        '${dir.path}/other.txt',
      ).writeAsString('Another book.')).path;
      final other = await library.importTxt(otherPath);
      final llm = GenerationLlm();
      final s = await Scheduler.open(
        store: store,
        profileLlm: llm,
        directorLlm: llm,
        ttsAdapters: {'minimax': GenerationTts()},
      );
      await s.enqueue(book.id, TaskKind.profile, through: 1);
      await s.idle;
      await Casting(store).recommend(book, providers: {'minimax'});
      await s.enqueue(book.id, TaskKind.synthesize, through: 1);
      await s.idle;
      await s.close();
      final directory = AudioRepository(store).bookDirectory(book.id);
      expect(await directory.exists(), isTrue);
      await library.deleteBook(book.id);
      expect((await library.books()).map((b) => b.id), [other.id]);
      await expectLater(library.getBook(book.id), throwsStateError);
      expect((await CastRepository(store).get(book.id)).profiledThrough, 0);
      expect((await Casting(store).getCasting(book.id)).voices, isEmpty);
      expect(await ScriptRepository(store).get(book.id, 1), isNull);
      expect(await AudioRepository(store).get(book.id, 1), isNull);
      expect(await directory.exists(), isFalse);
      expect(await File(source).exists(), isTrue);
      final reopened = await Scheduler.open(
        store: store,
        profileLlm: llm,
        directorLlm: llm,
        ttsAdapters: {},
      );
      expect(reopened.tasks, isEmpty);
      await reopened.close();
    },
  );
}
