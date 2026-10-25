import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pagestage_core/pagestage_core.dart';

import '../playback/playback_engine.dart';
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
    );
    service._events = service.scheduler.events.listen((event) {
      if (event.task.kind == TaskKind.profile &&
          event.task.status == TaskStatus.completed) {
        service._queueReconcile(event.task.bookId);
      }
      service._notify();
    });
    store.addListener(service._notify);
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
    _reconciled = _reconciled.then((_) async {
      if (await store.get('books', bookId) == null) return;
      try {
        final cast = await CastRepository(store).get(bookId);
        if (cast.profiledThrough == 0 ||
            cast.speakers.every((s) => s.voiceId != null)) {
          return;
        }
        final book = await Library(store).getBook(bookId);
        final casting = Casting(store);
        if (await store.get('casting', bookId) == null) {
          await casting.recommend(
            book,
            exclusiveCount: exclusiveCount,
            providers: _configuredTts,
            bailianRegion: providers.value.region.name,
          );
        } else {
          // Adds voices for newly discovered speakers while retaining existing
          // bindings and the previous exclusive-speaker allocation.
          await casting.recommend(
            book,
            exclusiveCount: exclusiveCount,
            providers: _configuredTts,
            bailianRegion: providers.value.region.name,
            preserveExisting: true,
          );
        }
        await store.delete('castingFailure', bookId);
      } catch (_) {
        if (await store.get('books', bookId) == null) return;
        await store.put('castingFailure', bookId, {
          'bookId': bookId,
          'reason': 'interrupted',
        });
      }
      _notify();
    });
  }

  Set<String>? get _configuredTts {
    final selected = {
      if (providers.value.hasMinimaxKey) 'minimax',
      if (providers.value.hasBailianKey) 'bailian',
    };
    // Assigning a preset is local. Users may configure its provider before audition.
    return selected.isEmpty ? {'minimax'} : selected;
  }

  Future<void> get idleAuditions => _auditions;

  Future<void> get idle async {
    await scheduler.idle;
    await _reconciled;
    await _auditions;
  }

  @override
  Future<CastState> load(String bookId) async {
    final book = await Library(store).getBook(bookId);
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
    return CastState(
      bookId: bookId,
      profiledThrough: cast.cast.profiledThrough,
      targetChapter: target,
      chapterCount: book.chapters.length,
      status: status,
      provider: paused?.provider == 'local'
          ? 'system'
          : paused?.provider ?? (failure == null ? null : 'system'),
      reason:
          failure?['reason'] as String? ??
          (paused?.provider == 'local'
              ? 'interrupted'
              : _reason(paused?.reason)),
      members: [
        for (final speaker in cast.cast.speakers)
          CastMember(
            id: speaker.id,
            name: speaker.name,
            kind: CastMemberKind.values.byName(speaker.kind.name),
            gender: speaker.gender,
            ageGroup: speaker.ageGroup,
            personality: speaker.personality,
            speakingStyle: speaker.speakingStyle,
            voiceDescription: speaker.voiceDescription,
            voiceName: cast.voices[speaker.id]?.binding.voiceId,
            provider: cast.voices[speaker.id]?.binding.provider,
          ),
      ],
    );
  }

  static String? _reason(ProviderErrorKind? reason) => switch (reason) {
    null => null,
    ProviderErrorKind.invalidKey => 'unauthorized',
    ProviderErrorKind.insufficientBalance => 'quotaExceeded',
    ProviderErrorKind.rateLimited => 'rateLimited',
    ProviderErrorKind.unavailable => 'network',
    ProviderErrorKind.invalidResponse => 'invalidResponse',
    ProviderErrorKind.invalidVoice => 'invalidResponse',
    ProviderErrorKind.invalidConfiguration => 'missingKey',
  };

  Future<bool> _approveProfile(
    String bookId,
    ProviderConfiguration config,
  ) async {
    final book = await Library(store).getBook(bookId);
    // Validates all required fields before prompting; no requests are sent.
    final settings = LlmSettings.fromConfiguration(config);
    return consents.request(
      bookTitle: book.title,
      provider: 'llm',
      endpoint: settings.baseUrl.toString(),
      content: 'chapterTextAndCast',
    );
  }

  @override
  Future<void> profile(String bookId, {required int through}) async {
    final book = await Library(store).getBook(bookId);
    book.chapter(through);
    final config = await providers.configuration();
    if (!await _approveProfile(bookId, config)) return;
    final old = (await store.get('profiling', bookId))?['through'] as int? ?? 0;
    final target = through > old ? through : old;
    await store.put('profiling', bookId, {'bookId': bookId, 'through': target});
    await scheduler.enqueue(bookId, TaskKind.profile, through: target);
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
  Future<void> setExclusiveCount(int count) {
    if (count < 0) throw ArgumentError.value(count, 'count');
    final operation = _reconciled.then((_) async {
      await store.put('settings', 'casting', {'exclusiveCount': count});
      _exclusiveCount = count;
      for (final book in await Library(store).listBooks()) {
        final cast = await CastRepository(store).get(book.id);
        if (cast.profiledThrough > 0) {
          await scheduler.withBookPaused(book.id, () async {
            await onCastingChanged?.call(book.id);
            await Casting(store).recommend(
              book,
              exclusiveCount: count,
              providers: _configuredTts,
              bailianRegion: providers.value.region.name,
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
    if (await store.get('books', bookId) == null) {
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

  @override
  Future<void> stopAudition() {
    _auditionGeneration++;
    _auditioning = null;
    _notify();
    return auditionEngine.pause();
  }

  Future<void> close() async {
    _closed = true;
    store.removeListener(_notify);
    await scheduler.close();
    await _events.cancel();
    await _auditionEvents.cancel();
    await _reconciled;
    await _auditions;
    await auditionEngine.dispose();
    super.dispose();
  }
}
