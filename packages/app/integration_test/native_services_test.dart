import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagestage_app/application/listening_controller.dart';
import 'package:pagestage_app/application/listening_handler.dart';
import 'package:pagestage_app/application/provider_store.dart';
import 'package:pagestage_app/application/system_speech.dart';
import 'package:pagestage_app/playback/just_audio_engine.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('native secure storage and local TTS use the shared media session', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    const secrets = PlatformSecretStore();
    await secrets.write('integration-probe', 'offline-test-value');
    expect(await secrets.read('integration-probe'), 'offline-test-value');
    await secrets.write('integration-probe', null);
    expect(await secrets.read('integration-probe'), isNull);

    final parent = await getApplicationSupportDirectory();
    await parent.create(recursive: true);
    final directory = await parent.createTemp('native-services-');
    final store = LocalStore('${directory.path}/db.sqlite');
    final file = File('${directory.path}/book.txt');
    await file.writeAsString(
      'Chapter 1\nHello. This is a local speech test.\nChapter 2\nWelcome to the second chapter.',
    );
    final book = await Library(store).importTxt(file.path);
    final player = ListeningController(
      store: store,
      engine: JustAudioEngine(),
      speech: PlatformSystemSpeech(AudioRepository(store)),
    );
    await (await AudioSession.instance).configure(
      const AudioSessionConfiguration.speech(),
    );
    final handler = await AudioService.init<ListeningHandler>(
      builder: () => ListeningHandler(player),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'pagestage.playback',
        androidNotificationChannelName: 'pagestage',
      ),
    );
    try {
      await player.open(book.id);
      expect(
        player.value.error,
        isNull,
        reason: 'An English system voice must be installed on the test device.',
      );
      await handler.pause();
      expect(player.value.playing, isFalse);
      await handler.skipToNext();
      expect(player.value.line, 1);
      for (final speed in [0.5, 1.0, 3.0]) {
        await handler.setSpeed(speed);
        expect(player.value.speed, speed);
      }
      await handler.fastForward();
      expect(player.value.chapter, 2);
      await handler.rewind();
      expect(player.value.chapter, 1);
      await player.open(book.id, chapter: 2);
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (player.value.error != 'endOfBook' &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(player.value.error, 'endOfBook');
      expect(player.value.playing, isFalse);
      debugPrint(
        'NATIVE_SERVICES_RESULT ${Platform.operatingSystem}: secure-storage, local-TTS, speed, sentence/chapter controls, end-of-book passed',
      );
    } finally {
      await handler.close();
      await player.close();
      await store.close();
      await directory.delete(recursive: true);
    }
  });
}
