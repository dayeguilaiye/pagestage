import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:pagestage_core/pagestage_core.dart';

import '../playback/just_audio_engine.dart';
import '../storage.dart';
import 'cast_controller.dart';
import 'contracts.dart';
import 'listening_controller.dart';
import 'listening_handler.dart';
import 'provider_store.dart';
import 'system_speech.dart';

export 'contracts.dart';

class AppServices {
  AppServices({
    required this.listening,
    required this.providers,
    required this.consents,
    required this.casts,
    Future<void> Function()? onClose,
  }) : _onClose = onClose;
  final Listening listening;
  final Providers providers;
  final Consents consents;
  final Casts casts;
  final Future<void> Function()? _onClose;
  bool _closed = false;

  static Future<AppServices> open(AppStorage storage) async {
    final providers = await ProviderStore.open(
      storage.store,
      const PlatformSecretStore(),
    );
    final consents = ConsentBroker(storage.store);
    final listening = ListeningController(
      store: storage.store,
      engine: JustAudioEngine(),
      speech: PlatformSystemSpeech(AudioRepository(storage.store)),
    );
    await listening.restoreSettings();
    final casts = await CastController.open(
      store: storage.store,
      providers: providers,
      consents: consents,
      listening: listening,
      auditionEngine: JustAudioEngine(),
    );
    var wasPlaying = false;
    void stopSampleOnPlayback() {
      final playing = listening.value.playing;
      if (playing && !wasPlaying) unawaited(casts.stopAudition());
      wasPlaying = playing;
    }

    listening.addListener(stopSampleOnPlayback);
    final handler = await AudioService.init<ListeningHandler>(
      builder: () => ListeningHandler(listening),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'pagestage.playback',
        androidNotificationChannelName: 'pagestage',
        androidNotificationOngoing: true,
      ),
    );
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    final interruptions = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        unawaited(listening.pause());
        unawaited(casts.stopAudition());
      }
    });
    final noisy = session.becomingNoisyEventStream.listen((_) {
      unawaited(listening.pause());
      unawaited(casts.stopAudition());
    });
    return AppServices(
      listening: listening,
      providers: providers,
      consents: consents,
      casts: casts,
      onClose: () async {
        await interruptions.cancel();
        await noisy.cancel();
        listening.removeListener(stopSampleOnPlayback);
        await consents.close();
        await casts.close();
        await handler.close();
        await listening.close();
        await providers.saved;
        providers.dispose();
      },
    );
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _onClose?.call();
  }
}
