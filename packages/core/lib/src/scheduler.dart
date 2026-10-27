import 'dart:async';

import 'audio_repository.dart';
import 'casting.dart';
import 'director.dart';
import 'library.dart';
import 'local_store.dart';
import 'models/cast.dart';
import 'profiler.dart';
import 'providers/llm_adapter.dart';
import 'providers/provider_exception.dart';
import 'providers/request_recovery.dart';
import 'providers/tts_adapter.dart';
import 'script_repository.dart';
import 'synthesizer.dart';

enum TaskKind { profile, direct, synthesize }

enum TaskStatus { queued, running, paused, completed }

enum TaskOrigin { user, lookahead }

class Lookahead {
  Lookahead({this.directing = 2, this.synthesis = 1}) {
    if (directing < 0 || synthesis < 0 || synthesis > directing) {
      throw ArgumentError(
        'Synthesis lookahead must be between zero and directing lookahead.',
      );
    }
  }
  final int directing;
  final int synthesis;
}

/// Each durable task is a single chapter checkpoint.
class ScheduledTask {
  const ScheduledTask({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.kind,
    required this.origin,
    required this.order,
    this.mode = PerformanceMode.audiobook,
    this.status = TaskStatus.queued,
    this.completedUtterances = 0,
    this.provider,
    this.reason,
    this.code,
  });
  final String id;
  final String bookId;
  final int chapter;
  final TaskKind kind;
  final TaskOrigin origin;
  final int order;
  final PerformanceMode mode;
  final TaskStatus status;
  final int completedUtterances;
  final String? provider;
  final ProviderErrorKind? reason;

  /// The pause's fixed [ProviderException.code], when it has one.
  final String? code;

  ScheduledTask copyWith({
    TaskStatus? status,
    TaskOrigin? origin,
    int? completedUtterances,
    String? provider,
    ProviderErrorKind? reason,
    String? code,
  }) => ScheduledTask(
    id: id,
    bookId: bookId,
    chapter: chapter,
    kind: kind,
    origin: origin ?? this.origin,
    order: order,
    mode: mode,
    status: status ?? this.status,
    completedUtterances: completedUtterances ?? this.completedUtterances,
    provider: provider,
    reason: reason,
    code: code,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'bookId': bookId,
    'chapter': chapter,
    'kind': kind.name,
    'origin': origin.name,
    'order': order,
    'mode': mode.name,
    'status': status.name,
    'completedUtterances': completedUtterances,
    'provider': provider,
    'reason': reason?.name,
    'code': code,
  };
  factory ScheduledTask.fromJson(Map<String, Object?> json) => ScheduledTask(
    id: json['id'] as String,
    bookId: json['bookId'] as String,
    chapter: json['chapter'] as int,
    kind: TaskKind.values.byName(json['kind'] as String),
    origin: TaskOrigin.values.byName(json['origin'] as String),
    order: json['order'] as int,
    mode: PerformanceMode.values.byName(json['mode'] as String),
    status: TaskStatus.values.byName(json['status'] as String),
    completedUtterances: json['completedUtterances'] as int,
    provider: json['provider'] as String?,
    reason: json['reason'] == null
        ? null
        : ProviderErrorKind.values.byName(json['reason'] as String),
    code: json['code'] as String?,
  );
}

class SchedulerEvent {
  const SchedulerEvent(this.task, {this.utterance});
  final ScheduledTask task;
  final SynthesizedUtterance? utterance;
}

/// Durable generation queue. Inject the same adapters used by the CLI, including
/// their request recovery queues; this module never adds another retry budget.
/// Closing finishes the current chapter or utterance checkpoint before stopping.
class Scheduler {
  Scheduler._(
    this.store,
    this.profileLlm,
    this.directorLlm,
    this.ttsAdapters,
    this.runtime,
    this.beforeTask,
    this.recoverVoice,
  ) : _audio = AudioRepository(store);

  static Future<Scheduler> open({
    required LocalStore store,
    required LlmAdapter profileLlm,
    required LlmAdapter directorLlm,
    required Map<String, TtsAdapter> ttsAdapters,
    RequestRuntime? runtime,
    Future<void> Function(ScheduledTask)? beforeTask,
    Future<bool> Function(ScheduledTask, ProviderException)? recoverVoice,
  }) async {
    final scheduler = Scheduler._(
      store,
      profileLlm,
      directorLlm,
      Map.unmodifiable(ttsAdapters),
      runtime ?? RequestRuntime(),
      beforeTask,
      recoverVoice,
    );
    for (final json in await store.list('tasks')) {
      var task = ScheduledTask.fromJson(json);
      if (task.status == TaskStatus.running) {
        task = task.copyWith(status: TaskStatus.queued);
        await store.put('tasks', task.id, task.toJson());
      }
      scheduler._tasks[task.id] = task;
      if (task.order >= scheduler._order) scheduler._order = task.order + 1;
    }
    scheduler._kick();
    return scheduler;
  }

