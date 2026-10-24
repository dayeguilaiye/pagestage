import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/l10n/app_localizations.dart';
import 'package:pagestage_app/playback/chapter_player.dart';
import 'package:pagestage_app/playback/playback_engine.dart';
import 'package:pagestage_app/playback/playback_handler.dart';
import 'package:pagestage_app/playback/playback_queue.dart';
import 'package:pagestage_app/playback/prototype_page.dart';
import 'package:pagestage_core/pagestage_core.dart';

class FakeEngine implements PlaybackEngine {
  final events = StreamController<EngineState>.broadcast(sync: true);
  @override
  EngineState state = const EngineState();
  final seeks = <Duration>[];
  void publish({Duration? position, bool? playing, double? speed}) {
    state = EngineState(
      position: position ?? state.position,
      playing: playing ?? state.playing,
      speed: speed ?? state.speed,
    );
    events.add(state);
  }

  @override
  Stream<EngineState> get states => events.stream;
  @override
  Future<void> load(String path, Duration duration) async {}
  @override
  Future<void> play() async => publish(playing: true);
  @override
  Future<void> pause() async => publish(playing: false);
  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    publish(position: position);
  }

  @override
  Future<void> setSpeed(double speed) async => publish(speed: speed);
  @override
  Future<void> dispose() => events.close();
}

SynthesizedUtterance utterance(
  List<int> lines, {
  int pause = 0,
  String path = '',
}) => SynthesizedUtterance(
  start: 0,
  end: 5,
  lineIndices: lines,
  speakerId: 'narrator',
  audioPath: path,
  rawAudioPath: path,
  cacheKey: 'x',
  cacheHit: false,
  duration: const Duration(seconds: 1),
  pauseBefore: Duration(milliseconds: pause),
  loudness: const LoudnessReport(
    measurement: LoudnessMeasurement.integrated,
    inputLufs: -20,
    estimatedOutputLufs: -20,
    gainDb: 0,
    targetLufs: -20,
    peakLimited: false,
    boostLimited: false,
  ),
);

void main() {
  test('maps merged lines, skipped lines, pauses and exact boundary seeks', () {
    final queue = PlaybackQueue([
      utterance([0, 1]),
      utterance([3], pause: 300),
    ]);
    expect(queue.duration, const Duration(milliseconds: 2300));
    expect(queue.positionForLine(1), Duration.zero);
    expect(queue.positionForLine(3), const Duration(milliseconds: 1300));
    expect(queue.indexForLine(2), -1);
    expect(() => queue.positionForLine(2), throwsArgumentError);
    expect(queue.indexAt(const Duration(milliseconds: 999)), 0);
    expect(queue.indexAt(const Duration(seconds: 1)), 1);
  });

  test(
    'materialized queue has exactly the declared silence and unchanged speech samples',
    () async {
      final dir = await Directory.systemTemp.createTemp('playback-pcm-');
      addTearDown(() => dir.delete(recursive: true));
      final original = PcmAudio(
        samples: Int16List.fromList(List.filled(24000, 1000)),
        sampleRate: 24000,
      );
      final clip = await File(
        '${dir.path}/clip.wav',
      ).writeAsBytes(original.toWav());
      final queue = PlaybackQueue([
        utterance([0], path: clip.path),
        utterance([1], pause: 300, path: clip.path),
      ]);
      final out = File('${dir.path}/queue.wav');
      await queue.writeWav(out);
      final rendered = PcmAudio.fromWav(await out.readAsBytes());
      expect(rendered.samples.length, 55200);
      expect(rendered.samples.take(24000), everyElement(1000));
      expect(rendered.samples.skip(24000).take(7200), everyElement(0));
      expect(rendered.samples.skip(31200), everyElement(1000));
    },
  );

  test(
    'notification controls use the same line positions and speed as the screen',
    () async {
      final engine = FakeEngine();
      final player = ChapterPlayer(
        engine,
        PlaybackQueue([
          utterance([0]),
          utterance([2], pause: 300),
        ]),
      );
      final handler = PlaybackHandler(
        player,
        bookId: 'book',
        title: 'Book',
        chapterTitle: 'Chapter',
      );
      expect(
        handler.playbackState.value.systemActions,
        contains(MediaAction.playPause),
      );
      await handler.click();
      expect(player.state.playing, isTrue);
      await handler.click();
      expect(player.state.playing, isFalse);
      await handler.skipToNext();
      expect(engine.seeks.last, const Duration(milliseconds: 1300));
      await handler.play();
      expect(player.state.playing, isTrue);
      await handler.pause();
      expect(player.state.playing, isFalse);
      await handler.skipToPrevious();
      expect(engine.seeks.last, Duration.zero);
      await handler.setSpeed(3);
      expect(player.state.speed, 3);
      expect(() => player.setSpeed(3.1), throwsArgumentError);
      await handler.close();
    },
  );

  testWidgets(
    'tapping a line only opens a menu; selecting play moves playback',
    (tester) async {
      final engine = FakeEngine();
      final player = ChapterPlayer(
        engine,
        PlaybackQueue([
          utterance([0]),
          utterance([1], pause: 300),
        ]),
      );
      const chapter = Chapter(number: 1, title: '第一章', text: '风来了。\n他回家。');
      final script = Script.narration(bookId: 'book', chapter: chapter);
      await tester.pumpWidget(
        MaterialApp(
          theme: PsTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          home: PlaybackPrototypePage(
            player: player,
            chapter: chapter,
            script: script,
            title: '书',
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final passage = tester.widget<PsPassage>(find.byType(PsPassage).last);
      passage.onLineTap!(0, 0, Offset.zero);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('从这里播放'), findsOneWidget);
      expect(engine.seeks, isEmpty);
      expect(engine.state.playing, isFalse);
      await tester.tap(find.text('从这里播放'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(engine.seeks, [const Duration(milliseconds: 1300)]);
      expect(engine.state.playing, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(player.close);
    },
  );
}
