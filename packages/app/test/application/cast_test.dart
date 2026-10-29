import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/cast_controller.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/application/listening_controller.dart';
import 'package:pagestage_app/application/provider_store.dart';
import 'package:pagestage_core/pagestage_core.dart';

import '../../../core/test/support/generation_fakes.dart';
import 'support.dart';

void main() {
  late Directory root;
  late LocalStore store;
  late ProviderStore providers;
  late MemorySecrets secrets;
  late ConsentBroker consents;
  late ListeningController listening;
  late CastController casts;
  late Book book;
  late GenerationLlm llm;
  late GenerationTts tts;
  bool accepted = true;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('cast-app-');
    store = LocalStore('${root.path}/db.sqlite');
    book = await importBook(store, root);
    secrets = MemorySecrets();
    providers = await ProviderStore.open(store, secrets);
    await providers.save(
      const ProviderPreferences(
        baseUrl: 'https://example.test/v1',
        profileModel: 'offline',
      ),
      llmKey: 'test-key',
      minimaxKey: 'test-key',
    );
    consents = ConsentBroker(store);
    accepted = true;
    consents.addListener(() {
      final request = consents.value;
      if (request != null) consents.respond(request.id, accepted: accepted);
    });
    listening = ListeningController(
      store: store,
      engine: MemoryEngine(),
      speech: MemorySpeech(),
    );
    llm = GenerationLlm();
    tts = GenerationTts();
    casts = await CastController.open(
      store: store,
      providers: providers,
      consents: consents,
      listening: listening,
      auditionEngine: MemoryEngine(),
      profileFactory: (_) => llm,
      auditionFactory: (_, _) => tts,
    );
  });
  tearDown(() async {
    await consents.close();
    await casts.close();
    await listening.close();
    providers.dispose();
    await store.close();
    await root.delete(recursive: true);
  });

  test('cancelling consent sends no profiling requests or tasks', () async {
    accepted = false;
    await casts.profile(book.id, through: 1);
    await casts.idle;
    expect(llm.chapters, isEmpty);
    expect(casts.scheduler.tasks, isEmpty);
  });

  test(
    'casting waits for a voice provider and goes on once one is on',
    () async {
      await providers.save(providers.value.switched('minimax', false));
      await casts.profile(book.id, through: 1);
      await casts.idle;
      final waiting = await casts.load(book.id);
      expect(waiting.status, ProfilingStatus.paused);
      expect(waiting.reason, 'noVoiceProvider');
      expect(waiting.members.single.provider, isNull);

      await providers.save(providers.value.switched('edge', true));
      await casts.idle;
      final cast = await casts.load(book.id);
      expect(cast.status, ProfilingStatus.complete);
      expect(cast.members.single.provider, 'edge');
    },
  );

  test('rematch moves voices off a switched-off provider only', () async {
    await casts.profile(book.id, through: 1);
    await casts.idle;
    expect((await casts.load(book.id)).members.single.provider, 'minimax');

    await providers.save(
      providers.value.switched('minimax', false).switched('edge', true),
    );
    await casts.idle;
    // Switching providers never recasts a finished cast by itself.
    expect((await casts.load(book.id)).members.single.provider, 'minimax');
    await casts.rematch(book.id);
    expect((await casts.load(book.id)).members.single.provider, 'edge');
  });

  test('a new key turns its provider on; switches survive a restart', () async {
    await providers.save(providers.value.switched('minimax', false));
    expect(providers.value.voiceProviders, isEmpty);
    await providers.save(providers.value, minimaxKey: 'another-key');
    expect(providers.value.voiceProviders, {'minimax'});
    await providers.save(providers.value.switched('edge', true));
    final reopened = await ProviderStore.open(store, secrets);
    expect(reopened.value.voiceProviders, {'minimax', 'edge'});
    reopened.dispose();
  });

  test(
    'with only Edge on, casting picks Edge and auditions through Microsoft consent',
    () async {
      await providers.save(
        providers.value.switched('edge', true),
        minimaxKey: '',
      );
      final destinations = <ConsentRequest>[];
      consents.addListener(() {
        if (consents.value case final request?) destinations.add(request);
      });
      await casts.profile(book.id, through: 1);
      await casts.idle;
      expect((await casts.load(book.id)).members.single.provider, 'edge');
      await casts.audition(book.id, 'narrator');
      expect(tts.requests.single.binding.provider, 'edge');
      expect(
        destinations.any(
          (r) =>
              r.provider == 'edge' &&
              r.endpoint == EdgeTtsAdapter.defaultEndpoint,
        ),
        isTrue,
      );
    },
  );

  test(
    'profiles selected range, casts, extends preserving voices and caches auditions',
    () async {
      await casts.profile(book.id, through: 1);
      await casts.idle;
      final first = await casts.load(book.id);
      expect(first.profiledThrough, 1);
      expect(first.status, ProfilingStatus.complete);
      expect(first.members.single.provider, 'minimax');
      final voice = (await Casting(
        store,
      ).getCasting(book.id)).voices['narrator']!;
      await casts.audition(book.id, 'narrator');
      await casts.audition(book.id, 'narrator');
      expect(tts.requests, hasLength(1));
      await casts.profile(book.id, through: 2);
      await casts.idle;
      expect(llm.chapters, [1, 2]);
      expect((await casts.load(book.id)).profiledThrough, 2);
      expect(
        (await Casting(store).getCasting(book.id)).voices['narrator']!.id,
        voice.id,
      );
      await casts.setExclusiveCount(4);
      expect(casts.exclusiveCount, 4);
      expect((await store.get('settings', 'casting'))!['exclusiveCount'], 4);
    },
  );

  test(
    'provider failure pauses, corrected settings resume without repeating finished chapter',
    () async {
      llm.before = (chapter) {
        if (chapter == 2) {
          throw const ProviderException(
            provider: 'llm',
            kind: ProviderErrorKind.insufficientBalance,
          );
        }
      };
      await casts.profile(book.id, through: 2);
      await casts.idle;
      final paused = await casts.load(book.id);
      expect(paused.profiledThrough, 1);
      expect(paused.status, ProfilingStatus.paused);
      expect(paused.reason, 'quotaExceeded');
      llm.before = null;
      await casts.resume(book.id);
      await casts.idle;
      expect(llm.chapters, [1, 2, 2]);
      expect((await casts.load(book.id)).status, ProfilingStatus.complete);
    },
  );
  test('profiling a paused book moves its target down and continues', () async {
    llm.before = (chapter) {
      if (chapter == 1) {
        throw const ProviderException(
          provider: 'llm',
          kind: ProviderErrorKind.invalidResponse,
          code: LlmFailure.requestRejected,
        );
      }
    };
    await casts.profile(book.id, through: 2);
    await casts.idle;
    final paused = await casts.load(book.id);
    expect(paused.status, ProfilingStatus.paused);
    expect(paused.targetChapter, 2);
    expect(paused.reason, 'requestRejected');
    llm.before = null;
    await casts.profile(book.id, through: 1);
    await casts.idle;
    final done = await casts.load(book.id);
    expect(done.status, ProfilingStatus.complete);
    expect(done.profiledThrough, 1);
    expect(done.targetChapter, 1);
    expect(
      casts.scheduler.tasks.where(
        (t) => t.kind == TaskKind.profile && t.chapter == 2,
      ),
      isEmpty,
    );
  });
  test(
    'reopening interrupted profiling continues from completed chapters',
    () async {
      final gate = Completer<void>();
      llm.before = (chapter) async {
        if (chapter == 1) await gate.future;
      };
      await casts.profile(book.id, through: 2);
      while (llm.chapters.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final closing = casts.close();
      gate.complete();
      await closing;
      expect((await CastRepository(store).get(book.id)).profiledThrough, 1);
      llm.before = null;
      casts = await CastController.open(
        store: store,
        providers: providers,
        consents: consents,
        listening: listening,
        auditionEngine: MemoryEngine(),
        profileFactory: (_) => llm,
        auditionFactory: (_, _) => tts,
      );
      await casts.idle;
      expect(llm.chapters, [1, 2]);
      expect((await casts.load(book.id)).status, ProfilingStatus.complete);
    },
  );

  test(
    'stopping an in-flight audition caches the result without playing it',
    () async {
      await casts.profile(book.id, through: 1);
      await casts.idle;
      final gate = Completer<void>();
      tts.before = (_) => gate.future;
      final pending = casts.audition(book.id, 'narrator');
      while (tts.requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await casts.stopAudition();
      gate.complete();
      await pending;
      expect(casts.auditionEngine.state.playing, isFalse);
      await casts.audition(book.id, 'narrator');
      expect(tts.requests, hasLength(1));
      expect(casts.auditionEngine.state.playing, isTrue);
    },
  );
  test(
    'TTS consent is independent and cancellation performs no synthesis',
    () async {
      await casts.profile(book.id, through: 1);
      await casts.idle;
      accepted = false;
      final seen = <ConsentRequest>[];
      void capture() {
        if (consents.value != null) seen.add(consents.value!);
      }

      consents.addListener(capture);
      await casts.audition(book.id, 'narrator');
      expect(tts.requests, isEmpty);
      expect(seen.single.provider, 'minimax');
      expect(seen.single.endpoint, 'https://api.minimax.io/v1');
      consents.removeListener(capture);
    },
  );
  test('local task failures expose only localized categories', () async {
    llm.before = (_) => throw StateError('private-response-content');
    await casts.profile(book.id, through: 1);
    await casts.idle;
    final state = await casts.load(book.id);
    expect(state.status, ProfilingStatus.paused);
    expect(state.provider, 'system');
    expect(state.reason, 'interrupted');
    expect(
      (await store.list('tasks')).toString(),
      isNot(contains('private-response-content')),
    );
  });
}
