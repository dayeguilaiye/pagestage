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
    providers = await ProviderStore.open(store, MemorySecrets());
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
