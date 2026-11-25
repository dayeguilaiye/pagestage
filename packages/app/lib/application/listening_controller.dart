import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pagestage_core/pagestage_core.dart';

import '../playback/playback_engine.dart';
import '../playback/playback_queue.dart';
import 'contracts.dart';
import 'system_speech.dart';
import 'generation_controller.dart';

class ListeningController extends ValueNotifier<ListeningState>
    implements Listening {
  ListeningController({
    required this.store,
    required this.engine,
    required this.speech,
    DateTime Function()? now,
    this.fallbackAfter = const Duration(seconds: 20),
  }) : _now = now ?? DateTime.now,
       super(const ListeningState()) {
    _subscription = engine.states.listen(_onEngine);
    store.addListener(_onStore);
  }
  final LocalStore store;
  final PlaybackEngine engine;
  final SystemSpeech speech;
  final DateTime Function() _now;

  /// How long playback waits for AI voices before the system voice reads
  /// the rest of the chapter.
  final Duration fallbackAfter;
  Timer? _fallbackTimer;
  DateTime? _waitingSince;

  /// The system voice stands in for AI voices that were not ready.
  bool _fallback = false;

  /// Whether the open book uses AI voices and can.
  bool _aiVoice = false;
  late final StreamSubscription<EngineState> _subscription;
  Future<void> _commands = Future.value();
  Future<void> _saved = Future.value();
  Book? _book;
  int _chapter = 1;
  int _line = 0;
  List<ListeningLine> _lines = [];
  int _lineRevision = 0;
  void _replaceLines(List<ListeningLine> lines) {
    final same =
        _lines.length == lines.length &&
        List.generate(
          lines.length,
          (i) =>
              _lines[i].start == lines[i].start &&
              _lines[i].end == lines[i].end &&
              _lines[i].speakerName == lines[i].speakerName &&
              _lines[i].text == lines[i].text &&
              _lines[i].nonStory == lines[i].nonStory,
        ).every((value) => value);
    if (!same) _lineRevision++;
    _lines = lines;
  }

  PlaybackQueue? _queue;
  ListeningSource _source = ListeningSource.synthesized;
  double _speed = 1;
  bool _loading = false;
  bool _closed = false;
  bool _completionScheduled = false;
  String? _error;
  Timer? _sleepTimer;
  DateTime? _sleepUntil;
  bool _sleepAfterChapter = false;
  int? _lastSavedLine;
  GenerationController? generation;
  StreamSubscription<void>? _generationEvents;
  PerformanceMode _mode = PerformanceMode.audiobook;
  bool _streaming = false;
  bool _audioComplete = false;
  bool _waiting = false;
  bool _wantPlay = false;
  int _epoch = 0;
  int _requestedOffset = 0;
  String? _audioHash;
  bool _refreshQueued = false;

  void attachGeneration(GenerationController service) {
    generation = service;
    service.onModeChanged = (bookId) async {
      if (_book?.id != bookId) return;
      // A chapter still being voiced starts over in the new performance;
      // one already playing in full, or read by the system voice, finishes
      // as it is and the change applies from the next chapter.
      if (_streaming && !_audioComplete) {
        final play = _wantPlay;
        _cancelPending();
        await _command(() => _loadChapter(_book!, _chapter, _line, play: play));
        return;
      }
      await _command(() async {
        if (_book?.id != bookId) return;
        _mode = await service.coreMode(bookId);
        if (_wantPlay) {
          await service.listening(bookId, chapter: _chapter, mode: _mode);
        }
      });
    };
    _generationEvents = service.changes.listen((_) {
      _queueRefresh();
      unawaited(_refreshAiVoice());
    });
  }

  Future<void> _refreshAiVoice() async {
    final book = _book;
    if (book == null || generation == null || _closed) return;
    try {
      final active = await generation!.active(book.id);
      if (active != _aiVoice && !_closed && _book?.id == book.id) {
        _aiVoice = active;
        _publish();
      }
    } catch (_) {
      // A book deleted meanwhile has nothing to show.
    }
  }

  void _cancelPending() {
    _epoch++;
  }

  /// Starts the wait for AI voices, which the system voice ends after
  /// [fallbackAfter].
  void _startWaiting() {
    if (!_wantPlay || _fallbackTimer != null) return;
    _waitingSince ??= _now();
    final epoch = _epoch;
    final chapter = _chapter;
    _fallbackTimer = Timer(fallbackAfter, () {
      _fallbackTimer = null;
      if (_closed || epoch != _epoch || chapter != _chapter) return;
      unawaited(
        _command(() async {
          if (_streaming && _waiting && _wantPlay && _chapter == chapter) {
            await _fallBack();
          }
        }),
      );
    });
  }

  void _stopWaiting() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _waitingSince = null;
  }

  /// The system voice reads the rest of this chapter, from the first line
  /// not heard yet. AI voices come back with the next chapter.
  Future<void> _fallBack() async {
    final book = _book;
    if (book == null) return;
    _stopWaiting();
    final heard = _queue != null && _lines.isNotEmpty
        ? _lines[_line.clamp(0, _lines.length - 1)].end
        : _requestedOffset;
    final offset = heard > _requestedOffset ? heard : _requestedOffset;
    _streaming = false;
    _waiting = false;
    _queue = null;
    _audioHash = null;
    _source = ListeningSource.system;
    _fallback = true;
    _loading = true;
    _publish();
    await engine.pause();
    _replaceLines(splitSentences(book.chapter(_chapter).text));
    final next = _lines.indexWhere((l) => l.end > offset);
    if (next < 0 || _lines.isEmpty) {
      _loading = false;
      _line = (_lines.length - 1).clamp(0, 10000000);
      if (_wantPlay) {
        await _advance();
      } else {
        _publish();
      }
      return;
    }
    _line = next;
    _requestedOffset = _lines[next].start;
    await _loadSentence();
    await engine.setSpeed(_speed);
    _completionScheduled = false;
    _loading = false;
    if (_wantPlay) await engine.play();
    _publish();
    await _savePosition();
  }

  @override
  Future<void> useSystemVoice() => _command(() async {
    if (_book == null || !_streaming) return;
    await _fallBack();
  });

  void _queueRefresh() {
    if (_closed || !_streaming || _refreshQueued) return;
    _refreshQueued = true;
    unawaited(
      _command(() async {
        _refreshQueued = false;
        await _refreshStream();
      }),
    );
  }

  Future<void> invalidate(String bookId) async {
    if (_book?.id != bookId) return;
    await pause();
    _queue = null;
    _streaming = false;
    _error = 'audioChanged';
    _publish();
  }

  Future<void> refreshBook(String bookId) => _command(() async {
    if (_book?.id != bookId) return;
    _book = await Library(store).getBook(bookId);
    _replaceLines(await lines(bookId, _chapter));
    final saved = await bookmark(bookId);
    _line = (saved?.line ?? 0).clamp(0, (_lines.length - 1).clamp(0, 10000000));
    _publish();
  });

  Future<void> _command(Future<void> Function() action) {
    final next = _commands.then((_) async {
      if (_closed) return;
      try {
        await action();
      } on SpeechUnavailable {
        _error = 'systemVoiceUnavailable';
        _loading = false;
        await engine.pause();
        _publish();
      } catch (_) {
        _error = 'audioFailed';
        _loading = false;
        await engine.pause();
        _publish();
      }
    });
    _commands = next;
    return next;
  }

  Future<void> get settled async {
    await _commands;
    await _saved;
  }

  @override
  Future<void> open(String bookId, {int? chapter, int? line}) {
    _cancelPending();
    return _command(() async {
      await _savePosition();
      final book = await Library(store).getBook(bookId);
      final saved = await bookmark(bookId);
      final selected = chapter ?? saved?.chapter ?? 1;
      await _loadChapter(
        book,
        selected,
        line ?? (chapter == null ? saved?.line ?? 0 : 0),
        play: true,
        sourceOffset: line == null && chapter == null
            ? saved?.sourceOffset
            : null,
      );
    });
  }

  Future<bool> _hasAudio(Book book, int chapter) async {
    final script = await ScriptRepository(store).get(book.id, chapter);
    if (script == null ||
        script.sourceTextHash != book.chapter(chapter).textHash) {
      return false;
    }
    try {
      return await AudioRepository(store).isComplete(
        script,
        mode: await generation?.coreMode(book.id) ?? PerformanceMode.audiobook,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ListeningLine>> lines(String bookId, int chapter) async {
    final book = await Library(store).getBook(bookId);
    final source = book.chapter(chapter).text;
    final script = await ScriptRepository(store).get(bookId, chapter);
    if (script != null &&
        script.sourceTextHash == book.chapter(chapter).textHash &&
        !(_book?.id == bookId &&
            _chapter == chapter &&
            _source == ListeningSource.system)) {
      final cast = await CastRepository(store).get(bookId);
      String? named(Speaker? speaker) =>
          speaker == null || speaker.kind == SpeakerKind.narrator
          ? null
          : speaker.name;
      return [
        for (var i = 0; i < script.lines.length; i++)
          ListeningLine(
            index: i,
            text: script.lines[i].textIn(source),
            start: script.lines[i].start,
            end: script.lines[i].end,
            speakerId: cast
                .findSpeaker(script.lines[i].direction.speakerId)
                ?.id,
            // Narration needs no name beside it; characters do.
            speakerName: named(
              cast.findSpeaker(script.lines[i].direction.speakerId),
            ),
            nonStory: script.lines[i].isNonStory,
            directed: true,
          ),
      ];
    }
    return splitSentences(source);
  }

  /// Keeps every UTF-16 character, including whitespace, in its original range.
  static List<ListeningLine> splitSentences(String source) {
    final result = <ListeningLine>[];
    var start = 0;
    for (final match in RegExp(
      r'[。！？.!?]+[”’"\x27]*\s*|[\r\n]+',
    ).allMatches(source)) {
      if (source.substring(start, match.end).trim().isEmpty) continue;
      result.add(
        ListeningLine(
          index: result.length,
          text: source.substring(start, match.end),
          start: start,
          end: match.end,
        ),
      );
      start = match.end;
    }
    if (start < source.length) {
      result.add(
        ListeningLine(
          index: result.length,
          text: source.substring(start),
          start: start,
          end: source.length,
        ),
      );
    }
    final bounded = <ListeningLine>[];
    for (final line in result) {
      var offset = line.start;
      while (offset < line.end) {
        var end = (offset + 2000).clamp(offset, line.end);
        if (end < line.end &&
            source.codeUnitAt(end - 1) >= 0xd800 &&
            source.codeUnitAt(end - 1) <= 0xdbff) {
          end--;
        }
        bounded.add(
          ListeningLine(
            index: bounded.length,
            text: source.substring(offset, end),
            start: offset,
            end: end,
          ),
        );
        offset = end;
      }
    }
    return bounded;
  }

  Future<void> _loadChapter(
    Book book,
    int chapter,
    int line, {
    required bool play,
    int? sourceOffset,
  }) async {
    book.chapter(chapter);
    final previousLines = await lines(book.id, chapter);
    final offset =
        sourceOffset ??
        (previousLines.isEmpty
            ? 0
            : previousLines[line.clamp(0, previousLines.length - 1)].start);
    final epoch = _epoch;
    _stopWaiting();
    _wantPlay = play;
    _waiting = false;
    _streaming = false;
    _fallback = false;
    _queue = null;
    _audioHash = null;
    _mode = await generation?.coreMode(book.id) ?? PerformanceMode.audiobook;
    _loading = true;
    _error = null;
    _publish();
    await engine.pause();
    _book = book;
    _chapter = chapter;
    _lastSavedLine = null;
    final hasAudio = await _hasAudio(book, chapter);
    _source = ListeningSource.synthesized;
    _replaceLines(await lines(book.id, chapter));
    _requestedOffset = offset;
    try {
      _aiVoice = await generation?.active(book.id) ?? false;
    } catch (_) {
      _aiVoice = false;
    }
    if (!hasAudio && generation != null) {
      _publish();
      // Never asks: AI voices are prepared while playback waits, or the
      // system voice reads the chapter.
      final choice = await generation!.plan(book.id, chapter, _mode);
      if (epoch != _epoch) {
        _loading = false;
        _publish();
        return;
      }
      _source = choice == GenerationChoice.generate
          ? ListeningSource.synthesized
          : ListeningSource.system;
    } else {
      _source = hasAudio ? ListeningSource.synthesized : ListeningSource.system;
    }
    if (_source == ListeningSource.system) {
      _replaceLines(splitSentences(book.chapter(chapter).text));
      final mapped = _lines.indexWhere((l) => l.end > _requestedOffset);
      line = mapped < 0 ? 0 : mapped;
    }
    final completed = hasAudio
        ? await AudioRepository(store).get(book.id, chapter, mode: _mode)
        : null;
    final preparedPath = completed?.path;
    final hasPreparedFile =
        preparedPath != null && await File(preparedPath).exists();
    if (_source == ListeningSource.synthesized &&
        generation != null &&
        !hasPreparedFile) {
      _streaming = true;
      _waiting = true;
      _audioComplete = false;
      _line = line.clamp(0, (_lines.length - 1).clamp(0, 10000000));
      _loading = false;
      _startWaiting();
      _publish();
      if (play) {
        await generation?.listening(book.id, chapter: chapter, mode: _mode);
      }
      await _refreshStream();
      return;
    }
    if (_lines.isEmpty) {
      _loading = false;
      _error = 'chapterUnavailable';
      _publish();
      return;
    }
    _line = line.clamp(0, _lines.length - 1);
    if (_source == ListeningSource.synthesized) {
      final audio = (await AudioRepository(
        store,
      ).get(book.id, chapter, mode: _mode))!;
      _queue = PlaybackQueue(audio.utterances);
      if (_queue!.entries.isEmpty) throw StateError('Empty audio.');
      final path = hasPreparedFile
          ? preparedPath
          : '${AudioRepository(store).bookDirectory(book.id).path}/playback-$chapter-${audio.inputsHash}.wav';
      final file = File(path);
      // Input hash includes voices and pronunciation; completed files can be
      // reused when opening the chapter or choosing another starting line.
      if (!await file.exists() || await file.length() <= 44) {
        await _queue!.writeWav(file);
      }
      await engine.load(path, _queue!.duration);
      if (_queue!.indexForLine(_line) < 0) {
        _line = _queue!.entries.first.utterance.lineIndices.first;
      }
      await engine.seek(_queue!.positionForLine(_line));
    } else {
      _queue = null;
      await _loadSentence();
    }
    await engine.setSpeed(_speed);
    _completionScheduled = false;
    _loading = false;
    if (play) await engine.play();
    _publish();
    // Chapters ahead are prepared while the book is listened to, whichever
    // voice reads this one; the generation service knows whether to.
    if (play) {
      await generation?.listening(book.id, chapter: chapter, mode: _mode);
    } else {
      await generation?.listening(null);
    }
    await _savePosition();
  }

  Future<void> _refreshStream() async {
    if (!_streaming || _book == null) return;
    final book = _book!;
    // A paused book will not voice this chapter soon: the system voice
    // reads it instead of leaving the listener in silence.
    if (_waiting &&
        _wantPlay &&
        generation?.failure(book.id, _chapter) != null) {
      await _fallBack();
      return;
    }
    _publish();
    final repository = AudioRepository(store);
    final script = await ScriptRepository(store).get(book.id, _chapter);
    if (script == null ||
        script.sourceTextHash != book.chapter(_chapter).textHash) {
      return;
    }
    final audio = await repository.get(book.id, _chapter, mode: _mode);
    if (audio == null ||
        audio.scriptHash != AudioRepository.hashScript(script) ||
        audio.inputsHash != await repository.hashInputs(script, _mode)) {
      return;
    }
    if (audio.utterances.isEmpty) {
      if (audio.complete) {
        _audioComplete = true;
        _waiting = false;
        if (_wantPlay) await _advance();
      }
      return;
    }
    _audioComplete = audio.complete;
    final old = _queue;
    final reset = old == null || _audioHash != audio.inputsHash;
    final count = reset ? 0 : old.entries.length;
    if (!reset && audio.utterances.length <= count) {
      if (_waiting && audio.complete && _wantPlay) await _advance();
      return;
    }
    final targetQueue = PlaybackQueue(audio.utterances);
    final segments = <PlaybackSegment>[];
    for (final entry in targetQueue.entries.skip(count)) {
      final path =
          '${repository.bookDirectory(book.id).path}/segments/${entry.utterance.cacheKey}-${entry.utterance.pauseBefore.inMicroseconds}.wav';
      final file = File(path);
      if (!await file.exists()) {
        await PlaybackQueue([entry.utterance]).writeWav(file);
      }
      segments.add(PlaybackSegment(path, entry.end - entry.start));
    }
    _loading = true;
    final oldPosition = engine.state.position;
    final wasWaiting = _waiting;
    _queue = targetQueue;
    _audioHash = audio.inputsHash;
    _replaceLines(await lines(book.id, _chapter));
    final targetLine = _lines
        .where(
          (l) =>
              l.end > _requestedOffset &&
              targetQueue.indexForLine(l.index) >= 0,
        )
        .firstOrNull;
    if (reset && targetLine == null && !audio.complete) {
      _queue = null;
      _loading = false;
      return;
    }
    if (engine case final GrowingPlaybackEngine growing) {
      if (reset) {
        await growing.loadPlaylist(segments);
      } else {
        await growing.appendPlaylist(segments);
      }
    } else {
      // Non-production engines can exercise the same timeline via a snapshot.
      final path =
          '${repository.bookDirectory(book.id).path}/stream-${audio.inputsHash}-${audio.utterances.length}.wav';
      await targetQueue.writeWav(File(path));
      await engine.load(path, targetQueue.duration);
      if (!reset) await engine.seek(oldPosition);
    }
    if (reset) {
      _line =
          targetLine?.index ??
          targetQueue.entries.first.utterance.lineIndices.first;
      await engine.seek(targetQueue.positionForLine(_line));
    }
    await engine.setSpeed(_speed);
    _waiting = false;
    _stopWaiting();
    _loading = false;
    _error = null;
    _completionScheduled = false;
    if (_wantPlay && (reset || wasWaiting || !engine.state.playing)) {
      await engine.play();
    }
    _publish();
    if (_wantPlay) {
      await generation?.firstSound(book.id, _chapter, _mode);
      await generation?.listening(book.id, chapter: _chapter, mode: _mode);
    }
    await _savePosition();
  }

  Future<void> _loadSentence() async {
    final path = await speech.render(
      _book!.id,
      _lines[_line].text,
      _book!.language,
    );
    await engine.load(path, Duration.zero);
    await engine.setSpeed(_speed);
    // The next sentence renders while this one plays, so there is no
    // silence between them.
    final next = _lines.skip(_line + 1).where((l) => l.text.trim().isNotEmpty);
    if (next.isNotEmpty) {
      unawaited(speech.prefetch(_book!.id, next.first.text, _book!.language));
    }
  }

  void _onEngine(EngineState state) {
    if (_closed || _loading || _book == null) return;
    if (_source == ListeningSource.synthesized && _queue != null) {
      final index = _queue!.indexAt(state.position);
      if (index >= 0) {
        _line = _queue!.entries[index].utterance.lineIndices.first;
      }
    }
    if (state.error != null) _error = 'audioFailed';
    _publish();
    if (_lastSavedLine != _line) unawaited(_savePosition());
    if (state.completed && !_completionScheduled) {
      _completionScheduled = true;
      unawaited(_command(_advance));
    }
  }

  Future<void> _advance() async {
    if (_streaming && !_audioComplete) {
      _waiting = true;
      _completionScheduled = false;
      _startWaiting();
      _publish();
      await _refreshStream();
      return;
    }
    if (_source == ListeningSource.system && _line + 1 < _lines.length) {
      await _moveLine(_line + 1, play: true);
      return;
    }
    if (_sleepAfterChapter) {
      _sleepAfterChapter = false;
      _wantPlay = false;
      await generation?.listening(null);
      await engine.pause();
      _publish();
      await _savePosition();
      return;
    }
    if (_chapter < _book!.chapters.length) {
      await _loadChapter(_book!, _chapter + 1, 0, play: true);
    } else {
      await engine.pause();
      _wantPlay = false;
      await generation?.listening(null);
      _error = 'endOfBook';
      _publish();
      await _savePosition();
    }
  }

  void _publish() {
    if (_closed) return;
    final e = engine.state;
    final q = _queue;
    final index = q?.indexAt(e.position) ?? -1;
    final remaining = _sleepUntil?.difference(_now());
    value = ListeningState(
      bookId: _book?.id,
      bookTitle: _book?.title ?? '',
      chapter: _chapter,
      chapterTitle: _book?.chapter(_chapter).title ?? '',
      chapterCount: _book?.chapters.length ?? 0,
      line: _line,
      lineCount: _lines.length,
      lineRevision: _lineRevision,
      activeLines: _lines.isEmpty
          ? const []
          : (_source == ListeningSource.synthesized && index >= 0
                ? q!.entries[index].utterance.lineIndices
                : [_line]),
      playing: !_loading && !_waiting && e.playing && _error == null,
      buffering:
          _loading ||
          (_waiting &&
              _wantPlay &&
              generation?.failure(_book?.id ?? '', _chapter) == null) ||
          e.buffering,
      source: _source,
      position: _source == ListeningSource.synthesized
          ? e.position
          : Duration.zero,
      duration: _source == ListeningSource.synthesized
          ? q?.duration ?? Duration.zero
          : Duration.zero,
      durationComplete: !_streaming || _audioComplete,
      speed: _speed,
      sleepRemaining: remaining == null
          ? null
          : (remaining.isNegative ? Duration.zero : remaining),
      sleepAfterChapter: _sleepAfterChapter,
      error: _error,
      aiVoice: _aiVoice,
      fallback: _fallback,
      waitingSince: _waiting && _wantPlay ? _waitingSince : null,
    );
  }

  Future<void> _savePosition() {
    final book = _book;
    if (book == null || _lines.isEmpty || _loading) return Future.value();
    final snapshot = value;
    final sourceOffset =
        _lines[snapshot.line.clamp(0, _lines.length - 1)].start;
    _lastSavedLine = _line;
    final result = _saved.then((_) async {
      if (!await store.exists('books', book.id)) return;
      await store.put('listening', book.id, {
        'bookId': book.id,
        'chapter': snapshot.chapter,
        'line': snapshot.line,
        'sourceOffset': sourceOffset,
        'progress':
            ((snapshot.chapter - 1 + snapshot.progress) / book.chapters.length)
                .clamp(0, 1),
        'at': _now().toUtc().microsecondsSinceEpoch,
      });
    });
    _saved = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<ListeningBookmark?> bookmark(String bookId) async {
    final json = await store.get('listening', bookId);
    return json == null
        ? null
        : ListeningBookmark(
            bookId: bookId,
            chapter: json['chapter'] as int,
            line: json['line'] as int,
            progress: (json['progress'] as num).toDouble(),
            sourceOffset: json['sourceOffset'] as int?,
            listenedAt: json['at'] is int
                ? DateTime.fromMicrosecondsSinceEpoch(
                    json['at'] as int,
                    isUtc: true,
                  )
                : null,
          );
  }

  @override
  Future<void> play() => _command(() async {
    if (_book == null) return;
    _wantPlay = true;
    if (_streaming && _waiting) {
      _startWaiting();
      await generation?.listening(_book!.id, chapter: _chapter, mode: _mode);
      await _refreshStream();
      return;
    }
    if (_error != null) {
      await _loadChapter(_book!, _chapter, _line, play: true);
      return;
    }
    if (engine.state.completed) {
      if (_source == ListeningSource.system) {
        await _moveLine(_line, play: true);
        return;
      }
      await engine.seek(Duration.zero);
    }
    _completionScheduled = false;
    await engine.play();
    await generation?.listening(_book!.id, chapter: _chapter, mode: _mode);
    _publish();
  });
  @override
  Future<void> pause() {
    _cancelPending();
    _wantPlay = false;
    _stopWaiting();
    return _command(() async {
      await generation?.listening(null);
      await engine.pause();
      _publish();
      await _savePosition();
    });
  }

  Future<void> _moveLine(int line, {required bool play}) async {
    if (_book == null || _lines.isEmpty) return;
    _wantPlay = play;
    _loading = true;
    _publish();
    await engine.pause();
    _line = line.clamp(0, _lines.length - 1);
    if (_source == ListeningSource.system) {
      await _loadSentence();
    } else {
      await engine.seek(_queue!.positionForLine(_line));
    }
    _completionScheduled = false;
    _loading = false;
    if (play) await engine.play();
    _publish();
    await _savePosition();
  }

  Future<void> _step(int direction) => _command(() async {
    final play = engine.state.playing;
    if (_source == ListeningSource.system) {
      await _moveLine(_line + direction, play: play);
    } else if (_queue != null) {
      final index = _queue!.indexAt(engine.state.position);
      final next = (index + direction).clamp(0, _queue!.entries.length - 1);
      await _moveLine(
        _queue!.entries[next].utterance.lineIndices.first,
        play: play,
      );
    }
  });
  @override
  Future<void> previousLine() => _step(-1);
  @override
  Future<void> nextLine() => _step(1);
  Future<void> _stepChapter(int direction) {
    _cancelPending();
    return _command(() async {
      if (_book == null) return;
      final chapter = (_chapter + direction).clamp(1, _book!.chapters.length);
      await _savePosition();
      await _loadChapter(_book!, chapter, 0, play: _wantPlay);
    });
  }

  @override
  Future<void> previousChapter() => _stepChapter(-1);
  @override
  Future<void> nextChapter() => _stepChapter(1);
  @override
  Future<void> seek(Duration position) => _command(() async {
    if (_queue == null) return;
    await engine.seek(
      Duration(
        microseconds: position.inMicroseconds.clamp(
          0,
          _queue!.duration.inMicroseconds,
        ),
      ),
    );
    _publish();
    await _savePosition();
  });
  @override
  Future<void> setSpeed(double speed) => _command(() async {
    if (!speed.isFinite || speed < 0.5 || speed > 3) {
      throw ArgumentError.value(speed);
    }
    _speed = speed;
    await engine.setSpeed(speed);
    _publish();
    await store.put('settings', 'playback', {'speed': speed});
  });
  Future<void> restoreSettings() async {
    final json = await store.get('settings', 'playback');
    final speed = (json?['speed'] as num?)?.toDouble() ?? 1;
    if (speed.isFinite && speed >= 0.5 && speed <= 3) _speed = speed;
    _publish();
  }

  @override
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    _sleepUntil = duration == null ? null : _now().add(duration);
    _sleepAfterChapter = false;
    if (duration != null) {
      _sleepTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => checkSleepTimer(),
      );
    }
    checkSleepTimer();
  }

  void checkSleepTimer() {
    if (_sleepUntil != null && !_now().isBefore(_sleepUntil!)) {
      _sleepTimer?.cancel();
      _sleepUntil = null;
      unawaited(pause());
    }
    _publish();
  }

  @override
  void setSleepAfterChapter(bool enabled) {
    _sleepTimer?.cancel();
    _sleepUntil = null;
    _sleepAfterChapter = enabled;
    _publish();
  }

  void _onStore() {
    final bookId = _book?.id;
    if (bookId == null || _closed) return;
    unawaited(
      store.exists('books', bookId).then((exists) {
        if (!exists && !_closed && _book?.id == bookId) {
          unawaited(
            _command(() async {
              await engine.pause();
              _book = null;
              _replaceLines([]);
              _queue = null;
              _publish();
            }),
          );
        }
      }),
    );
  }

  Future<void> close() async {
    await pause();
    _sleepTimer?.cancel();
    _stopWaiting();
    store.removeListener(_onStore);
    await _generationEvents?.cancel();
    await _subscription.cancel();
    await _commands;
    await _saved;
    _closed = true;
    await speech.close();
    await engine.dispose();
    super.dispose();
  }
}