  final LocalStore store;
  final LlmAdapter profileLlm;
  final LlmAdapter directorLlm;
  final Map<String, TtsAdapter> ttsAdapters;
  final RequestRuntime runtime;
  final Future<void> Function(ScheduledTask)? beforeTask;
  final Future<bool> Function(ScheduledTask, ProviderException)? recoverVoice;
  final _suspended = <String>{};
  final _voiceRecoveries = <String, int>{};
  ScheduledTask? _active;
  Completer<void>? _checkpoint;
  final AudioRepository _audio;
  final _tasks = <String, ScheduledTask>{};
  final _events = StreamController<SchedulerEvent>.broadcast(sync: true);
  Stream<SchedulerEvent> get events => _events.stream;
  List<ScheduledTask> get tasks => List.unmodifiable(
    _tasks.values.toList()..sort((a, b) => a.order.compareTo(b.order)),
  );
  var _order = 0;
  var _closing = false;
  Future<void>? _worker;
  var _requested = false;
  Future<void> _commands = Future.value();
  String? _listeningBook;
  Set<String> _lookaheadIds = {};

  Future<T> _command<T>(Future<T> Function() action) {
    if (_closing) throw StateError('Scheduler is closed.');
    final future = _commands.then((_) => action());
    _commands = future.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return future;
  }

  /// Profiles chapters 1..through, or directs/synthesizes first..through.
  /// Directing and synthesis require an already profiled range.
  Future<void> enqueue(
    String bookId,
    TaskKind kind, {
    required int through,
    int first = 1,
    PerformanceMode mode = PerformanceMode.audiobook,
  }) => _command(() async {
    final book = await Library(store).getBook(bookId);
    book.chapter(first);
    book.chapter(through);
    if (first > through) throw ArgumentError('Invalid chapter range.');
    final cast = await CastRepository(store).get(bookId);
    if (kind != TaskKind.profile && through > cast.profiledThrough) {
      throw StateError('Profile the requested range first.');
    }
    for (var n = kind == TaskKind.profile ? 1 : first; n <= through; n++) {
      if (kind == TaskKind.synthesize) {
        await _add(bookId, n, TaskKind.direct, TaskOrigin.user, mode);
      }
      await _add(bookId, n, kind, TaskOrigin.user, mode);
    }
    _kick();
  });

  /// Call only while listening. Passing null stops pending automatic work.
  /// Reopening the scheduler does not resume automatic work until this is called.
  Future<void> reportListening(
    String? bookId, {
    int? chapter,
    Lookahead? lookahead,
    PerformanceMode mode = PerformanceMode.audiobook,
  }) => _command(() async {
    if (bookId == null) {
      _listeningBook = null;
      _lookaheadIds = {};
      return;
    }
    final book = await Library(store).getBook(bookId);
    book.chapter(chapter!);
    final settings = lookahead ?? Lookahead();
    final cast = await CastRepository(store).get(bookId);
    _listeningBook = bookId;
    _lookaheadIds = {};
    for (
      var n = chapter + 1;
      n <= chapter + settings.directing &&
          n <= cast.profiledThrough &&
          n <= book.chapters.length;
      n++
    ) {
      _lookaheadIds.add(
        await _add(bookId, n, TaskKind.direct, TaskOrigin.lookahead, mode),
      );
      if (n <= chapter + settings.synthesis) {
        _lookaheadIds.add(
          await _add(
            bookId,
            n,
            TaskKind.synthesize,
            TaskOrigin.lookahead,
            mode,
          ),
        );
      }
    }
    _kick();
  });

  Future<void> resume({String? provider, String? bookId, TaskKind? kind}) =>
      _command(() async {
        for (final task in tasks) {
          if (task.status == TaskStatus.paused &&
              (provider == null || task.provider == provider) &&
              (bookId == null || task.bookId == bookId) &&
              (kind == null || task.kind == kind)) {
            _voiceRecoveries.remove(task.id);
            await _save(task.copyWith(status: TaskStatus.queued));
          }
        }
        _kick();
      });

  /// Stops this book at its next durable checkpoint before mutating its files.
  Future<T> withBookPaused<T>(
    String bookId,
    Future<T> Function() action,
  ) async {
    if (!_suspended.add(bookId)) throw StateError('Book is busy.');
    try {
      if (_active?.bookId == bookId) await _checkpoint?.future;
      return await action();
    } finally {
      _suspended.remove(bookId);
      _kick();
    }
  }

