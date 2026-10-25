import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/application/listening_controller.dart';
import 'package:pagestage_app/application/listening_handler.dart';
import 'package:pagestage_core/pagestage_core.dart';

import '../../../core/test/support/generation_fakes.dart';
import 'support.dart';

void main() {
  late Directory root;
  late LocalStore store;
  late MemoryEngine engine;
  late MemorySpeech speech;
  late ListeningController player;
  late Book book;
  var time = DateTime(2026);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('listening-');
    store = LocalStore('${root.path}/db.sqlite');
    book = await importBook(store, root);
    engine = MemoryEngine();
    speech = MemorySpeech();
    player = ListeningController(
      store: store,
      engine: engine,
      speech: speech,
      now: () => time,
    );
  });
  tearDown(() async {
    await player.close();
    await store.close();
    await root.delete(recursive: true);
  });

  test(
    'system speech advances sentence then chapter, restores book progress',
    () async {
      await player.open(book.id);
      expect(player.value.source, ListeningSource.system);
      expect(speech.requests.single.$2, 'en');
      expect(player.value.activeLines, [0]);
      engine.complete();
      await player.settled;
      expect(player.value.line, 1);
      engine.complete();
      await player.settled;
      expect(player.value.chapter, 2);
      expect((await player.bookmark(book.id))!.progress, 0.5);
      await player.pause();
      final secondEngine = MemoryEngine();
      final reopened = ListeningController(
        store: store,
        engine: secondEngine,
        speech: MemorySpeech(),
      );
      await reopened.open(book.id);
      expect(reopened.value.chapter, 2);
      expect(reopened.value.line, 0);
      await reopened.close();
    },
  );

  test('Chinese sentences, unavailable voice and source ranges', () async {
    final chinese = await importBook(store, root, language: 'zh');
    await player.open(chinese.id);
    expect(speech.requests.single.$2, 'zh');
    final lines = await player.lines(chinese.id, 1);
    expect(lines.map((l) => l.text).join(), chinese.chapter(1).text);
    for (final line in lines) {
      expect(
        line.text,
        chinese.chapter(1).text.substring(line.start, line.end),
      );
    }
    speech.available = false;
    await player.nextLine();
    expect(player.value.error, 'systemVoiceUnavailable');
    expect(player.value.playing, isFalse);
  });

  test('duration timer and end-of-chapter timer stop playback', () async {
    await player.open(book.id);
    player.setSleepTimer(const Duration(minutes: 2));
    time = time.add(const Duration(minutes: 2));
    player.checkSleepTimer();
    await player.settled;
    expect(player.value.playing, isFalse);
    await player.play();
    player.setSleepAfterChapter(true);
    engine.complete();
    await player.settled;
    expect(player.value.line, 1);
    engine.complete();
    await player.settled;
    expect(player.value.chapter, 1);
    expect(player.value.playing, isFalse);
    expect(player.value.sleepAfterChapter, isFalse);
  });

  test(
    'generated audio uses source timeline and falls back to system next chapter',
    () async {
      final llm = GenerationLlm();
      await Profiler(store, llm).profile(book, throughChapter: 1);
      await Casting(store).recommend(book, providers: {'minimax'});
      final scheduler = await Scheduler.open(
        store: store,
        profileLlm: llm,
        directorLlm: llm,
        ttsAdapters: {'minimax': GenerationTts()},
      );
      await scheduler.enqueue(book.id, TaskKind.synthesize, through: 1);
      await scheduler.idle;
      await scheduler.close();
      await player.open(book.id);
      expect(player.value.source, ListeningSource.synthesized);
      expect(player.value.duration, greaterThan(Duration.zero));
      expect(speech.requests, isEmpty);
      await player.setSpeed(3);
      expect(engine.state.speed, 3);
      engine.complete();
      await player.settled;
      expect(player.value.chapter, 2);
      expect(player.value.source, ListeningSource.system);
      expect(speech.requests, hasLength(1));
      expect(engine.state.speed, 3);
    },
  );

  test('system media actions use same sentence and chapter session', () async {
    final handler = ListeningHandler(player);
    await player.open(book.id);
    await handler.skipToNext();
    expect(player.value.line, 1);
    await handler.fastForward();
    expect(player.value.chapter, 2);
    await handler.rewind();
    expect(player.value.chapter, 1);
    await handler.setSpeed(0.5);
    expect(player.value.speed, 0.5);
    await handler.pause();
    expect(player.value.playing, isFalse);
    await handler.close();
  });
  test(
    'long sentences remain bounded and preserve surrogate pairs and text',
    () {
      final text = '${'你' * 1999}😀${'a' * 5000}。';
      final lines = ListeningController.splitSentences(text);
      expect(lines.map((line) => line.text).join(), text);
      expect(lines.every((line) => line.text.length <= 2000), isTrue);
      expect(lines.every((line) => !line.text.runes.contains(0xfffd)), isTrue);
    },
  );
}
