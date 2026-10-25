import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagestage_app/app.dart';
import 'package:pagestage_app/application/app_services.dart';
import 'package:pagestage_app/application/audio_storage_controller.dart';
import 'package:pagestage_app/application/cast_controller.dart';
import 'package:pagestage_app/application/generation_controller.dart';
import 'package:pagestage_app/application/listening_controller.dart';
import 'package:pagestage_app/application/provider_store.dart';
import 'package:pagestage_app/application/system_speech.dart';
import 'package:pagestage_app/application/voice_controller.dart';
import 'package:pagestage_app/playback/just_audio_engine.dart';
import 'package:pagestage_app/shelf/reading_settings.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/test/support/generation_fakes.dart';
import '../test/application/generation_test.dart' show DesignTts;
import '../test/application/support.dart' show MemorySecrets;

class NativeFixtureTts extends DesignTts {
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    await super.synthesize(request);
    return TtsAudio(
      audio: PcmAudio(
        samples: Int16List.fromList(
          List.generate(
            24000,
            (i) => (sin(i / 24000 * 2 * pi * 220) * 1000).round(),
          ),
        ),
        sampleRate: 24000,
      ),
    );
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'real native queue grows while offline services profile, cast, design and clear',
    (tester) async {
      final parent = await getApplicationSupportDirectory();
      await parent.create(recursive: true);
      final directory = await parent.createTemp('generation-services-');
      final store = LocalStore('${directory.path}/db.sqlite');
      final source = await File(
        '${directory.path}/fixture.txt',
      ).writeAsString('Chapter 1\nOne.\nTwo.\nThree.\nChapter 2\nFour.');
      final book = await Library(
        store,
      ).importTxt(source.path, title: 'Offline integration book');
      final providers = await ProviderStore.open(store, MemorySecrets());
      await providers.save(
        const ProviderPreferences(
          baseUrl: 'https://offline.test/v1',
          profileModel: 'fake',
        ),
        llmKey: 'fake',
        minimaxKey: 'fake',
      );
      final consents = ConsentBroker(store);
      // This is the production consent broker. Only in-memory fake adapters receive
      // these values, and the test accepts its prompts rather than using API keys.
      final destinations = <String>{};
      consents.addListener(() {
        if (consents.value case final r?) {
          destinations.add(r.provider);
          consents.respond(r.id, accepted: true);
        }
      });
      final engine = JustAudioEngine();
      final listening = ListeningController(
        store: store,
        engine: engine,
        speech: PlatformSystemSpeech(AudioRepository(store)),
      );
      final tts = NativeFixtureTts();
      final llm = GenerationLlm();
      final casts = await CastController.open(
        store: store,
        providers: providers,
        consents: consents,
        listening: listening,
        auditionEngine: JustAudioEngine(),
        profileFactory: (_) => llm,
        directorFactory: (_) => llm,
        auditionFactory: (_, _) => tts,
      );
      final generation = await GenerationController.open(
        store,
        casts.scheduler,
      );
      listening.attachGeneration(generation);
      final voices = await VoiceController.open(store, casts, listening);
      final storage = AudioStorageController(store, casts, listening, voices);
      final release = Completer<void>();
      Future<void> until(bool Function() condition) async {
        final deadline = DateTime.now().add(const Duration(seconds: 30));
        while (!condition() && DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(
          condition(),
          isTrue,
          reason: 'Native condition timed out: ${listening.value.error}',
        );
      }

      try {
        await (await AudioSession.instance).configure(
          const AudioSessionConfiguration.speech(),
        );
        await tester.pumpWidget(
          PagestageApp(
            bookshelf: Library(store),
            readingSettings: MemoryReadingSettings(),
            locale: const Locale('en'),
            services: AppServices(
              listening: listening,
              providers: providers,
              consents: consents,
              casts: casts,
              generation: generation,
              voices: voices,
              audioStorage: storage,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(book.title), findsWidgets);
        await casts.profile(book.id, through: 2);
        await casts.idle;
        expect((await casts.load(book.id)).members, isNotEmpty);
        await generation.savePreferences(
          const GenerationPreferences(
            automatic: true,
            directing: 0,
            synthesis: 0,
          ),
        );
        tts.before = (n) => n == 2 ? release.future : null;
        listening.setSleepAfterChapter(true);
        await listening.open(book.id);
        await until(() => listening.value.playing);
        expect(
          (await AudioRepository(store).get(book.id, 1))!.complete,
          isFalse,
        );
        await until(() => listening.value.buffering);
        release.complete();
        await casts.idle;
        await until(() => listening.value.playing);
        expect(listening.value.source, ListeningSource.synthesized);
        await until(
          () => !listening.value.playing && !listening.value.buffering,
        );
        expect(listening.value.chapter, 1);
        expect(listening.value.line, 2);
        expect(destinations, {'llm', 'minimax'});
        for (final speed in [0.5, 1.0, 3.0]) {
          await listening.setSpeed(speed);
          expect(engine.state.speed, speed);
        }
        final options = await voices.presets(book.id, 'narrator');
        final replacement = options.firstWhere(
          (o) => !o.selected && o.provider == 'minimax',
        );
        await voices.auditionPreset(book.id, 'narrator', replacement.id);
        await voices.selectPreset(book.id, 'narrator', replacement.id);
        final candidates = await voices.design(
          book.id,
          'narrator',
          provider: 'minimax',
          description: 'Clear narrator',
        );
        await voices.auditionCandidate(
          book.id,
          'narrator',
          candidates.first.id,
        );
        await voices.selectCandidate(book.id, 'narrator', candidates.first.id);
        expect((await storage.usage()).single.audioBytes, greaterThan(0));
        await storage.clearAudio(book.id);
        expect((await storage.usage()).single.audioBytes, 0);
        expect(
          (await Library(store).chapters(book.id)).first.state,
          ChapterState.directed,
        );
        expect((await casts.load(book.id)).members, isNotEmpty);
        debugPrint(
          'GENERATION_SERVICES_RESULT ${Platform.operatingSystem}: profiling, consent, streaming, buffer/resume, native speed, voices, design, storage passed',
        );
      } finally {
        if (!release.isCompleted) release.complete();
        await tester.pumpWidget(const SizedBox());
        await listening.pause();
        await consents.close();
        storage.dispose();
        await voices.close();
        await listening.close();
        await generation.close();
        await casts.close();
        providers.dispose();
        await store.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
