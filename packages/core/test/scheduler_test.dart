import 'dart:async';
import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

import 'support/generation_fakes.dart';
import 'support/fake_request_clock.dart';

void main() {
  late Directory dir;
  late LocalStore store;
  late Book book;
  late GenerationLlm profile;
  late GenerationLlm director;
  late GenerationTts tts;
  Scheduler? scheduler;

  Future<Scheduler> open({Map<String, TtsAdapter>? adapters}) async =>
      scheduler = await Scheduler.open(
        store: store,
        profileLlm: profile,
        directorLlm: director,
        ttsAdapters: adapters ?? {'minimax': tts},
      );

  Future<void> prepare() async {
    await Profiler(store, profile).profile(book, throughChapter: 5);
    await Casting(store).recommend(book, providers: {'minimax'});
    profile.chapters.clear();
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('scheduler-');
    store = LocalStore('${dir.path}/db.sqlite');
    final file = await File('${dir.path}/novel.txt').writeAsString(
      [for (var i = 1; i <= 5; i++) 'Chapter $i\nWind $i.\nHome $i.\n'].join(),
    );
    book = await Library(store).importTxt(file.path);
    profile = GenerationLlm();
    director = GenerationLlm();
    tts = GenerationTts();
  });
  tearDown(() async {
    await scheduler?.close();
    scheduler = null;
    await store.close();
    await dir.delete(recursive: true);
  });

  test(
    'idle reading makes no tasks or requests; listening clamps to profiled range',
    () async {
      await prepare();
      final s = await open();
      await s.idle;
      expect(s.tasks, isEmpty);
      await Library(store).paragraphs(book.id, 1);
      expect(director.chapters, isEmpty);
      await s.reportListening(book.id, chapter: 1);
      await s.idle;
      expect(director.chapters, [2, 3]);
      expect(tts.requests, hasLength(2));
      expect((await AudioRepository(store).get(book.id, 2))!.complete, isTrue);
      await s.reportListening(book.id, chapter: 5);
      await s.idle;
      expect(director.chapters, [2, 3]);
    },
  );

  test(
    'zero lookahead disables work and invalid settings are rejected',
    () async {
      await prepare();
      final s = await open();
      expect(() => Lookahead(directing: 1, synthesis: 2), throwsArgumentError);
      await s.reportListening(
        book.id,
        chapter: 1,
        lookahead: Lookahead(directing: 0, synthesis: 0),
      );
      await s.idle;
      expect(s.tasks, isEmpty);
    },
  );

  test('profiling resumes chapter checkpoints after recreation', () async {
    var s = await open();
    s.events.listen((event) {
      if (event.task.chapter == 2 &&
          event.task.status == TaskStatus.completed) {
        unawaited(s.close());
      }
    });
    await s.enqueue(book.id, TaskKind.profile, through: 5);
    await s.idle;
    expect(profile.chapters, [1, 2]);
    await store.close();
    store = LocalStore('${dir.path}/db.sqlite');
    s = await open();
    await s.idle;
    expect(profile.chapters, [1, 2, 3, 4, 5]);
    expect(
      s.tasks.every((task) => task.status == TaskStatus.completed),
      isTrue,
    );
  });

  test('user work runs before queued lookahead work', () async {
    await prepare();
    final s = await open();
    final started = Completer<void>();
    final release = Completer<void>();
    director.before = (chapter) async {
      if (chapter == 2) {
        started.complete();
        await release.future;
      }
    };
    await s.reportListening(
      book.id,
      chapter: 1,
      lookahead: Lookahead(directing: 2, synthesis: 0),
    );
    await started.future;
    await s.enqueue(book.id, TaskKind.direct, first: 5, through: 5);
    release.complete();
    await s.idle;
    expect(director.chapters, [2, 5, 3]);
  });

  test(
    'first utterance is durable and playable while the next request is pending',
    () async {
      await prepare();
      final s = await open();
      final second = Completer<void>();
      final release = Completer<void>();
      tts.before = (n) async {
        if (n == 2) {
          second.complete();
          await release.future;
        }
      };
      final emitted = <SynthesizedUtterance>[];
      s.events.listen((e) {
        if (e.utterance != null) emitted.add(e.utterance!);
      });
      await s.enqueue(book.id, TaskKind.synthesize, first: 1, through: 1);
      await second.future;
      expect(emitted, hasLength(1));
      final audio = (await AudioRepository(store).get(book.id, 1))!;
      expect(audio.complete, isFalse);
      expect(await File(audio.utterances.single.audioPath).exists(), isTrue);
      release.complete();
      await s.idle;
      expect((await AudioRepository(store).get(book.id, 1))!.complete, isTrue);
    },
  );

  for (final kind in [
    ProviderErrorKind.invalidKey,
    ProviderErrorKind.insufficientBalance,
    ProviderErrorKind.invalidResponse,
    ProviderErrorKind.unavailable,
  ]) {
    test(
      '$kind pauses with provider and resumes without repeating completed audio',
      () async {
        await prepare();
        var s = await open();
        tts.before = (n) {
          if (n == 2) throw ProviderException(provider: 'minimax', kind: kind);
        };
        await s.enqueue(book.id, TaskKind.synthesize, first: 1, through: 2);
        await s.idle;
        final paused = s.tasks.singleWhere(
          (t) => t.status == TaskStatus.paused,
        );
        expect(paused.provider, 'minimax');
        expect(paused.reason, kind);
        expect(paused.completedUtterances, 1);
        await s.close();
        scheduler = null;
        await store.close();
        store = LocalStore('${dir.path}/db.sqlite');
        tts.before = null;
        s = await open();
        await s.idle;
        expect(tts.requests, hasLength(2));
        await s.resume(provider: 'minimax');
        await s.idle;
        expect(
          tts.requests,
          hasLength(5),
        ); // 4 lines plus the rejected attempt.
        expect(s.tasks.every((t) => t.status == TaskStatus.completed), isTrue);
      },
    );
  }

  test(
    'stopping listening discards pending lookahead until listening is reported again',
    () async {
      await prepare();
      var s = await open();
      final started = Completer<void>();
      final release = Completer<void>();
      director.before = (chapter) async {
        if (chapter == 2) {
          started.complete();
          await release.future;
        }
      };
      await s.reportListening(
        book.id,
        chapter: 1,
        lookahead: Lookahead(directing: 2, synthesis: 0),
      );
      await started.future;
      await s.reportListening(null);
      release.complete();
      await s.idle;
      expect(director.chapters, [2]);
      await s.close();
      scheduler = null;
      director.before = null;
      s = await open();
      await s.idle;
      expect(director.chapters, [2]);
      await s.reportListening(
        book.id,
        chapter: 1,
        lookahead: Lookahead(directing: 2, synthesis: 0),
      );
      await s.idle;
      expect(director.chapters, [2, 3]);
    },
  );

  test(
    'LLM failure pauses dependent profiling chapters and later resumes',
    () async {
      final s = await open();
      profile.before = (chapter) {
        if (chapter == 2) {
          throw const ProviderException(
            provider: 'llm',
            kind: ProviderErrorKind.invalidKey,
          );
        }
      };
      await s.enqueue(book.id, TaskKind.profile, through: 3);
      await s.idle;
      expect(profile.chapters, [1, 2]);
      profile.before = null;
      await s.resume(provider: 'llm');
      await s.idle;
      expect(profile.chapters, [1, 2, 2, 3]);
    },
  );

  test(
    'exhausted request recovery pauses after three attempts using a fake clock',
    () async {
      await prepare();
      final clock = FakeRequestClock();
      tts.before = (_) => throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.rateLimited,
      );
      final queued = ScheduledTtsAdapter(
        tts,
        ProviderRequestQueue(
          provider: 'minimax',
          requestsPerMinute: 60,
          runtime: clock.runtime,
        ),
      );
      final s = await open(adapters: {'minimax': queued});
      await s.enqueue(book.id, TaskKind.synthesize, through: 1);
      await s.idle;
      expect(tts.requests, hasLength(3));
      expect(clock.waits, [
        const Duration(seconds: 60),
        const Duration(seconds: 60),
      ]);
      expect(s.tasks.last.reason, ProviderErrorKind.rateLimited);
      tts.before = null;
      await s.resume();
      await s.idle;
      expect(s.tasks.last.status, TaskStatus.completed);
    },
  );

  test(
    'recovers a running task after the previous process exits abruptly',
    () async {
      await store.close();
      final child = await Process.run(Platform.resolvedExecutable, [
        'packages/core/test/support/scheduler_crash_worker.dart',
        dir.path,
      ]);
      expect(child.exitCode, 0, reason: '${child.stderr}');
      store = LocalStore('${dir.path}/db.sqlite');
      final s = await open();
      await s.idle;
      expect(profile.chapters, [2, 3]);
      expect((await CastRepository(store).get(book.id)).profiledThrough, 3);
      expect(
        s.tasks.every((task) => task.status == TaskStatus.completed),
        isTrue,
      );
    },
  );

  test(
    'deleting a book during an accepted request cannot restore it or its audio',
    () async {
      await prepare();
      final s = await open();
      final started = Completer<void>();
      final release = Completer<void>();
      tts.before = (_) async {
        started.complete();
        await release.future;
      };
      await s.enqueue(book.id, TaskKind.synthesize, through: 1);
      await started.future;
      await Library(store).deleteBook(book.id);
      release.complete();
      await s.idle;
      expect(await Library(store).books(), isEmpty);
      expect(await AudioRepository(store).get(book.id, 1), isNull);
      expect(
        await AudioRepository(store).bookDirectory(book.id).exists(),
        isFalse,
      );
      expect(s.tasks, isEmpty);
      expect(tts.requests, hasLength(1));
    },
  );

  test('closing during synthesis resumes from the saved utterance', () async {
    await prepare();
    var s = await open();
    s.events.listen((event) {
      if (event.utterance != null) unawaited(s.close());
    });
    await s.enqueue(book.id, TaskKind.synthesize, through: 1);
    await s.idle;
    expect(tts.requests, hasLength(1));
    expect((await AudioRepository(store).get(book.id, 1))!.complete, isFalse);
    s = await open();
    await s.idle;
    expect(tts.requests, hasLength(2));
    expect(s.tasks.last.status, TaskStatus.completed);
  });

  test(
    'a completed chapter is reused until a selected voice changes',
    () async {
      await prepare();
      final s = await open();
      await s.enqueue(book.id, TaskKind.synthesize, through: 1);
      await s.idle;
      await s.enqueue(book.id, TaskKind.synthesize, through: 1);
      await s.idle;
      expect(tts.requests, hasLength(2));
      final casting = Casting(store);
      final voice = (await casting.getCasting(book.id)).voices['narrator']!;
      await casting.selectVoice(
        book,
        'narrator',
        voice.copyWith(
          binding: VoiceBinding(
            provider: 'minimax',
            model: voice.binding.model,
            voiceId: 'another-voice',
          ),
        ),
      );
      expect(
        (await Library(store).chapters(book.id)).first.state,
        ChapterState.directed,
      );
      await s.enqueue(book.id, TaskKind.synthesize, through: 1);
      await s.idle;
      expect(tts.requests, hasLength(4));
    },
  );

  test(
    'rejects generation outside the profiled range without requests',
    () async {
      final s = await open();
      await expectLater(
        s.enqueue(book.id, TaskKind.synthesize, through: 1),
        throwsStateError,
      );
      await s.reportListening(book.id, chapter: 1);
      await s.idle;
      expect(s.tasks, isEmpty);
      expect(tts.requests, isEmpty);
    },
  );
  test(
    'cleanup at task-start notification holds the checkpoint before removing tasks',
    () async {
      await prepare();
      final s = await open();
      Future<void>? cleanup;
      final subscription = s.events.listen((event) {
        if (cleanup == null &&
            event.task.kind == TaskKind.direct &&
            event.task.status == TaskStatus.running) {
          cleanup = s.withBookPaused(
            book.id,
            () => s.cancelGeneration(book.id),
          );
        }
      });
      await s.enqueue(book.id, TaskKind.synthesize, through: 1);
      await s.idle;
      await cleanup;
      await s.idle;
      await subscription.cancel();
      expect(cleanup, isNotNull);
      expect(director.chapters, isEmpty);
      expect(tts.requests, isEmpty);
      expect(s.tasks, isEmpty);
    },
  );
}
