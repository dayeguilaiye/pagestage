import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:pagestage_core/pagestage_core.dart';

import '../playback/just_audio_engine.dart';
import '../storage.dart';
import 'cast_controller.dart';
import 'generation_controller.dart';
import 'voice_controller.dart';
import 'audio_storage_controller.dart';
import 'contracts.dart';
import 'listening_controller.dart';
import 'ming.dart';
import 'listening_handler.dart';
import 'package_controller.dart';
import 'provider_store.dart';
import 'system_speech.dart';

export 'contracts.dart';
export 'system_speech.dart' show SystemSpeech, SystemVoice;

class AppServices {
  AppServices({
    required this.listening,
    required this.providers,
    required this.consents,
    required this.casts,
    this.generation,
    this.voices,
    this.audioStorage,
    this.diagnostics,
    this.packages,
    this.scripts,
    this.ming,
    this.speech,
    Future<void> Function()? onClose,
  }) : _onClose = onClose;
  final Listening listening;
  final Providers providers;
  final Consents consents;
  final Casts casts;
  final Generation? generation;
  final Voices? voices;
  final AudioStorage? audioStorage;
  final Diagnostics? diagnostics;
  final Packages? packages;
  final Scripts? scripts;
  final MingDevice? ming;

  /// The phone's own voice, for choosing which of its voices reads.
  final SystemSpeech? speech;
  final Future<void> Function()? _onClose;
  bool _closed = false;

  static Future<AppServices> open(
    AppStorage storage, {
    Diagnostics? diagnostics,
    AppEngines? engines,
  }) async {
    final ming = engines == null && Platform.isAndroid
        ? await MingDevice.open()
        : null;
    if (ming != null) {
      engines = AppEngines(
        voice: TtsEngines([
          ...standardTtsEngines.all.where((engine) => engine.id != 'device'),
          MingTtsEngine(ming),
        ]),
      );
    }
    final providers = await ProviderStore.open(
      storage.store,
      const PlatformSecretStore(),
      engines: engines,
    );
    var ready = ming?.value.ready ?? false;
    void updateMingReadiness() {
      if (ming == null || ming.value.ready == ready) return;
      ready = ming.value.ready;
      unawaited(providers.refreshReadiness());
    }

    ming?.addListener(updateMingReadiness);
    final consents = ConsentBroker(storage.store);
    final speech = PlatformSystemSpeech(AudioRepository(storage.store));
    final listening = ListeningController(
      store: storage.store,
      engine: JustAudioEngine(),
      speech: speech,
    );
    await listening.restoreSettings();
    final casts = await CastController.open(
      store: storage.store,
      providers: providers,
      consents: consents,
      listening: listening,
      auditionEngine: JustAudioEngine(),
    );
    final generation = await GenerationController.open(
      storage.store,
      casts.scheduler,
      providers: providers,
    );
    listening.attachGeneration(generation);
    final pauses = casts.scheduler.events.listen((event) {
      final task = event.task;
      if (Platform.isAndroid) {
        debugPrintSynchronously(
          'PageStageGeneration ${task.kind.name} chapter=${task.chapter} '
          'state=${task.status.name} utterances=${task.completedUtterances}'
          '${event.utterance == null ? '' : ' cached=${event.utterance!.cacheHit}'}'
          '${task.provider == null ? '' : ' provider=${task.provider}'}'
          '${task.reason == null ? '' : ' reason=${task.reason!.name}'}',
        );
      }
      if (task.status != TaskStatus.paused) return;
      unawaited(
        diagnostics?.recordPause(
          provider: task.provider ?? 'local',
          task: task.kind.name,
          reason: task.reason?.name ?? 'unknown',
          code: task.code,
        ),
      );
    });
    final voices = await VoiceController.open(storage.store, casts, listening);
    final audioStorage = AudioStorageController(
      storage.store,
      casts,
      listening,
      voices,
    );
    storage.library.editBook = (bookId, action) async {
      await listening.invalidate(bookId);
      await voices.idle;
      await voices.stopAudition();
      await casts.stopAudition();
      await casts.idleAuditions;
      await casts.scheduler.withBookPaused(bookId, () async {
        await casts.scheduler.cancelGeneration(bookId);
        await action();
      });
      await listening.refreshBook(bookId);
    };
    var wasPlaying = false;
    void stopSampleOnPlayback() {
      final playing = listening.value.playing;
      if (playing && !wasPlaying) {
        unawaited(casts.stopAudition());
        unawaited(voices.stopAudition());
      }
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
        unawaited(voices.stopAudition());
      }
    });
    final noisy = session.becomingNoisyEventStream.listen((_) {
      unawaited(listening.pause());
      unawaited(casts.stopAudition());
      unawaited(voices.stopAudition());
    });
    return AppServices(
      listening: listening,
      providers: providers,
      consents: consents,
      casts: casts,
      generation: generation,
      voices: voices,
      audioStorage: audioStorage,
      diagnostics: diagnostics,
      packages: PackageController(
        storage.store,
        directory: Directory('${storage.directory.path}/exports'),
      ),
      ming: ming,
      speech: speech,
      scripts: ScriptController(
        storage.store,
        storage.library,
        revoice: (bookId, chapter) =>
            generation.prepare(bookId, first: chapter, through: chapter),
      ),
      onClose: () async {
        ming?.removeListener(updateMingReadiness);
        ming?.dispose();
        storage.library.editBook = null;
        await pauses.cancel();
        await interruptions.cancel();
        await noisy.cancel();
        listening.removeListener(stopSampleOnPlayback);
        await consents.close();
        audioStorage.dispose();
        await listening.pause();
        await voices.close();
        await handler.close();
        await listening.close();
        await generation.close();
        await casts.close();
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
