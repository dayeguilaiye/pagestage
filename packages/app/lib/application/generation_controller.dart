import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pagestage_core/pagestage_core.dart';

import 'contracts.dart';
import 'provider_gateway.dart';
import 'provider_store.dart';

/// Coordinates listening intent with the durable queue. Reading never calls
/// it, and it never asks the listener anything: a chapter is voiced when its
/// book uses AI voices and they can be made, and read by the system voice
/// otherwise.
class GenerationController extends ValueNotifier<GenerationState>
    implements Generation {
  GenerationController._(this.store, this.scheduler, this.providers)
    : super(const GenerationState());
  final LocalStore store;
  final Scheduler scheduler;

  /// Whether a language model and a voice engine are ready. Null in tests
  /// that do not set providers up, where both count as ready.
  final ProviderStore? providers;
  ProviderGateway? gateway;
  late final StreamSubscription<SchedulerEvent> _events;
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  bool _closed = false;
  Future<void> _refreshing = Future.value();
  final _started = <String, Stopwatch>{};
  String? _listeningBook;
  int? _listeningChapter;
  PerformanceMode _listeningMode = PerformanceMode.audiobook;
  Future<void> Function(String bookId)? onModeChanged;
  final _progress = ValueNotifier(const GenerationProgress());
  @override
  ValueListenable<GenerationProgress> get progress => _progress;

  /// When each chapter being directed started, by `bookId:chapter`.
  final _directing = <String, DateTime>{};

  /// Books listened to so far past their profiled chapters that profiling
  /// them waits for the reader, with the chapter that was wanted.
  final _profileNeeded = <String, int>{};

  /// Transient pauses resumed on their own, by task id.
  final _retries = <String, int>{};
  final _retryTimers = <String, Timer>{};

  /// How far past the profiled chapters listening may jump before finding
  /// the characters in between needs the reader's go-ahead.
  static const autoProfileLimit = 20;

  /// Automatic attempts for a network or rate-limit pause.
  static const maxRetries = 3;

  static Future<GenerationController> open(
    LocalStore store,
    Scheduler scheduler, {
    ProviderStore? providers,
  }) async {
    final service = GenerationController._(store, scheduler, providers);
    final json = await store.get('settings', 'generation') ?? {};
    // Before books had their own choice, `automatic` meant asking before
    // each chapter; such a record leaves the new default in place.
    final legacy = !json.containsKey('ahead');
    service.value = GenerationState(
      preferences: GenerationPreferences(
        enabled: json['enabled'] as bool? ?? true,
        automatic: legacy ? true : json['automatic'] as bool? ?? true,
        ahead: (json['ahead'] as int? ?? json['synthesis'] as int? ?? 1).clamp(
          0,
          GenerationPreferences.maxAhead,
        ),
      ),
    );
    scheduler.hold(!service.value.preferences.enabled);
    service._events = scheduler.events.listen((_) => service._refresh());
    providers?.addListener(service._onProviders);
    service._refresh();
    return service;
  }

  void _onProviders() {
    // A provider set up or switched off changes what can run now.
    unawaited(_report());
  }

  void _refresh() {
    _refreshing = _refreshing
        .then((_) async {
          if (_closed) return;
          final failures = <GenerationFailure>[];
          for (final task in scheduler.tasks.where(
            (t) => t.status == TaskStatus.paused,
          )) {
            if (failures.any(
              (f) =>
                  f.bookId == task.bookId &&
                  f.chapter == task.chapter &&
                  (task.kind == TaskKind.profile) == f.profiling,
            )) {
              continue;
            }
            final custom = await store.get(
              task.kind == TaskKind.profile
                  ? 'profileFailure'
                  : 'generationFailure',
              task.bookId,
            );
            final reason =
                custom?['reason'] as String? ??
                (task.provider == 'local'
                    ? 'interrupted'
                    : providerReason(task.reason, task.code));
            failures.add(
              GenerationFailure(
                bookId: task.bookId,
                chapter: task.chapter,
                provider: task.provider == 'local'
                    ? 'system'
                    : custom?['provider'] as String? ??
                          task.provider ??
                          'system',
                reason: reason,
                profiling: task.kind == TaskKind.profile,
              ),
            );
            _retryLater(task, reason);
          }
          final progress = await _measure();
          if (!_closed) {
            value = GenerationState(
              preferences: value.preferences,
              failures: List.unmodifiable(failures),
            );
            _progress.value = progress;
            _changes.add(null);
          }
        })
        .catchError((Object _) {});
  }

  /// A network or rate-limit pause resumes by itself a few times before it
  /// waits for the reader.
  void _retryLater(ScheduledTask task, String reason) {
    if (reason != 'network' && reason != 'rateLimited') return;
    if (_retryTimers.containsKey(task.id)) return;
    final attempts = _retries[task.id] ?? 0;
    if (attempts >= maxRetries) return;
    _retries[task.id] = attempts + 1;
    final delay = Duration(
      seconds: (reason == 'rateLimited' ? 60 : 20) * (attempts + 1),
    );
    _retryTimers[task.id] = Timer(delay, () {
      _retryTimers.remove(task.id);
      if (_closed) return;
      unawaited(
        scheduler
            .resume(bookId: task.bookId, provider: task.provider)
            .then((_) => _refresh()),
      );
    });
  }

  /// Reads where each chapter with outstanding work stands. Lookahead that
  /// will not run while nobody listens is not under way.
  Future<GenerationProgress> _measure() async {
    final chapters = <(String, int), List<ScheduledTask>>{};
    for (final task in scheduler.outstanding) {
      if (task.kind == TaskKind.profile) continue;
      (chapters[(task.bookId, task.chapter)] ??= []).add(task);
    }
    final profiling = <(String, int)>{
      for (final task in scheduler.outstanding)
        if (task.kind == TaskKind.profile) (task.bookId, task.chapter),
    };
    final result = <ChapterProgress>[];
    final directing = <String>{};
    for (final MapEntry(key: (bookId, chapter), value: tasks)
        in chapters.entries) {
      final running = tasks.any((t) => t.status == TaskStatus.running);
      final paused = tasks.any((t) => t.status == TaskStatus.paused);
      final script = await ScriptRepository(store).get(bookId, chapter);
      if (script == null) {
        final key = '$bookId:$chapter';
        if (running) directing.add(key);
        // Characters are still being found up to this chapter.
        final waiting = profiling.any((p) => p.$1 == bookId && p.$2 <= chapter);
        result.add(
          ChapterProgress(
            bookId: bookId,
            chapter: chapter,
            stage: running
                ? ChapterStage.directing
                : paused
                ? ChapterStage.paused
                : waiting
                ? ChapterStage.profiling
                : ChapterStage.queued,
            since: running ? _directing.putIfAbsent(key, DateTime.now) : null,
          ),
        );
        continue;
      }
      final synthesis = tasks
          .where((t) => t.kind == TaskKind.synthesize)
          .firstOrNull;
      final mode = synthesis?.mode ?? await coreMode(bookId);
      final audio = await AudioRepository(
        store,
      ).get(bookId, chapter, mode: mode);
      final voiced = {
        if (audio != null &&
            audio.scriptHash == AudioRepository.hashScript(script))
          for (final utterance in audio.utterances) ...utterance.lineIndices,
      };
      final voiceable = [
        for (final (i, line) in script.lines.indexed)
          if (!line.isNonStory &&
              !(mode == PerformanceMode.drama && line.isDialogueTag) &&
              line.end > line.start)
            i,
      ];
      result.add(
        ChapterProgress(
          bookId: bookId,
          chapter: chapter,
          stage: running
              ? ChapterStage.voicing
              : paused
              ? ChapterStage.paused
              : ChapterStage.queued,
          directed: true,
          voiced: voiceable.where(voiced.contains).length,
          total: voiceable.length,
          unvoiced: {...voiceable.where((i) => !voiced.contains(i))},
        ),
      );
    }
    _directing.removeWhere((key, _) => !directing.contains(key));
    return GenerationProgress(List.unmodifiable(result));
  }

  @override
  Future<void> savePreferences(GenerationPreferences preferences) async {
    if (preferences.ahead < 0 ||
        preferences.ahead > GenerationPreferences.maxAhead) {
      throw ArgumentError('Invalid generation lookahead.');
    }
    await store.put('settings', 'generation', {
      'enabled': preferences.enabled,
      'automatic': preferences.automatic,
      'ahead': preferences.ahead,
    });
    final wasEnabled = value.preferences.enabled;
    value = GenerationState(preferences: preferences, failures: value.failures);
    if (wasEnabled != preferences.enabled) {
      scheduler.hold(!preferences.enabled);
    }
    await _report();
    _changes.add(null);
  }

  PerformanceRepository get _performances => PerformanceRepository(store);

  @override
  Future<BookPerformanceMode> mode(String bookId) async =>
      BookPerformanceMode.values.byName((await coreMode(bookId)).name);
  Future<PerformanceMode> coreMode(String bookId) async =>
      (await _performances.get(bookId)).mode;
  @override
  Future<void> setMode(String bookId, BookPerformanceMode selected) async {
    await Library(store).getBook(bookId);
    if (await mode(bookId) == selected) return;
    await _perform(
      bookId,
      (performance) => performance.copyWith(
        mode: PerformanceMode.values.byName(selected.name),
      ),
    );
  }

  @override
  Future<BookExpressiveness> expressiveness(String bookId) async =>
      BookExpressiveness.values.byName(
        (await _performances.get(bookId)).expressiveness.name,
      );
  @override
  Future<void> setExpressiveness(
    String bookId,
    BookExpressiveness selected,
  ) async {
    await Library(store).getBook(bookId);
    if (await expressiveness(bookId) == selected) return;
    await _perform(
      bookId,
      (performance) => performance.copyWith(
        expressiveness: Expressiveness.values.byName(selected.name),
      ),
    );
  }

  /// Changes how a book is performed. Work queued for the old performance
  /// is dropped, and what is playing reloads for the new one.
  Future<void> _perform(
    String bookId,
    Performance Function(Performance) change,
  ) async {
    await scheduler.withBookPaused(bookId, () async {
      await scheduler.cancelGeneration(bookId);
      await _performances.save(bookId, change(await _performances.get(bookId)));
    });
    await onModeChanged?.call(bookId);
    _changes.add(null);
  }

  /// The bundled example books: voiced in advance, never regenerated.
  Future<bool> isSample(String bookId) async =>
      (await samples()).contains(bookId);

  @override
  Future<Set<String>> samples() async {
    final json = await store.get('settings', 'exampleBooks');
    return {...?(json?['ids'] as List?)?.cast<String>()};
  }

  /// What the app still needs before AI voices can be made for [bookId].
  Future<VoiceSetupGap?> _gap(String bookId) async {
    final providers = this.providers;
    if (providers == null) return null;
    final preferences = providers.value;
    if (!preferences.llmReady) return VoiceSetupGap.languageModel;
    if (preferences.voiceProviders.isEmpty) return VoiceSetupGap.voiceEngine;
    // Voices are on, but none speaks this book's language.
    final failure = await store.get('castingFailure', bookId);
    if (failure?['reason'] == 'noVoiceProvider') {
      return VoiceSetupGap.voiceEngine;
    }
    return null;
  }

  /// Whether chapters of [bookId] get AI voices as they are listened to.
  Future<bool> active(String bookId) async {
    final preferences = value.preferences;
    if (!preferences.enabled) return false;
    final choice = await store.get('bookVoice', bookId);
    if (!(choice?['ai'] as bool? ?? preferences.automatic)) return false;
    return await _gap(bookId) == null && !await isSample(bookId);
  }

  @override
  Future<BookVoice> voice(String bookId) async {
    final book = await Library(store).getBook(bookId);
    final choice = await store.get('bookVoice', bookId);
    final chosen = choice?['ai'] as bool?;
    final cast = await CastRepository(store).get(bookId);
    return BookVoice(
      bookId: bookId,
      ai: chosen ?? value.preferences.automatic,
      chosen: chosen != null,
      enabled: value.preferences.enabled,
      gap: await _gap(bookId),
      sample: await isSample(bookId),
      profiledThrough: cast.profiledThrough.clamp(0, book.chapters.length),
      chapterCount: book.chapters.length,
      profileNeeded: _profileNeeded[bookId],
    );
  }

  @override
  Future<void> setAiVoice(String bookId, bool on) async {
    await Library(store).getBook(bookId);
    await store.put('bookVoice', bookId, {'bookId': bookId, 'ai': on});
    if (!on) await stopPreparing(bookId);
    await _report();
    _changes.add(null);
  }

  @override
  Future<bool> allow(String bookId) async {
    final gateway = this.gateway;
    if (gateway == null) return true;
    for (final provider in ['llm', ...?providers?.value.voiceProviders]) {
      if (!await gateway.ask(bookId, provider)) return false;
    }
    return true;
  }

  @override
  Future<void> stopPreparing(String bookId) async {
    _profileNeeded.remove(bookId);
    await scheduler.cancelGeneration(bookId);
    final cast = await CastRepository(store).get(bookId);
    await scheduler.limitProfile(bookId, cast.profiledThrough);
    await store.delete('generationFailure', bookId);
    await store.delete('profileFailure', bookId);
    // What listening needs next is queued again.
    if (_listeningBook == bookId) await _report(force: true);
    _refresh();
  }

  @override
  Future<void> profileThrough(String bookId, int chapter) async {
    final book = await Library(store).getBook(bookId);
    final through = chapter.clamp(1, book.chapters.length);
    _profileNeeded.remove(bookId);
    final cast = await CastRepository(store).get(bookId);
    if (through > cast.profiledThrough) {
      await store.put('profiling', bookId, {
        'bookId': bookId,
        'through': through,
      });
      await scheduler.enqueue(bookId, TaskKind.profile, through: through);
    }
    if (_listeningBook == bookId) await _report(force: true);
    _refresh();
    _changes.add(null);
  }

  /// How [chapter] will be heard. AI voices are queued when the book uses
  /// them and they can be made; otherwise the system voice reads it. Never
  /// asks: a failing book reads in the system voice while its banner
  /// explains why.
  Future<GenerationChoice> plan(
    String bookId,
    int chapter,
    PerformanceMode mode,
  ) async {
    if (!await active(bookId)) return GenerationChoice.system;
    if (value.failures.any((f) => f.bookId == bookId)) {
      return GenerationChoice.system;
    }
    final profiledThrough = (await CastRepository(
      store,
    ).get(bookId)).profiledThrough;
    final pending = scheduler.tasks.any(
      (t) =>
          t.bookId == bookId &&
          t.chapter == chapter &&
          t.kind == TaskKind.synthesize &&
          t.mode == mode &&
          t.status != TaskStatus.completed,
    );
    if (!pending && chapter - profiledThrough > autoProfileLimit) {
      _profileNeeded[bookId] = chapter;
      _changes.add(null);
      return GenerationChoice.system;
    }
    _profileNeeded.remove(bookId);
    _started['$bookId:$chapter:${mode.name}'] ??= Stopwatch()..start();
    // Promotes lookahead work, or queues the chapter with any profiling it
    // still needs.
    await scheduler.enqueue(
      bookId,
      TaskKind.synthesize,
      first: chapter,
      through: chapter,
      mode: mode,
      profile: true,
    );
    _refresh();
    return GenerationChoice.generate;
  }

  /// The failure stopping [chapter] of [bookId]. Any pause in a book holds
  /// the work queued behind it, so another chapter's failure counts too.
  GenerationFailure? failure(String bookId, int chapter) {
    final book = value.failures.where((f) => f.bookId == bookId);
    return book.where((f) => f.chapter == chapter).firstOrNull ??
        book.firstOrNull;
  }

  @override
  Future<void> prepare(
    String bookId, {
    required int first,
    required int through,
  }) async {
    await scheduler.enqueue(
      bookId,
      TaskKind.synthesize,
      first: first,
      through: through,
      mode: await coreMode(bookId),
      profile: true,
    );
    _refresh();
  }

  @override
  Future<void> resume(String bookId) async {
    gateway?.resetRecovery(bookId);
    for (final task in scheduler.tasks.where((t) => t.bookId == bookId)) {
      _retries.remove(task.id);
      _retryTimers.remove(task.id)?.cancel();
    }
    // An agreement withdrawn or never given is asked for now, while the
    // reader is here to answer.
    final failures = value.failures.where(
      (f) =>
          f.bookId == bookId &&
          (f.reason == 'consentNeeded' || f.reason == 'consentDeclined'),
    );
    for (final failure in failures) {
      if (!await (gateway?.ask(bookId, failure.provider) ??
          Future.value(true))) {
        return;
      }
    }
    await store.delete('generationFailure', bookId);
    await store.delete('profileFailure', bookId);
    await scheduler.resume(bookId: bookId);
    _refresh();
  }

  Future<void> listening(
    String? bookId, {
    int? chapter,
    PerformanceMode mode = PerformanceMode.audiobook,
  }) async {
    if (_closed) return;
    if (_listeningBook == bookId &&
        _listeningChapter == chapter &&
        _listeningMode == mode) {
      return;
    }
    _listeningBook = bookId;
    _listeningChapter = chapter;
    _listeningMode = mode;
    await _report();
  }

  String? _reported;

  /// Tells the scheduler what to prepare ahead: nothing unless the book
  /// listened to uses AI voices and they can be made, and profiling ahead
  /// only within reach of what is already profiled.
  Future<void> _report({bool force = false}) async {
    if (_closed) return;
    final bookId = _listeningBook;
    final chapter = _listeningChapter;
    final preferences = value.preferences;
    var active = false;
    var profile = false;
    if (bookId != null && chapter != null) {
      try {
        active = await this.active(bookId);
        final profiled = (await CastRepository(
          store,
        ).get(bookId)).profiledThrough;
        profile =
            chapter + preferences.directing - profiled <= autoProfileLimit;
      } catch (_) {
        active = false;
      }
    }
    final key = active
        ? '$bookId:$chapter:${_listeningMode.name}:${preferences.ahead}:$profile'
        : null;
    if (!force && key == _reported) return;
    _reported = key;
    await scheduler.reportListening(
      active ? bookId : null,
      chapter: chapter,
      mode: _listeningMode,
      profile: profile,
      lookahead: Lookahead(
        directing: preferences.directing,
        synthesis: preferences.synthesis,
      ),
    );
    // Which lookahead is under way changed with it.
    _refresh();
  }

  @override
  Future<List<BookUsage>> usage() async {
    final file = File('${File(store.path).parent.path}/usage.jsonl');
    if (!await file.exists()) return const [];
    final tokens = <String, int>{};
    final characters = <String, Map<String, int>>{};
    final requests = <String, int>{};
    int number(Object? value) => value is num ? value.toInt() : 0;
    for (final line in await file.readAsLines()) {
      if (line.trim().isEmpty) continue;
      final Map<String, Object?> json;
      try {
        json = Map<String, Object?>.from(jsonDecode(line) as Map);
      } catch (_) {
        continue;
      }
      final bookId = json['bookId'] as String? ?? '';
      final provider = json['provider'] as String? ?? '';
      final usage = json['usage'] is Map
          ? Map<String, Object?>.from(json['usage'] as Map)
          : const <String, Object?>{};
      requests[bookId] = (requests[bookId] ?? 0) + 1;
      if (provider == 'llm') {
        final total = number(usage['total_tokens']);
        tokens[bookId] =
            (tokens[bookId] ?? 0) +
            (total > 0
                ? total
                : number(usage['prompt_tokens']) +
                      number(usage['completion_tokens']) +
                      number(usage['input_tokens']) +
                      number(usage['output_tokens']));
        continue;
      }
      final voiced =
          number(usage['usage_characters']) + number(usage['characters']);
      if (voiced > 0) {
        final perProvider = characters[bookId] ??= {};
        perProvider[provider] = (perProvider[provider] ?? 0) + voiced;
      }
    }
    final books = {...tokens.keys, ...characters.keys, ...requests.keys};
    int weight(String id) =>
        (tokens[id] ?? 0) +
        (characters[id]?.values.fold<int>(0, (a, b) => a + b) ?? 0);
    return [
      for (final id in books)
        BookUsage(
          bookId: id,
          tokens: tokens[id] ?? 0,
          characters: Map.unmodifiable(characters[id] ?? const {}),
          requests: requests[id] ?? 0,
        ),
    ]..sort((a, b) => weight(b.bookId).compareTo(weight(a.bookId)));
  }

  Future<void> firstSound(
    String bookId,
    int chapter,
    PerformanceMode mode,
  ) async {
    final watch = _started.remove('$bookId:$chapter:${mode.name}');
    if (watch == null) return;
    watch.stop();
    final file = File(
      '${File(store.path).parent.path}/generation-timing.jsonl',
    );
    await file.writeAsString(
      '${jsonEncode({'event': 'firstSound', 'bookId': bookId, 'chapter': chapter, 'mode': mode.name, 'elapsedMs': watch.elapsedMilliseconds, 'at': DateTime.now().toUtc().toIso8601String()})}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  Future<void> close() async {
    _closed = true;
    providers?.removeListener(_onProviders);
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    await _events.cancel();
    await _refreshing;
    await _changes.close();
    _progress.dispose();
    dispose();
  }
}
