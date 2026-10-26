import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagestage_app/app.dart';
import 'package:pagestage_app/application/app_services.dart';
import 'package:pagestage_app/application/bundled_examples.dart';
import 'package:pagestage_app/application/cast_controller.dart';
import 'package:pagestage_app/application/generation_controller.dart';
import 'package:pagestage_app/application/listening_controller.dart';
import 'package:pagestage_app/application/provider_store.dart';
import 'package:pagestage_app/playback/just_audio_engine.dart';
import 'package:pagestage_app/playback/playback_queue.dart';
import 'package:pagestage_app/storage.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:path_provider/path_provider.dart';

import '../test/application/support.dart' show MemorySecrets, MemorySpeech;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('bundled first chapters play to completion without keys', (
    tester,
  ) async {
    final parent = await getApplicationSupportDirectory();
    final directory = await parent.createTemp('bundled-examples-');
    final storage = await AppStorage.open(directory: directory);
    await installBundledExamples(storage.store);
    final providers = await ProviderStore.open(storage.store, MemorySecrets());
    final consents = ConsentBroker(storage.store);
    final speech = MemorySpeech();
    final engine = JustAudioEngine();
    final listening = ListeningController(
      store: storage.store,
      engine: engine,
      speech: speech,
    );
    var providerCalls = 0;
    Never unexpectedProvider() {
      providerCalls++;
      throw StateError('Bundled playback must not use a provider');
    }

    final casts = await CastController.open(
      store: storage.store,
      providers: providers,
      consents: consents,
      listening: listening,
      auditionEngine: JustAudioEngine(),
      profileFactory: (_) => unexpectedProvider(),
      directorFactory: (_) => unexpectedProvider(),
      auditionFactory: (_, _) => unexpectedProvider(),
    );
    final generation = await GenerationController.open(
      storage.store,
      casts.scheduler,
    );
    listening.attachGeneration(generation);
    try {
      await (await AudioSession.instance).configure(
        const AudioSessionConfiguration.speech(),
      );
      await tester.pumpWidget(
        PagestageApp(
          bookshelf: storage.library,
          readingSettings: storage.readingSettings,
          services: AppServices(
            listening: listening,
            providers: providers,
            consents: consents,
            casts: casts,
            generation: generation,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final books = await storage.library.listBooks();
      expect(books, hasLength(2));
      for (final book in books) {
        expect(find.text(book.title), findsWidgets);
        expect(book.chapters, hasLength(1));
        expect(
          (await storage.library.chapters(book.id)).single.state,
          ChapterState.synthesized,
        );
        await listening.open(book.id);
        await listening.pause();
        expect(listening.value.source, ListeningSource.synthesized);
        final audio = (await AudioRepository(storage.store).get(book.id, 1))!;
        final queue = PlaybackQueue(audio.utterances);
        final script = (await ScriptRepository(storage.store).get(book.id, 1))!;
        final lines = await listening.lines(book.id, 1);
        for (final entry in queue.entries) {
          final line = entry.utterance.lineIndices.first;
          await listening.seek(
            entry.audioStart + const Duration(milliseconds: 10),
          );
          await tester.pump(const Duration(milliseconds: 50));
          expect(listening.value.line, line);
          expect(
            lines[line].text,
            script.lines[line].textIn(book.chapters.single.text),
          );
        }
        await listening.seek(Duration.zero);
        await listening.setSpeed(3);
        await listening.play();
        final deadline = DateTime.now().add(
          queue.duration ~/ 3 + const Duration(seconds: 30),
        );
        final visited = <int>{};
        while (listening.value.error != 'endOfBook' &&
            DateTime.now().isBefore(deadline)) {
          await tester.pump(const Duration(milliseconds: 100));
          visited.add(listening.value.line);
          expect(engine.state.error, isNull);
        }
        expect(listening.value.error, 'endOfBook');
        expect(visited.length, greaterThan(1));
        expect(providerCalls, 0);
        expect(speech.requests, isEmpty);
        expect(consents.value, isNull);
        expect(generation.value.request, isNull);
        debugPrint(
          'BUNDLED_VERIFIED ${book.title}: ${queue.duration.inMilliseconds} ms, ${queue.entries.length} utterances',
        );
      }
      for (final book in books) {
        await storage.library.deleteBook(book.id);
      }
      await installBundledExamples(storage.store);
      expect(await storage.library.listBooks(), isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await consents.close();
      await listening.close();
      await generation.close();
      await casts.close();
      providers.dispose();
      await storage.close();
      await directory.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
