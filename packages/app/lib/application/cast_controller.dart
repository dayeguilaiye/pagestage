import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:pagestage_core/pagestage_core.dart';

import '../playback/playback_engine.dart';
import '../playback/playback_queue.dart';
import 'contracts.dart';
import 'provider_store.dart';
import 'provider_gateway.dart';

typedef ProfileAdapterFactory =
    LlmAdapter Function(ProviderConfiguration configuration);
typedef AuditionAdapterFactory =
    TtsAdapter Function(ProviderConfiguration configuration, String provider);

class CastController extends ChangeNotifier implements Casts {
  CastController._({
    required this.store,
    required this.providers,
    required this.consents,
    required this.listening,
    required this.auditionEngine,
    this.profileFactory,
    this.auditionFactory,
  });
  final LocalStore store;
  final ProviderStore providers;
  final ConsentBroker consents;
  final Listening listening;
  final PlaybackEngine auditionEngine;
  final ProfileAdapterFactory? profileFactory;
  final AuditionAdapterFactory? auditionFactory;
  late final Scheduler scheduler;
  late final ProviderGateway gateway;
  late final StreamSubscription<SchedulerEvent> _events;
  late final StreamSubscription<EngineState> _auditionEvents;
  String? _auditioning;
  @override
  String? get auditioning => _auditioning;
  Future<void> _reconciled = Future.value();
  Future<void> _auditions = Future.value();
  int _exclusiveCount = 20;
  Set<String> _lastVoiceProviders = const {};
  bool _closed = false;
  Future<void> Function()? beforeAudition;
  Future<void> Function(String bookId)? onCastingChanged;
  int _auditionGeneration = 0;
  @override
  int get exclusiveCount => _exclusiveCount;

