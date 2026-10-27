import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pagestage_core/pagestage_core.dart';

import 'contracts.dart';
import 'provider_gateway.dart';

/// Coordinates listening intent with the durable queue. Reading never calls it.
class GenerationController extends ValueNotifier<GenerationState>
    implements Generation {
  GenerationController._(this.store, this.scheduler)
    : super(const GenerationState());
  final LocalStore store;
  final Scheduler scheduler;
  ProviderGateway? gateway;
  late final StreamSubscription<SchedulerEvent> _events;
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  Completer<GenerationChoice>? _answer;
  int _sequence = 0;
  bool _closed = false;
  Future<void> _refreshing = Future.value();
  final _started = <String, Stopwatch>{};
  String? _listeningBook;
  int? _listeningChapter;
  PerformanceMode _listeningMode = PerformanceMode.audiobook;
  Future<void> Function(String bookId)? onModeChanged;

  static Future<GenerationController> open(
    LocalStore store,
    Scheduler scheduler,
  ) async {
    final service = GenerationController._(store, scheduler);
    final json = await store.get('settings', 'generation') ?? {};
    service.value = GenerationState(
      preferences: GenerationPreferences(
        automatic: json['automatic'] as bool? ?? false,
        directing: json['directing'] as int? ?? 2,
        synthesis: json['synthesis'] as int? ?? 1,
      ),
    );
    service._events = scheduler.events.listen((_) => service._refresh());
    service._refresh();
    return service;
  }

  void _refresh() {
    _refreshing = _refreshing
        .then((_) async {
          if (_closed) return;
          final failures = <GenerationFailure>[];
          for (final task in scheduler.tasks.where(
            (t) => t.kind != TaskKind.profile && t.status == TaskStatus.paused,
          )) {
            final custom = await store.get('generationFailure', task.bookId);
            failures.add(
              GenerationFailure(
                bookId: task.bookId,
                chapter: task.chapter,
                provider: task.provider == 'local'
                    ? 'system'
                    : task.provider ?? 'system',
                reason:
                    custom?['reason'] as String? ??
                    (task.provider == 'local'
                        ? 'interrupted'
                        : providerReason(task.reason, task.code)),
              ),
            );
          }
          if (!_closed) {
            value = GenerationState(
              preferences: value.preferences,
              request: value.request,
              failures: List.unmodifiable(failures),
            );
            _changes.add(null);
          }
        })
        .catchError((Object _) {});
  }

  @override
  Future<void> savePreferences(GenerationPreferences preferences) async {
    if (preferences.directing < 0 ||
        preferences.directing > 20 ||
        preferences.synthesis < 0 ||
        preferences.synthesis > preferences.directing) {
      throw ArgumentError('Invalid generation lookahead.');
    }
    await store.put('settings', 'generation', {
      'automatic': preferences.automatic,
      'directing': preferences.directing,
      'synthesis': preferences.synthesis,
    });
    value = GenerationState(
      preferences: preferences,
      request: value.request,
      failures: value.failures,
    );
    await _report();
  }

  @override
  Future<BookPerformanceMode> mode(String bookId) async =>
      BookPerformanceMode.values.byName(
        (await store.get('performance', bookId))?['mode'] as String? ??
            'audiobook',
      );
  Future<PerformanceMode> coreMode(String bookId) async =>
      PerformanceMode.values.byName((await mode(bookId)).name);
  @override
  Future<void> setMode(String bookId, BookPerformanceMode selected) async {
    await Library(store).getBook(bookId);
    if (await mode(bookId) == selected) return;
    cancelRequest();
    await scheduler.withBookPaused(bookId, () async {
      await scheduler.cancelGeneration(bookId);
      await store.put('performance', bookId, {
        'bookId': bookId,
        'mode': selected.name,
      });
    });
    await onModeChanged?.call(bookId);
    _changes.add(null);
  }

  /// Returns immediately for an already requested chapter, including a paused
  /// task. A paused task stays in the synthesized path until explicitly resumed.
  Future<GenerationChoice> choose(
    String bookId,
    int chapter,
    PerformanceMode mode,
  ) async {
    final cast = await CastRepository(store).get(bookId);
    final canGenerate = chapter <= cast.profiledThrough;
    if (canGenerate &&
        scheduler.tasks.any(
          (t) =>
              t.bookId == bookId &&
              t.chapter == chapter &&
              t.kind == TaskKind.synthesize &&
              t.mode == mode &&
              t.status != TaskStatus.completed,
        )) {
      // Promote lookahead work when playback reaches it.
      await scheduler.enqueue(
        bookId,
        TaskKind.synthesize,
        first: chapter,
        through: chapter,
        mode: mode,
      );
      return GenerationChoice.generate;
    }
    GenerationChoice choice;
    if (canGenerate && value.preferences.automatic) {
      choice = GenerationChoice.generate;
    } else {
      cancelRequest();
      final book = await Library(store).getBook(bookId);
      final answer = Completer<GenerationChoice>();
      _answer = answer;
      value = GenerationState(
        preferences: value.preferences,
        failures: value.failures,
        request: GenerationRequest(
          id: ++_sequence,
          bookId: bookId,
          bookTitle: book.title,
          chapter: chapter,
          canGenerate: canGenerate,
        ),
      );
      choice = await answer.future;
      if (identical(_answer, answer)) {
        _answer = null;
        value = GenerationState(
          preferences: value.preferences,
          failures: value.failures,
        );
      }
    }
    if (choice == GenerationChoice.generate && canGenerate) {
      _started['$bookId:$chapter:${mode.name}'] = Stopwatch()..start();
      await scheduler.enqueue(
        bookId,
        TaskKind.synthesize,
        first: chapter,
        through: chapter,
        mode: mode,
      );
    }
    return choice;
  }

  @override
  void respond(int requestId, GenerationChoice choice) {
    if (value.request?.id != requestId ||
        _answer == null ||
        _answer!.isCompleted) {
      return;
    }
    if (choice == GenerationChoice.generate && !value.request!.canGenerate) {
      return;
    }
    _answer!.complete(choice);
  }

  void cancelRequest() {
    if (_answer != null && !_answer!.isCompleted) {
      _answer!.complete(GenerationChoice.cancel);
    }
    _answer = null;
    if (!_closed && value.request != null) {
      value = GenerationState(
        preferences: value.preferences,
        failures: value.failures,
      );
    }
  }

  GenerationFailure? failure(String bookId, int chapter) => value.failures
      .where((f) => f.bookId == bookId && f.chapter == chapter)
      .firstOrNull;
  @override
  Future<void> resume(String bookId) async {
    gateway?.resetRecovery(bookId);
    await store.delete('generationFailure', bookId);
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

  Future<void> _report() => scheduler.reportListening(
    _listeningBook,
    chapter: _listeningChapter,
    mode: _listeningMode,
    lookahead: Lookahead(
      directing: value.preferences.directing,
      synthesis: value.preferences.synthesis,
    ),
  );

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
    cancelRequest();
    _closed = true;
    await _events.cancel();
    await _refreshing;
    await _changes.close();
    dispose();
  }
}
