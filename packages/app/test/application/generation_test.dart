import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/audio_storage_controller.dart';
import 'package:pagestage_app/application/cast_controller.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/application/generation_controller.dart';
import 'package:pagestage_app/application/listening_controller.dart';
import 'package:pagestage_app/application/provider_store.dart';
import 'package:pagestage_app/application/voice_controller.dart';
import 'package:pagestage_app/playback/playback_engine.dart';
import 'package:pagestage_core/pagestage_core.dart';
import '../../../core/test/support/generation_fakes.dart';
import 'support.dart';

Future<void> eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition did not become true.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class PlaylistEngine extends MemoryEngine implements GrowingPlaybackEngine {
  final segments = <PlaybackSegment>[];
  int replacements = 0;
  int appends = 0;
  @override
  Future<void> loadPlaylist(List<PlaybackSegment> values) async {
    replacements++;
    segments
      ..clear()
      ..addAll(values);
    await load(
      values.first.path,
      segments.fold<Duration>(Duration.zero, (t, s) => t + s.duration),
    );
  }

  @override
  Future<void> appendPlaylist(List<PlaybackSegment> values) async {
    appends++;
    segments.addAll(values);
    emit(
      duration: segments.fold<Duration>(
        Duration.zero,
        (t, s) => t + s.duration,
      ),
    );
  }
}

class DesignTts extends GenerationTts implements VoiceDesignAdapter {
  final designs = <VoiceDesignRequest>[];
  final invalid = <String>{};
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    if (invalid.contains(request.binding.voiceId)) {
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.invalidVoice,
      );
    }
    return super.synthesize(request);
  }

  @override
  Future<DesignedVoice> design(VoiceDesignRequest request) async {
    designs.add(request);
    return DesignedVoice(
      binding: VoiceBinding(
        provider: 'minimax',
        model: request.model,
        voiceId: 'designed-${designs.length}',
        designed: true,
      ),
      preview: VoicePreview.detect(
        PcmAudio(
          samples: Int16List.fromList(List.filled(240, 700)),
          sampleRate: 24000,
        ).toWav(),
      ),
    );
  }
}