  /// Drops waiting profile tasks past [through]; finished chapters stay.
  Future<void> limitProfile(String bookId, int through) => _command(() async {
    for (final task in tasks.where(
      (t) =>
          t.bookId == bookId &&
          t.kind == TaskKind.profile &&
          t.chapter > through &&
          (t.status == TaskStatus.queued || t.status == TaskStatus.paused),
    )) {
      _tasks.remove(task.id);
      await store.delete('tasks', task.id);
    }
  });

  /// Explicit cleanup cancels queued generation while retaining profile tasks.
  Future<void> cancelGeneration(String bookId) => _command(() async {
    for (final task in tasks.where(
      (t) => t.bookId == bookId && t.kind != TaskKind.profile,
    )) {
      _tasks.remove(task.id);
      _lookaheadIds.remove(task.id);
      await store.delete('tasks', task.id);
    }
  });

  Future<void> get idle async {
    await _commands;
    while (_worker != null) {
      await _worker;
    }
  }

  Future<void> close() async {
    _closing = true;
    await _commands;
    await _worker;
    await _events.close();
  }

  Future<String> _add(
    String bookId,
    int chapter,
    TaskKind kind,
    TaskOrigin origin,
    PerformanceMode mode,
  ) async {
    final id =
        '$bookId:${kind.name}:$chapter:${kind == TaskKind.synthesize ? mode.name : "shared"}';
    final previous = _tasks[id];
    var task =
        previous ??
        ScheduledTask(
          id: id,
          bookId: bookId,
          chapter: chapter,
          kind: kind,
          origin: origin,
          order: _order++,
          mode: mode,
        );
    if (previous?.status == TaskStatus.completed) {
      task = task.copyWith(status: TaskStatus.queued);
    }
    if (origin == TaskOrigin.user) {
      task = ScheduledTask(
        id: task.id,
        bookId: task.bookId,
        chapter: task.chapter,
        kind: task.kind,
        origin: origin,
        order: task.order,
        mode: task.mode,
        status: task.status,
        completedUtterances: task.completedUtterances,
        provider: task.provider,
        reason: task.reason,
      );
    }
    await _save(task);
    return id;
  }

  Future<bool> _save(
    ScheduledTask task, {
    SynthesizedUtterance? utterance,
  }) async {
    if (await store.get('books', task.bookId) == null) {
      // A response already in flight may arrive after a book was deleted.
      // Remove that response's artifacts before it can restore task progress.
      await Library(store).deleteBook(task.bookId);
      _tasks.removeWhere((_, value) => value.bookId == task.bookId);
      return false;
    }
    _tasks[task.id] = task;
    await store.put('tasks', task.id, task.toJson());
    _events.add(SchedulerEvent(task, utterance: utterance));
    return true;
  }

  void _kick() {
    if (_closing) return;
    if (_worker != null) {
      _requested = true;
      return;
    }
    _requested = false;
    _worker = Future<void>(() async {
      try {
        await _run();
      } finally {
        _worker = null;
        if (_requested) _kick();
      }
    });
  }

  Future<void> _run() async {
    while (!_closing) {
      await _commands;
      final pending =
          tasks
              .where(
                (t) =>
                    t.status == TaskStatus.queued &&
                    !_suspended.contains(t.bookId) &&
                    (t.origin == TaskOrigin.user ||
                        (t.bookId == _listeningBook &&
                            _lookaheadIds.contains(t.id))),
              )
              .toList()
            ..sort((a, b) {
              final priority = a.origin.index.compareTo(b.origin.index);
              return priority == 0 ? a.order.compareTo(b.order) : priority;
            });
      ScheduledTask? next;
      for (final task in pending) {
        if (await store.get('books', task.bookId) == null) {
          _tasks.remove(task.id);
          await store.delete('tasks', task.id);
          continue;
        }
        if (await _blocked(task)) continue;
        next = task;
        break;
      }
      if (next == null || _closing) return;
      var task = next.copyWith(status: TaskStatus.running);
      if (_suspended.contains(task.bookId)) continue;
      _active = task;
      _checkpoint = Completer<void>();
      try {
        if (!await _save(task)) continue;
        if (_suspended.contains(task.bookId)) throw const _Interrupted();
        await beforeTask?.call(task);
        await _execute(task);
        _voiceRecoveries.remove(task.id);
        task = _tasks[task.id]!.copyWith(status: TaskStatus.completed);
        await _save(task);
      } on _BookDeleted {
        continue;
      } on _Interrupted {
        await _save(_tasks[task.id]!.copyWith(status: TaskStatus.queued));
      } on ProviderException catch (error) {
        var recovered = false;
        if (error.kind == ProviderErrorKind.invalidVoice &&
            recoverVoice != null &&
            (_voiceRecoveries[task.id] ?? 0) < 32) {
          _voiceRecoveries[task.id] = (_voiceRecoveries[task.id] ?? 0) + 1;
          try {
            recovered = await recoverVoice!(task, error);
          } catch (_) {
            /* Pause with the original safe error. */
          }
        }
        if (recovered) {
          await _save(_tasks[task.id]!.copyWith(status: TaskStatus.queued));
          continue;
        }
        await _save(
          _tasks[task.id]!.copyWith(
            status: TaskStatus.paused,
            provider: error.provider,
            reason: error.kind,
            code: error.code,
          ),
        );
      } catch (_) {
        // Never persist arbitrary exceptions: they may contain provider text.
        await _save(
          _tasks[task.id]!.copyWith(
            status: TaskStatus.paused,
            provider: 'local',
            reason: ProviderErrorKind.invalidConfiguration,
          ),
        );
      } finally {
        _active = null;
        _checkpoint?.complete();
        _checkpoint = null;
      }
    }
  }

