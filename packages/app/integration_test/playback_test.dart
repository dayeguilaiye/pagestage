import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/l10n/app_localizations.dart';
import 'package:pagestage_app/playback/chapter_player.dart';
import 'package:pagestage_app/playback/just_audio_engine.dart';
import 'package:pagestage_app/playback/playback_handler.dart';
import 'package:pagestage_app/playback/prototype_fixture.dart';
import 'package:pagestage_app/playback/prototype_page.dart';
import 'package:pagestage_app/playback/soloud_engine.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'local chapter plays through, seeks and changes speed on the native engine',
    (tester) async {
      const engineName = String.fromEnvironment(
        'PLAYBACK_ENGINE',
        defaultValue: 'just_audio',
      );
      PlaybackFixture? fixture;
      // Allows the host to copy the ignored fixture after the first install.
      for (var n = 0; n < 120 && fixture == null; n++) {
        try {
          fixture = await PlaybackFixture.load();
        } on FileSystemException {
          if (n == 0) debugPrint('WAITING_FOR_PLAYBACK_FIXTURE');
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      expect(fixture, isNotNull);
      final data = fixture!;
      final player = ChapterPlayer(
        engineName == 'soloud' ? SoloudEngine() : JustAudioEngine(),
        data.queue,
      );
      await (await AudioSession.instance).configure(
        const AudioSessionConfiguration.speech(),
      );
      await player.load(data.path);
      final handler = await AudioService.init(
        builder: () => PlaybackHandler(
          player,
          bookId: data.script.bookId,
          title: data.title,
          chapterTitle: data.chapter.title,
        ),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'pagestage.playback',
          androidNotificationChannelName: 'pagestage',
          androidNotificationOngoing: true,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: PsTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
          home: PlaybackPrototypePage(
            player: player,
            chapter: data.chapter,
            script: data.script,
            title: data.title,
          ),
        ),
      );
      await tester.pump();
      final metrics = <String, Object?>{
        'engine': engineName,
        'platform': Platform.operatingSystem,
        'utterances': data.queue.entries.length,
        'durationMs': data.queue.duration.inMilliseconds,
      };
      final seekTimes = <int>[];
      for (final entry in data.queue.entries) {
        final watch = Stopwatch()..start();
        await player.playFromLine(entry.utterance.lineIndices.first);
        await player.pause();
        seekTimes.add(watch.elapsedMilliseconds);
        expect(
          (player.state.position - entry.audioStart).inMilliseconds.abs(),
          lessThan(250),
        );
      }
      metrics['seekMilliseconds'] = seekTimes;
      for (final speed in [0.5, 1.0, 3.0]) {
        await handler.seek(Duration.zero);
        await handler.setSpeed(speed);
        await handler.play();
        await Future<void>.delayed(const Duration(seconds: 2));
        await handler.pause();
        metrics['positionAt${speed}xMs'] = player.state.position.inMilliseconds;
        expect(
          player.state.position.inMilliseconds,
          closeTo(2000 * speed, 1000),
        );
      }
      await handler.seek(Duration.zero);
      await handler.setSpeed(3);
      await handler.play();
      debugPrint('PLAYBACK_FULL_CHAPTER_STARTED $engineName');
      final heard = <int>{};
      final watch = Stopwatch()..start();
      while (!player.state.completed &&
          watch.elapsed < const Duration(minutes: 4)) {
        heard.add(player.index);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(player.state.error, isNull);
      expect(player.state.completed, isTrue);
      expect(
        heard,
        containsAll(List.generate(data.queue.entries.length, (i) => i)),
      );
      metrics['fullPlaybackMs'] = watch.elapsedMilliseconds;
      metrics['heardIndices'] = heard.toList()..sort();
      binding.reportData = metrics;
      debugPrint('PLAYBACK_RESULT ${jsonEncode(metrics)}');
      await tester.pumpWidget(const SizedBox());
      await handler.close();
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