void main() {
  late Directory root;
  late LocalStore store;
  late Book book;
  late ProviderStore providers;
  late ConsentBroker consents;
  late ListeningController listening;
  late PlaylistEngine engine;
  late MemorySpeech speech;
  late CastController casts;
  late GenerationController generation;
  late VoiceController voices;
  late AudioStorageController storage;
  late GenerationLlm profile;
  late GenerationLlm director;
  late DesignTts tts;
  bool accept = true;
  Future<void> prepare() async {
    await casts.profile(book.id, through: 2);
    await casts.idle;
  }

  /// AI voices on for new books, preparing [ahead] chapters ahead.
  Future<void> automatic({int ahead = 0}) =>
      generation.savePreferences(GenerationPreferences(ahead: ahead));
  setUp(() async {
    root = await Directory.systemTemp.createTemp('generation-app-');
    store = LocalStore('${root.path}/db.sqlite');
    final file = await File('${root.path}/source.txt').writeAsString(
      'Chapter 1\nOne.\nTwo.\nThree.\nChapter 2\nFour.\nFive.\nChapter 3\nSix.\n',
    );
    book = await Library(store).importTxt(file.path);
    providers = await ProviderStore.open(store, MemorySecrets());
    await providers.configure(
      'llm',
      values: {'baseUrl': 'https://offline.test/v1', 'profileModel': 'fake'},
      secrets: {'key': 'fake'},
    );
    await providers.configure('minimax', secrets: {'key': 'fake'});
    consents = ConsentBroker(store);
    accept = true;
    consents.addListener(() {
      if (consents.value case final request?) {
        consents.respond(request.id, accepted: accept);
      }
    });
    // As setting a provider up asks: work in the background never does.
    for (final id in ['llm', 'minimax']) {
      final endpoint = await providers.endpoint(id);
      await consents.request(
        provider: id,
        endpoint: endpoint!,
        content: 'chapterTextAndCast',
      );
    }
    engine = PlaylistEngine();
    speech = MemorySpeech();
    listening = ListeningController(
      store: store,
      engine: engine,
      speech: speech,
    );
    profile = GenerationLlm();
    director = GenerationLlm();
    tts = DesignTts();
    casts = await CastController.open(
      store: store,
      providers: providers,
      consents: consents,
      listening: listening,
      auditionEngine: MemoryEngine(),
      profileFactory: (_) => profile,
      directorFactory: (_) => director,
      auditionFactory: (_, _) => tts,
    );
    generation = await GenerationController.open(store, casts.scheduler);
    listening.attachGeneration(generation);
    voices = await VoiceController.open(store, casts, listening);
    storage = AudioStorageController(store, casts, listening, voices);
  });
  tearDown(() async {
    await listening.pause();
    await consents.close();
    storage.dispose();
    await voices.close();
    await casts.idle;
    await listening.close();
    await generation.close();
    await casts.close();
    providers.dispose();
    await store.close();
    await root.delete(recursive: true);
  });
  test(
    'prepared chapter plays directly with no keys or generation requests',
    () async {
      await prepare();
      await casts.scheduler.enqueue(book.id, TaskKind.synthesize, through: 2);
      await casts.idle;
      final original = (await AudioRepository(store).get(book.id, 1))!;
      final compressed = await File(
        '${root.path}/example.m4a',
      ).writeAsBytes(List.filled(64, 0));
      final json = original.toJson();
      json['path'] = compressed.path;
      json['utterances'] = [
        for (final u in original.utterances)
          {
            ...u.toJson(),
            'audioPath': compressed.path,
            'rawAudioPath': compressed.path,
          },
      ];
      await AudioRepository(store).save(ChapterAudio.fromJson(json));
      final count = tts.requests.length;
      await providers.configure('llm', secrets: {'key': ''});
      await providers.configure('minimax', secrets: {'key': ''});
      await automatic();
      await listening.open(book.id);
      expect(engine.loads.last, compressed.path);
      expect(engine.replacements, 0);
      expect(listening.value.source, ListeningSource.synthesized);
      expect(listening.value.playing, isTrue);
      expect(tts.requests.length, count);
      expect(speech.requests, isEmpty);
      await listening.nextLine();
      expect(listening.value.line, 1);
    },
  );

  test(
    'library update refreshes active chapter count while retaining its bookmark',
    () async {
      await prepare();
      await automatic();
      await listening.open(book.id);
      await casts.idle;
      await listening.settled;
      await listening.nextLine();
      final library = Library(store);
      library.editBook = (id, action) async {
        await listening.invalidate(id);
        await casts.scheduler.withBookPaused(id, () async {
          await casts.scheduler.cancelGeneration(id);
          await action();
        });
        await listening.refreshBook(id);
      };
      final source = await File('${root.path}/updated.txt').writeAsString(
        'Chapter 1\nOne.\nTwo.\nThree.\nChapter 2\nFour.\nFive.\nChapter 3\nSix.\nChapter 4\nNew chapter.\n',
      );
      final outcome = await library.importFile(source.path);
      expect(outcome.book.id, book.id);
      expect(outcome.addedChapters, 1);
      expect(listening.value.chapterCount, 4);
      expect(listening.value.playing, isFalse);
      expect(listening.value.line, 1);
      await listening.play();
      expect(listening.value.playing, isTrue);
      expect(listening.value.line, 1);
    },
  );

  test(
    'reading stays idle; a book with AI voices off reads in the system voice without asking',
    () async {
      await listening.lines(book.id, 1);
      await casts.idle;
      expect(director.chapters, isEmpty);
      await generation.setAiVoice(book.id, false);
      await listening.open(book.id);
      expect(listening.value.source, ListeningSource.system);
      expect(listening.value.aiVoice, isFalse);
      expect(listening.value.fallback, isFalse);
      expect(listening.value.playing, isTrue);
      expect(speech.requests, isNotEmpty);
      await casts.idle;
      expect(tts.requests, isEmpty);
      expect(director.chapters, isEmpty);
      expect(profile.chapters, isEmpty);
    },
  );
  test(
    'with AI voices on, an unprofiled chapter is profiled, directed and voiced without asking',
    () async {
      await automatic();
      await listening.open(book.id);
      await casts.idle;
      await eventually(
        () =>
            listening.value.playing &&
            listening.value.source == ListeningSource.synthesized,
      );
      expect(profile.chapters, contains(1));
      expect(director.chapters, [1]);
      expect(speech.requests, isEmpty);
      expect(listening.value.aiVoice, isTrue);
    },
  );
  test(
    'voices not ready in time: the system voice reads the chapter, the next one switches back',
    () async {
      await prepare();
      await automatic();
      final quick = ListeningController(
        store: store,
        engine: PlaylistEngine(),
        speech: speech,
        fallbackAfter: const Duration(milliseconds: 100),
      );
      quick.attachGeneration(generation);
      addTearDown(() async {
        await quick.pause();
        await quick.settled;
      });
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      tts.before = (n) => n == 1 ? release.future : null;
      await quick.open(book.id);
      expect(quick.value.waitingSince, isNotNull);
      await eventually(() => quick.value.source == ListeningSource.system);
      expect(quick.value.fallback, isTrue);
      expect(quick.value.playing, isTrue);
      expect(speech.requests, isNotEmpty);
      release.complete();
      await casts.idle;
      await quick.nextChapter();
      await casts.idle;
      await eventually(
        () =>
            quick.value.chapter == 2 &&
            quick.value.source == ListeningSource.synthesized &&
            quick.value.playing,
      );
      expect(quick.value.fallback, isFalse);
    },
  );
  test('a paused book reads in the system voice at once', () async {
    await prepare();
    await automatic();
    tts.before = (n) => throw const ProviderException(
      provider: 'minimax',
      kind: ProviderErrorKind.invalidKey,
    );
    await listening.open(book.id);
    await casts.idle;
    await eventually(
      () =>
          generation.value.failures.isNotEmpty &&
          listening.value.source == ListeningSource.system &&
          listening.value.playing,
    );
    expect(listening.value.fallback, isTrue);
    expect(generation.value.failures.single.reason, 'unauthorized');
    tts.before = null;
  });
  test(
    'first utterance starts early; playlist grows and buffers without system fallback',
    () async {
      await prepare();
      await automatic();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      tts.before = (n) => n == 2 ? release.future : null;
      await listening.open(book.id);
      await eventually(() => listening.value.playing);
      expect(tts.requests.length, 2);
      expect((await AudioRepository(store).get(book.id, 1))!.complete, isFalse);
      expect(engine.segments, hasLength(1));
      engine.complete();
      await eventually(() => listening.value.buffering);
      expect(speech.requests, isEmpty);
      release.complete();
      await casts.idle;
      await eventually(
        () => engine.segments.length == 3 && listening.value.playing,
      );
      expect(engine.replacements, 1);
      expect(engine.appends, greaterThan(0));
      final timing = await File(
        '${root.path}/generation-timing.jsonl',
      ).readAsString();
      expect(timing, contains('elapsedMs'));
      expect(timing, isNot(contains('One.')));
      expect(timing, isNot(contains('fake')));
    },
  );
  test(
    'lookahead profiles ahead and the next chapter continues without asking',
    () async {
      await prepare();
      await automatic(ahead: 1);
      await listening.open(book.id);
      await eventually(() => listening.value.playing);
      await casts.idle;
      // Chapter 3 was not profiled; lookahead profiles it on the way.
      expect(director.chapters.toSet(), {1, 2, 3});
      expect(profile.chapters, contains(3));
      await listening.settled;
      engine.complete();
      await eventually(
        () =>
            listening.value.chapter == 2 &&
            listening.value.playing &&
            listening.value.source == ListeningSource.synthesized,
      );
      expect(speech.requests, isEmpty);
      await listening.pause();
    },
  );
  test(
    'provider failure pauses and resume reuses first cached utterance',
    () async {
      await prepare();
      await automatic();
      tts.before = (n) {
        if (n == 2) {
          throw const ProviderException(
            provider: 'minimax',
            kind: ProviderErrorKind.insufficientBalance,
          );
        }
      };
      await listening.open(book.id);
      await casts.idle;
      await eventually(
        () => generation.value.failures.isNotEmpty && listening.value.playing,
      );
      expect(generation.value.failures.single.reason, 'quotaExceeded');
      // Out of credit: the system voice reads on from the line after the
      // voiced one instead of leaving the listener in silence.
      engine.complete();
      await eventually(
        () =>
            listening.value.source == ListeningSource.system &&
            listening.value.fallback,
      );
      expect(speech.requests, isNotEmpty);
      expect(speech.requests.first.$1, isNot(contains('One.')));
      tts.before = null;
      await generation.resume(book.id);
      await casts.idle;
      await eventually(() => generation.value.failures.isEmpty);
      expect((await AudioRepository(store).get(book.id, 1))!.complete, isTrue);
      expect(tts.requests.where((r) => r.text.trim() == 'One.'), hasLength(1));
    },
  );
  test(
    'mode persists and switching drama reuses existing speech cache',
    () async {
      await prepare();
      await automatic();
      await Director(store, director).direct(book, 1);
      final script = (await ScriptRepository(store).get(book.id, 1))!;
      await ScriptRepository(store).save(
        Script(
          bookId: book.id,
          chapterNumber: 1,
          sourceTextHash: script.sourceTextHash,
          model: script.model,
          promptVersion: script.promptVersion,
          lines: [
            for (var i = 0; i < script.lines.length; i++)
              ScriptLine(
                start: script.lines[i].start,
                end: script.lines[i].end,
                direction: script.lines[i].direction,
                isDialogueTag: i == 1,
              ),
          ],
        ),
      );
      await listening.open(book.id);
      await casts.idle;
      await eventually(() => engine.segments.length == 3);
      expect(tts.requests, hasLength(3));
      await generation.setMode(book.id, BookPerformanceMode.drama);
      await casts.idle;
      // The chapter playing finishes as it is; the change applies next.
      await listening.settled;
      expect(engine.segments, hasLength(3));
      await listening.open(book.id, chapter: 1);
      await casts.idle;
      await eventually(() => engine.segments.length == 2);
      expect(tts.requests, hasLength(3));
      expect(await generation.mode(book.id), BookPerformanceMode.drama);
      expect((await store.get('performance', book.id))!['mode'], 'drama');
      await expectLater(
        generation.savePreferences(const GenerationPreferences(ahead: -1)),
        throwsArgumentError,
      );
    },
  );
  test(
    'manual voice change invalidates only affected speaker and survives recommendation',
    () async {
      await prepare();
      await automatic();
      final cast = await CastRepository(store).get(book.id);
      await CastRepository(store).save(
        cast.copyWith(
          speakers: [
            ...cast.speakers,
            Speaker(id: 'hero', name: 'Hero', voiceDescription: 'Warm voice'),
          ],
        ),
      );
      await casts.setExclusiveCount(20);
      final text = book.chapter(1).text;
      await ScriptRepository(store).save(
        Script(
          bookId: book.id,
          chapterNumber: 1,
          sourceTextHash: book.chapter(1).textHash,
          model: 'fake',
          promptVersion: 'v1',
          lines: [
            ScriptLine(
              start: 0,
              end: text.indexOf('Two.'),
              direction: const Direction(speakerId: 'hero'),
            ),
            ScriptLine(
              start: text.indexOf('Two.'),
              end: text.length,
              direction: const Direction(speakerId: 'narrator'),
            ),
          ],
        ),
      );
      await listening.open(book.id);
      await casts.idle;
      await eventually(() => engine.segments.length == 2);
      final replacement = (await voices.presets(
        book.id,
        'hero',
      )).firstWhere((v) => !v.selected && v.provider == 'minimax');
      await voices.selectPreset(book.id, 'hero', replacement.id);
      await casts.setExclusiveCount(1);
      expect(
        (await voices.presets(
          book.id,
          'hero',
        )).singleWhere((v) => v.selected).id,
        replacement.id,
      );
      await listening.play();
      await casts.idle;
      await eventually(() => listening.value.playing);
      // Requests carry no speaker; the voice each was cast to tells. The
      // narrator's line was voiced once, the hero's once for each voice.
      final narrator = (await Casting(
        store,
      ).getCasting(book.id)).voices['narrator']!.binding.voiceId;
      expect(
        tts.requests.where((r) => r.binding.voiceId == narrator),
        hasLength(1),
      );
      expect(
        tts.requests.where((r) => r.binding.voiceId != narrator),
        hasLength(2),
      );
    },
  );
  test(
    'design candidates persist, selection activates, invalid binding rebuilds and notifies',
    () async {
      await prepare();
      await automatic();
      expect(await voices.designProviders(book.id), ['minimax']);
      final candidates = await voices.design(
        book.id,
        'narrator',
        provider: 'minimax',
        description: 'Warm clear narrator',
      );
      expect(candidates, hasLength(3));
      expect(tts.requests, isEmpty);
      await voices.selectCandidate(book.id, 'narrator', candidates[1].id);
      expect(tts.requests.single.binding.voiceId, 'designed-2');
      await casts.setExclusiveCount(0);
      expect(
        (await Casting(store).getCasting(book.id)).voices['narrator']!.id,
        candidates[1].id,
      );
      tts.invalid.add('designed-2');
      await listening.open(book.id);
      await casts.idle;
      await eventually(() => listening.value.playing);
      expect(tts.designs, hasLength(4));
      expect(voices.notices.single.speakerId, 'narrator');
      expect(
        (await Casting(
          store,
        ).getCasting(book.id)).voices['narrator']!.binding.voiceId,
        'designed-4',
      );
      await voices.dismissNotice(voices.notices.single.id);
      expect(await store.list('voiceRebuilds'), isEmpty);
    },
  );
  test(
    'clear releases measured audio, preserves cast/script and allows regeneration',
    () async {
      await prepare();
      await automatic();
      await listening.open(book.id);
      await casts.idle;
      await eventually(() => engine.segments.length == 3);
      await listening.pause();
      final before = (await storage.usage()).single;
      var actual = 0;
      await for (final entity in AudioRepository(
        store,
      ).bookDirectory(book.id).list(recursive: true)) {
        if (entity is File) actual += await entity.length();
      }
      expect(before.audioBytes, actual);
      expect(before.audioBytes, greaterThan(0));
      final script = (await ScriptRepository(store).get(book.id, 1))!.toJson();
      final cast = (await CastRepository(store).get(book.id)).toJson();
      await storage.clearAudio(book.id);
      expect((await storage.usage()).single.audioBytes, 0);
      expect((await ScriptRepository(store).get(book.id, 1))!.toJson(), script);
      expect((await CastRepository(store).get(book.id)).toJson(), cast);
      expect(
        (await Library(store).chapters(book.id)).first.state,
        ChapterState.directed,
      );
      expect(await File(book.sourcePath).exists(), isTrue);
      final requests = tts.requests.length;
      await listening.play();
      await casts.idle;
      await eventually(() => listening.value.playing);
      expect(tts.requests.length, requests + 3);
    },
  );
  test('progress follows chapters generated ahead, then clears', () async {
    await prepare();
    ChapterProgress? of(int chapter) =>
        generation.progress.value.of(book.id, chapter);
    final directing = Completer<void>();
    director.before = (_) => directing.future;
    final voicing = Completer<void>();
    tts.before = (_) => voicing.future;
    await generation.prepare(book.id, first: 1, through: 2);
    await eventually(() => of(1)?.stage == ChapterStage.directing);
    expect(of(1)!.since, isNotNull);
    expect(of(1)!.directed, isFalse);
    expect(of(2)!.stage, ChapterStage.queued);

    directing.complete();
    // The new script is announced before any line is voiced.
    await eventually(() => of(1)?.stage == ChapterStage.voicing);
    expect(of(1)!.directed, isTrue);
    expect(of(1)!.voiced, 0);
    expect(of(1)!.total, 3);
    expect(of(1)!.unvoiced, {0, 1, 2});

    voicing.complete();
    await casts.idle;
    await eventually(() => generation.progress.value.chapters.isEmpty);
    expect((await AudioRepository(store).get(book.id, 2))!.complete, isTrue);
  });
  test(
    'a switched-off provider is never called and resumes once back on',
    () async {
      await prepare();
      await automatic();
      await providers.switchVoice('minimax', false);
      await listening.open(book.id);
      await casts.idle;
      await eventually(() => generation.value.failures.isNotEmpty);
      expect(tts.requests, isEmpty);
      final failure = generation.value.failures.single;
      expect(failure.provider, 'minimax');
      expect(failure.reason, 'providerDisabled');

      await providers.switchVoice('minimax', true);
      await generation.resume(book.id);
      await casts.idle;
      await eventually(() => listening.value.playing);
      expect(tts.requests, hasLength(3));
    },
  );
  test(
    'an audition plays a line the voice already spoke, sending nothing',
    () async {
      await prepare();
      await casts.scheduler.enqueue(book.id, TaskKind.synthesize, through: 1);
      await casts.idle;
      final count = tts.requests.length;
      final audio = (await AudioRepository(store).get(book.id, 1))!;
      final spoken = audio.utterances.first;
      // Remove saved samples so only the chapter can provide one.
      for (final voice in (await Casting(
        store,
      ).getCasting(book.id)).voices.values) {
        final path = voice.samplePath;
        if (path != null && await File(path).exists()) {
          await File(path).delete();
        }
      }
      await casts.audition(book.id, spoken.speakerId);
      final engine = casts.auditionEngine as MemoryEngine;
      expect(engine.loads.last, spoken.audioPath);
      expect(tts.requests.length, count);
      expect(casts.auditioning, spoken.speakerId);
      await casts.stopAudition();

      // An example's chapter is one file: the line plays from where it is.
      final whole = await File(
        '${root.path}/whole.wav',
      ).writeAsBytes(await File(spoken.audioPath).readAsBytes());
      final json = audio.toJson();
      json['utterances'] = [
        for (final u in audio.utterances)
          {...u.toJson(), 'audioPath': whole.path},
      ];
      await AudioRepository(store).save(ChapterAudio.fromJson(json));
      final second = audio.utterances.last;
      await casts.audition(book.id, second.speakerId);
      expect(engine.loads.last, whole.path);
      expect(tts.requests.length, count);
      await casts.stopAudition();
    },
  );

  test('voice presets and design offer only providers that are on', () async {
    await prepare();
    expect(
      (await voices.presets(
        book.id,
        'narrator',
      )).map((v) => v.provider).toSet(),
      {'minimax'},
    );
    await providers.switchVoice('minimax', false);
    await providers.switchVoice('edge', true);
    expect(
      (await voices.presets(
        book.id,
        'narrator',
      )).map((v) => v.provider).toSet(),
      {'edge'},
    );
    expect(await voices.designProviders(book.id), isEmpty);
  });
  test(
    'without agreement voicing pauses instead of asking, and resuming asks',
    () async {
      await prepare();
      await automatic();
      final endpoint = (await providers.endpoint('minimax'))!;
      await consents.revoke(
        ConsentRecord(provider: 'minimax', endpoint: endpoint),
      );
      var asked = 0;
      consents.addListener(() {
        if (consents.value != null) asked++;
      });
      await listening.open(book.id);
      await casts.idle;
      await eventually(() => generation.value.failures.isNotEmpty);
      expect(asked, 0);
      expect(tts.requests, isEmpty);
      expect(generation.value.failures.single.reason, 'consentNeeded');
      // The listener keeps hearing the chapter meanwhile.
      await eventually(
        () =>
            listening.value.source == ListeningSource.system &&
            listening.value.playing,
      );
      accept = false;
      await generation.resume(book.id);
      expect(asked, 1);
      expect(generation.value.failures, isNotEmpty);
      accept = true;
      await generation.resume(book.id);
      await casts.idle;
      await eventually(() => tts.requests.length == 3);
      expect(await consents.granted('minimax', endpoint), isTrue);
    },
  );
  test(
    'clear during synthesis waits for checkpoint and cannot restore removed audio',
    () async {
      await prepare();
      await automatic();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      tts.before = (n) => n == 2 ? release.future : null;
      await listening.open(book.id);
      await eventually(
        () => tts.requests.length == 2 && listening.value.playing,
      );
      final clearing = storage.clearAudio(book.id);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      release.complete();
      await clearing;
      await casts.idle;
      await listening.settled;
      expect((await storage.usage()).single.audioBytes, 0);
      expect(
        casts.scheduler.tasks.where((t) => t.kind != TaskKind.profile),
        isEmpty,
      );
      expect(tts.requests, hasLength(2));
      expect(engine.state.playing, isFalse);
    },
  );

  test(
    'pausing while waiting does not fall back; playing waits again',
    () async {
      await prepare();
      await automatic();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      tts.before = (n) => n == 1 ? release.future : null;
      await listening.open(book.id);
      expect(listening.value.waitingSince, isNotNull);
      await listening.pause();
      expect(listening.value.waitingSince, isNull);
      expect(listening.value.source, ListeningSource.synthesized);
      release.complete();
      await casts.idle;
      await listening.play();
      await eventually(
        () =>
            listening.value.playing &&
            listening.value.source == ListeningSource.synthesized,
      );
      expect(speech.requests, isEmpty);
    },
  );

  test(
    'a failed rebuilt binding pauses after one recovery instead of redesigning repeatedly',
    () async {
      await prepare();
      await automatic();
      final current = (await Casting(
        store,
      ).getCasting(book.id)).voices['narrator']!;
      tts.invalid.addAll([current.binding.voiceId, 'designed-1']);
      await listening.open(book.id);
      await casts.idle;
      await eventually(() => generation.value.failures.isNotEmpty);
      expect(tts.designs, hasLength(1));
      expect(generation.value.failures.single.reason, 'voiceUnavailable');
    },
  );

  test(
    'Bailian design is unavailable in Singapore and unsupported design sends no requests',
    () async {
      await prepare();
      await providers.configure('minimax', secrets: {'key': ''});
      await providers.configure(
        'bailian',
        values: {'region': 'singapore'},
        secrets: {'key': 'fake'},
      );
      expect(await voices.designProviders(book.id), isEmpty);
      await expectLater(
        voices.design(
          book.id,
          'narrator',
          provider: 'bailian',
          description: 'Warm',
        ),
        throwsA(isA<ProviderException>()),
      );
      expect(tts.designs, isEmpty);
    },
  );
  test(
    'bookmark source offset restores the containing line after script segmentation changes',
    () async {
      await store.put('listening', book.id, {
        'bookId': book.id,
        'chapter': 1,
        'line': 1,
        'sourceOffset': 5,
        'progress': 0.1,
      });
      await prepare();
      await automatic();
      final text = book.chapter(1).text;
      await ScriptRepository(store).save(
        Script(
          bookId: book.id,
          chapterNumber: 1,
          sourceTextHash: book.chapter(1).textHash,
          model: 'fake',
          promptVersion: 'v1',
          lines: [
            ScriptLine(
              start: 0,
              end: text.indexOf('Three.'),
              direction: const Direction(speakerId: 'narrator'),
            ),
            ScriptLine(
              start: text.indexOf('Three.'),
              end: text.length,
              direction: const Direction(speakerId: 'narrator'),
            ),
          ],
        ),
      );
      expect((await listening.bookmark(book.id))!.sourceOffset, 5);
      await listening.open(book.id);
      await casts.idle;
      await eventually(() => listening.value.playing);
      expect(listening.value.line, 0);
      expect(listening.value.lineRevision, greaterThan(0));
    },
  );
}