  Future<bool> _blocked(ScheduledTask task) async {
    final paused = tasks.where((t) => t.status == TaskStatus.paused);
    if (task.kind == TaskKind.profile &&
        tasks.any(
          (t) =>
              t.bookId == task.bookId &&
              t.kind == TaskKind.profile &&
              t.chapter < task.chapter &&
              t.status != TaskStatus.completed,
        )) {
      return true;
    }
    if (task.kind == TaskKind.synthesize &&
        tasks.any(
          (t) =>
              t.bookId == task.bookId &&
              t.chapter == task.chapter &&
              t.kind == TaskKind.direct &&
              t.status != TaskStatus.completed,
        )) {
      return true;
    }
    if (task.kind != TaskKind.synthesize) {
      return paused.any((t) => t.provider == 'llm');
    }
    final cast = await Casting(store).getCasting(task.bookId);
    final providers = cast.voices.values.map((v) => v.binding.provider).toSet();
    return paused.any((t) => providers.contains(t.provider));
  }

  Future<void> _execute(ScheduledTask task) async {
    final book = await Library(store).getBook(task.bookId);
    if (task.kind == TaskKind.profile) {
      await Profiler(
        store,
        profileLlm,
      ).profile(book, throughChapter: task.chapter);
      return;
    }
    var script = await ScriptRepository(store).get(book.id, task.chapter);
    if (script == null ||
        script.sourceTextHash != book.chapter(task.chapter).textHash) {
      script = (await Director(
        store,
        directorLlm,
        runtime: runtime,
      ).direct(book, task.chapter)).script;
    }
    if (task.kind == TaskKind.direct ||
        await _audio.isComplete(script, mode: task.mode)) {
      return;
    }
    if (_closing || _suspended.contains(task.bookId)) {
      throw const _Interrupted();
    }
    final speakerIds = script.lines
        .where(
          (line) =>
              !line.isNonStory &&
              !(task.mode == PerformanceMode.drama && line.isDialogueTag) &&
              line.textIn(book.chapter(task.chapter).text).trim().isNotEmpty,
        )
        .map((line) => line.direction.speakerId)
        .toSet();
    final bindings = await Casting(
      store,
    ).prepareChapterBindings(book, task.chapter, speakerIds: speakerIds);
    final cast = await CastRepository(store).get(book.id);
    final inputsHash = await _audio.hashInputs(script, task.mode);
    final completed = <SynthesizedUtterance>[];
    final activeScript = script;
    final result =
        await Synthesizer(
          adapters: ttsAdapters,
          cacheDirectory: _audio.cacheDirectory(book.id),
          fallbackCacheDirectory: _audio.legacyCacheDirectory,
        ).synthesize(
          chapter: book.chapter(task.chapter),
          script: script,
          language: book.language,
          voices: bindings,
          lexicon: cast.lexicon,
          mode: task.mode,
          outputPath: _audio.outputPath(book.id, task.chapter, task.mode),
          onUtterance: (utterance) async {
            completed.add(utterance);
            await _audio.save(
              ChapterAudio(
                bookId: book.id,
                chapter: task.chapter,
                mode: task.mode,
                scriptHash: AudioRepository.hashScript(activeScript),
                utterances: completed,
                inputsHash: inputsHash,
              ),
            );
            final saved = await _save(
              _tasks[task.id]!.copyWith(completedUtterances: completed.length),
              utterance: utterance,
            );
            if (!saved) throw const _BookDeleted();
            if (_closing ||
                _suspended.contains(task.bookId) ||
                (task.origin == TaskOrigin.lookahead &&
                    !_lookaheadIds.contains(task.id))) {
              throw const _Interrupted();
            }
          },
        );
    await _audio.saveResult(
      script,
      result,
      mode: task.mode,
      inputsHash: inputsHash,
    );
  }
}

class _Interrupted implements Exception {
  const _Interrupted();
}

class _BookDeleted implements Exception {
  const _BookDeleted();
}