  static Future<CastController> open({
    required LocalStore store,
    required ProviderStore providers,
    required ConsentBroker consents,
    required Listening listening,
    required PlaybackEngine auditionEngine,
    ProfileAdapterFactory? profileFactory,
    AuditionAdapterFactory? auditionFactory,
    LlmFactory? directorFactory,
    ProviderGateway? gateway,
  }) async {
    final service = CastController._(
      store: store,
      providers: providers,
      consents: consents,
      listening: listening,
      auditionEngine: auditionEngine,
      profileFactory: profileFactory,
      auditionFactory: auditionFactory,
    );
    service._exclusiveCount =
        (await store.get('settings', 'casting'))?['exclusiveCount'] as int? ??
        20;
    service.gateway =
        gateway ??
        ProviderGateway(
          store: store,
          providers: providers,
          consents: consents,
          profileFactory: profileFactory,
          directorFactory: directorFactory,
          ttsFactory: auditionFactory,
        );
    service.scheduler = await Scheduler.open(
      store: store,
      profileLlm: service.gateway.llm(profile: true),
      directorLlm: service.gateway.llm(profile: false),
      ttsAdapters: service.gateway.tts(
        () => service.gateway.activeTask!.bookId,
      ),
      runtime: service.gateway.runtime,
      beforeTask: service.gateway.beforeTask,
      recoverVoice: service.gateway.recover,
      voiceCatalog: () async => service.gateway.catalog(),
    );
    service._events = service.scheduler.events.listen((event) {
      if (event.task.kind == TaskKind.profile &&
          event.task.status == TaskStatus.completed) {
        service._queueReconcile(event.task.bookId);
      }
      service._notify();
    });
    store.addListener(service._notify);
    service._lastVoiceProviders = service._voiceProviders;
    providers.addListener(service._onProviders);
    service._auditionEvents = auditionEngine.states.listen((state) {
      if ((state.completed || state.error != null) &&
          service._auditioning != null) {
        service._auditioning = null;
        service._notify();
      }
    });
    for (final book in await Library(store).listBooks()) {
      service._queueReconcile(book.id);
    }
    return service;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  void _queueReconcile(String bookId) {
    _reconciled = _reconciled.then((_) => _reconcile(bookId));
  }

  Future<void> _reconcile(String bookId) async {
    if (!await store.exists('books', bookId)) return;
    try {
      final cast = await CastRepository(store).get(bookId);
      if (cast.profiledThrough == 0) return;
      if (cast.speakers.every((s) => s.voiceId != null)) {
        if (await store.exists('castingFailure', bookId)) {
          await store.delete('castingFailure', bookId);
        }
        return;
      }
      final book = await Library(store).getBook(bookId);
      final casting = _casting();
      if (!casting.catalog.any((p) => p.languages.contains(book.language))) {
        await store.put('castingFailure', bookId, {
          'bookId': bookId,
          'provider': '',
          'reason': 'noVoiceProvider',
        });
        return;
      }
      if (await store.get('casting', bookId) == null) {
        await casting.recommend(
          book,
          exclusiveCount: exclusiveCount,
          providers: _voiceProviders,
        );
      } else {
        // Adds voices for newly discovered speakers while retaining existing
        // bindings and the previous exclusive-speaker allocation.
        await casting.recommend(
          book,
          exclusiveCount: exclusiveCount,
          providers: _voiceProviders,
          preserveExisting: true,
        );
      }
      await store.delete('castingFailure', bookId);
    } catch (_) {
      if (!await store.exists('books', bookId)) return;
      await store.put('castingFailure', bookId, {
        'bookId': bookId,
        'reason': 'interrupted',
      });
    }
    _notify();
  }

  Set<String> get _voiceProviders => providers.value.voiceProviders;

  /// Casts from the presets the engines in use offer right now.
  Casting _casting() => Casting(store, catalog: gateway.catalog());

  /// Casting waiting for a voice provider goes on once one is switched on.
  void _onProviders() {
    final now = _voiceProviders;
    if (now.length == _lastVoiceProviders.length &&
        now.containsAll(_lastVoiceProviders)) {
      return;
    }
    _lastVoiceProviders = now;
    _reconciled = _reconciled.then((_) async {
      for (final book in await Library(store).listBooks()) {
        await _reconcile(book.id);
      }
    });
  }

  Future<void> get idleAuditions => _auditions;

  Future<void> get idle async {
    await scheduler.idle;
    await _reconciled;
    await _auditions;
  }

  @override
  Future<CastState> load(String bookId) async {
    // Runs on every store change while the cast page is open.
    final chapterCount = await Library(store).chapterCount(bookId);
    final cast = await Casting(store).getCasting(bookId);
    final tasks = scheduler.tasks
        .where((t) => t.bookId == bookId && t.kind == TaskKind.profile)
        .toList();
    final pending = tasks
        .where((t) => t.status != TaskStatus.completed)
        .toList();
    final paused = pending
        .where((t) => t.status == TaskStatus.paused)
        .firstOrNull;
    final target =
        (await store.get('profiling', bookId))?['through'] as int? ??
        cast.cast.profiledThrough;
    final failure =
        await store.get('castingFailure', bookId) ??
        await store.get('profileFailure', bookId);
    final status = paused != null || failure != null
        ? ProfilingStatus.paused
        : pending.any((t) => t.status == TaskStatus.running)
        ? ProfilingStatus.running
        : pending.isNotEmpty
        ? ProfilingStatus.queued
        : cast.cast.profiledThrough > 0 &&
              cast.cast.speakers.any((speaker) => speaker.voiceId == null)
        ? ProfilingStatus.running
        : cast.cast.profiledThrough > 0
        ? ProfilingStatus.complete
        : ProfilingStatus.idle;
    final presetNames = {
      for (final p in gateway.engines.voice.catalog(
        providers.settings,
        only: cast.voices.values.map((v) => v.binding.provider).toSet(),
      ))
        if (p.displayName != null)
          (p.binding.provider, p.binding.voiceId): p.displayName!,
    };
    String? displayName(Voice? voice) => voice == null
        ? null
        : presetNames[(voice.binding.provider, voice.binding.voiceId)] ??
              voice.binding.voiceId;
    final spoken = await _spokenSpeakers(bookId, cast.cast);
    // The narrator first, then everyone in the order they first appear.
    final speakers = cast.cast.speakers.indexed.toList()
      ..sort((a, b) {
        int rank(Speaker s) => s.kind == SpeakerKind.narrator ? 0 : 1;
        int first(Speaker s) =>
            s.chapters.isEmpty ? 1 << 30 : s.chapters.reduce(math.min);
        final byKind = rank(a.$2).compareTo(rank(b.$2));
        if (byKind != 0) return byKind;
        final byChapter = first(a.$2).compareTo(first(b.$2));
        return byChapter != 0 ? byChapter : a.$1.compareTo(b.$1);
      });
    return CastState(
      bookId: bookId,
      // An example packed from a longer book may say more were profiled
      // than it has.
      profiledThrough: math.min(cast.cast.profiledThrough, chapterCount),
      targetChapter: target,
      chapterCount: chapterCount,
      status: status,
      provider: paused?.provider == 'local'
          ? 'system'
          : paused?.provider ??
                (failure == null
                    ? null
                    : failure['provider'] as String? ?? 'system'),
      skippedChapters: cast.cast.skippedChapters.keys.toList()..sort(),
      reason:
          failure?['reason'] as String? ??
          (paused?.provider == 'local'
              ? 'interrupted'
              : _reason(paused?.reason, paused?.code)),
      members: [
        for (final (_, speaker) in speakers)
          CastMember(
            id: speaker.id,
            name: speaker.name,
            kind: CastMemberKind.values.byName(speaker.kind.name),
            gender: speaker.gender,
            ageGroup: speaker.ageGroup,
            personality: speaker.personality,
            speakingStyle: speaker.speakingStyle,
            voiceDescription: speaker.voiceDescription,
            voiceName: displayName(cast.voices[speaker.id]),
            provider: cast.voices[speaker.id]?.binding.provider,
            firstChapter: speaker.chapters.isEmpty
                ? null
                : speaker.chapters.reduce(math.min),
            spoken: spoken.contains(speaker.id),
          ),
      ],
    );
  }

  static String? _reason(ProviderErrorKind? reason, String? code) =>
      switch (reason) {
        null => null,
        ProviderErrorKind.invalidKey => 'unauthorized',
        ProviderErrorKind.insufficientBalance => 'quotaExceeded',
        ProviderErrorKind.rateLimited => 'rateLimited',
        ProviderErrorKind.unavailable => 'network',
        ProviderErrorKind.invalidResponse => invalidResponseReason(code),
        ProviderErrorKind.invalidVoice => 'invalidResponse',
        ProviderErrorKind.invalidConfiguration => configurationReason(code),
      };

  Future<bool> _approveProfile(
    String bookId,
    ProviderConfiguration config,
  ) async {
    final book = await Library(store).getBook(bookId);
    // Validates all required fields before prompting; no requests are sent.
    // A device engine sends the text nowhere and needs no asking.
    final endpoint = gateway.engines.language.active(config).endpoint(config);
    if (endpoint == null) return true;
    return consents.request(
      bookTitle: book.title,
      provider: 'llm',
      endpoint: endpoint.toString(),
      content: 'chapterTextAndCast',
    );
  }

  @override
  Future<void> profile(String bookId, {required int through}) async {
    final book = await Library(store).getBook(bookId);
    book.chapter(through);
    final config = await providers.configuration();
    if (!await _approveProfile(bookId, config)) return;
    final paused = scheduler.tasks.any(
      (t) =>
          t.bookId == bookId &&
          t.kind == TaskKind.profile &&
          t.status == TaskStatus.paused,
    );
    final old = (await store.get('profiling', bookId))?['through'] as int? ?? 0;
    // A paused book may move its target either way; a running one only extends.
    final target = paused || through > old ? through : old;
    await store.put('profiling', bookId, {'bookId': bookId, 'through': target});
    await scheduler.limitProfile(bookId, target);
    await scheduler.enqueue(bookId, TaskKind.profile, through: target);
    if (paused) {
      await store.delete('profileFailure', bookId);
      await scheduler.resume(bookId: bookId, kind: TaskKind.profile);
    }
    _queueReconcile(bookId);
  }

  @override
  Future<void> resume(String bookId) async {
    if (!await _approveProfile(bookId, await providers.configuration())) return;
    await store.delete('profileFailure', bookId);
    await scheduler.resume(bookId: bookId, kind: TaskKind.profile);
    _queueReconcile(bookId);
  }

  @override
  Future<void> rematch(String bookId) {
    final operation = _reconciled.then((_) async {
      final allowed = _voiceProviders;
      if (allowed.isEmpty) throw StateError('No voice provider is on.');
      final book = await Library(store).getBook(bookId);
      await scheduler.withBookPaused(bookId, () async {
        await onCastingChanged?.call(bookId);
        await _casting().recommend(
          book,
          exclusiveCount: exclusiveCount,
          providers: allowed,
          preserveExisting: true,
          replaceOutsideProviders: true,
        );
      });
      await store.delete('castingFailure', bookId);
      _notify();
    });
    _reconciled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<void> setExclusiveCount(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    final operation = _reconciled.then((_) async {
      await store.put('settings', 'casting', {'exclusiveCount': count});
      _exclusiveCount = count;
      for (final book in await Library(store).listBooks()) {
        final cast = await CastRepository(store).get(book.id);
        if (cast.profiledThrough > 0 && _voiceProviders.isNotEmpty) {
          await scheduler.withBookPaused(book.id, () async {
            await onCastingChanged?.call(book.id);
            await _casting().recommend(
              book,
              exclusiveCount: count,
              providers: _voiceProviders,
            );
          });
        }
      }
      _notify();
    });
    _reconciled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<void> audition(String bookId, String speakerId) {
    final stopped = stopAudition();
    final generation = _auditionGeneration;
    final next = _auditions.then((_) async {
      await stopped;
      await beforeAudition?.call();
      await _audition(bookId, speakerId, generation);
    });
    _auditions = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _audition(
    String bookId,
    String speakerId,
    int generation,
  ) async {
    if (generation != _auditionGeneration || _closed) return;
    final book = await Library(store).getBook(bookId);
    final current = await Casting(store).getCasting(bookId);
    var voice = current.voices[speakerId];
    if (voice == null) {
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    // A line this voice already spoke in the book is the best sample, and
    // costs nothing: an example book and every voiced chapter have them.
    final spoken = await _hasSample(voice)
        ? null
        : await _spokenLine(book, speakerId);
    if (spoken case (final path, final start, final length)) {
      if (generation != _auditionGeneration || _closed) return;
      await listening.pause();
      await auditionEngine.pause();
      await auditionEngine.load(path, Duration.zero);
      if (start > Duration.zero) await auditionEngine.seek(start);
      await auditionEngine.setSpeed(1);
      _auditioning = speakerId;
      await auditionEngine.play();
      _notify();
      // A line inside a whole chapter's audio stops where the line does.
      if (length != null) {
        _auditionStop?.cancel();
        _auditionStop = Timer(length, () {
          if (generation != _auditionGeneration || _closed) return;
          unawaited(stopAudition());
        });
      }
      return;
    }
    if (!await _hasSample(voice)) {
      try {
        voice =
            (await Casting(
                  store,
                  adapters: gateway.tts(() => bookId, content: 'voiceSample'),
                ).audition(
                  book,
                  speakerId: speakerId,
                  outputDirectory:
                      '${AudioRepository(store).bookDirectory(bookId).path}/auditions',
                ))
                .single;
      } on ProviderException catch (error) {
        if (error.code == 'consentDeclined') return;
        if (error.kind == ProviderErrorKind.invalidVoice &&
            await gateway.recover(
              ScheduledTask(
                id: '$bookId:audition:$speakerId',
                bookId: bookId,
                chapter: 1,
                kind: TaskKind.synthesize,
                origin: TaskOrigin.user,
                order: 0,
              ),
              error,
            )) {
          await _audition(bookId, speakerId, generation);
          return;
        }
        rethrow;
      }
    }
    if (!await store.exists('books', bookId)) {
      await Library(store).deleteBook(bookId);
      return;
    }
    if (generation != _auditionGeneration || _closed) return;
    await listening.pause();
    await auditionEngine.pause();
    await auditionEngine.load(voice.samplePath!, Duration.zero);
    await auditionEngine.setSpeed(1);
    _auditioning = speakerId;
    await auditionEngine.play();
    _notify();
  }

  /// Speakers with a line in the first voiced chapters, which auditions can
  /// play without any provider. Bounded, as the cast page reloads often.
  Future<Set<String>> _spokenSpeakers(String bookId, Cast cast) async {
    final mode = (await PerformanceRepository(store).get(bookId)).mode;
    final out = <String>{};
    final last = math.min(cast.profiledThrough, 30);
    for (var chapter = 1; chapter <= last; chapter++) {
      final audio = await AudioRepository(
        store,
      ).get(bookId, chapter, mode: mode);
      if (audio == null || !audio.complete) continue;
      for (final utterance in audio.utterances) {
        out.add(
          cast.findSpeaker(utterance.speakerId)?.id ?? utterance.speakerId,
        );
      }
    }
    return out;
  }

  /// The audio of a line [speakerId] speaks in a chapter voiced with the
  /// book's current voices: its file, where the line starts in it, and how
  /// long it lasts when the file holds the whole chapter. Null when no
  /// voiced chapter has the speaker.
  Future<(String, Duration, Duration?)?> _spokenLine(
    Book book,
    String speakerId,
  ) async {
    final mode = (await PerformanceRepository(store).get(book.id)).mode;
    final audio = AudioRepository(store);
    final cast = await CastRepository(store).get(book.id);
    final id = cast.findSpeaker(speakerId)?.id ?? speakerId;
    for (final chapter in book.chapters.take(200)) {
      final script = await ScriptRepository(store).get(book.id, chapter.number);
      if (script == null || script.sourceTextHash != chapter.textHash) continue;
      final voiced = await audio.get(book.id, chapter.number, mode: mode);
      if (voiced == null) continue;
      try {
        if (!await audio.isComplete(script, mode: mode)) continue;
      } catch (_) {
        continue;
      }
      final PlaybackQueue queue;
      try {
        queue = PlaybackQueue(voiced.utterances);
      } catch (_) {
        continue;
      }
      // A line long enough to hear the voice, else the first one.
      final lines = [
        for (final entry in queue.entries)
          if ((cast.findSpeaker(entry.utterance.speakerId)?.id ??
                  entry.utterance.speakerId) ==
              id)
            entry,
      ];
      final entry =
          lines
              .where((e) => e.utterance.duration >= const Duration(seconds: 2))
              .firstOrNull ??
          lines.firstOrNull;
      if (entry == null) continue;
      final path = entry.utterance.audioPath;
      if (!await File(path).exists()) continue;
      final shared =
          voiced.utterances.where((u) => u.audioPath == path).length > 1;
      return shared
          ? (path, entry.audioStart, entry.utterance.duration)
          : (path, Duration.zero, null);
    }
    return null;
  }

  Future<bool> _hasSample(Voice voice) async {
    final path = voice.samplePath;
    if (path == null) return false;
    try {
      final audio = PcmAudio.fromWav(await File(path).readAsBytes());
      return audio.samples.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Timer? _auditionStop;

  @override
  Future<void> stopAudition() {
    _auditionStop?.cancel();
    _auditionStop = null;
    _auditionGeneration++;
    _auditioning = null;
    _notify();
    return auditionEngine.pause();
  }

  Future<void> close() async {
    _closed = true;
    _auditionStop?.cancel();
    store.removeListener(_notify);
    providers.removeListener(_onProviders);
    await scheduler.close();
    await _events.cancel();
    await _auditionEvents.cancel();
    await _reconciled;
    await _auditions;
    await auditionEngine.dispose();
    super.dispose();
  }
}
