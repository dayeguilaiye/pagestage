import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pagestage_core/pagestage_core.dart';

import '../playback/playback_engine.dart';
import '../playback/playback_queue.dart';
import 'contracts.dart';
import 'system_speech.dart';

class ListeningController extends ValueNotifier<ListeningState>
    implements Listening {
  ListeningController({
    required this.store,
    required this.engine,
    required this.speech,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const ListeningState()) {
    _subscription = engine.states.listen(_onEngine);
    store.addListener(_onStore);
  }
  final LocalStore store;
  final PlaybackEngine engine;
  final SystemSpeech speech;
  final DateTime Function() _now;
  late final StreamSubscription<EngineState> _subscription;
  Future<void> _commands = Future.value();
  Future<void> _saved = Future.value();
  Book? _book;
  int _chapter = 1;
  int _line = 0;
  List<ListeningLine> _lines = [];
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
  Future<void> open(String bookId, {int? chapter, int? line}) =>
      _command(() async {
        await _savePosition();
        final book = await Library(store).getBook(bookId);
        final saved = await bookmark(bookId);
        final selected = chapter ?? saved?.chapter ?? 1;
        await _loadChapter(
          book,
          selected,
          line ?? (chapter == null ? saved?.line ?? 0 : 0),
          play: true,
        );
      });

  Future<bool> _hasAudio(Book book, int chapter) async {
    final script = await ScriptRepository(store).get(book.id, chapter);
    if (script == null ||
        script.sourceTextHash != book.chapter(chapter).textHash) {
      return false;
    }
    try {
      return await AudioRepository(store).isComplete(script);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<ListeningLine>> lines(String bookId, int chapter) async {
    final book = await Library(store).getBook(bookId);
    final source = book.chapter(chapter).text;
    if (await _hasAudio(book, chapter)) {
      final script = (await ScriptRepository(store).get(bookId, chapter))!;
      final cast = await CastRepository(store).get(bookId);
      return [
        for (var i = 0; i < script.lines.length; i++)
          ListeningLine(
            index: i,
            text: script.lines[i].textIn(source),
            start: script.lines[i].start,
            end: script.lines[i].end,
            speakerName: cast
                .findSpeaker(script.lines[i].direction.speakerId)
                ?.name,
            nonStory: script.lines[i].isNonStory,
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
  }) async {
    book.chapter(chapter);
    _loading = true;
    _error = null;
    _publish();
    await engine.pause();
    _book = book;
    _chapter = chapter;
    _lastSavedLine = null;
    _source = await _hasAudio(book, chapter)
        ? ListeningSource.synthesized
        : ListeningSource.system;
    _lines = await lines(book.id, chapter);
    if (_lines.isEmpty) {
      _loading = false;
      _error = 'chapterUnavailable';
      _publish();
      return;
    }
    _line = line.clamp(0, _lines.length - 1);
    if (_source == ListeningSource.synthesized) {
      final audio = (await AudioRepository(store).get(book.id, chapter))!;
      _queue = PlaybackQueue(audio.utterances);
      if (_queue!.entries.isEmpty) throw StateError('Empty audio.');
      final path =
          '${AudioRepository(store).bookDirectory(book.id).path}/playback-$chapter-${audio.inputsHash}.wav';
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
    if (_source == ListeningSource.system && _line + 1 < _lines.length) {
      await _moveLine(_line + 1, play: true);
      return;
    }
    if (_sleepAfterChapter) {
      _sleepAfterChapter = false;
      await engine.pause();
      _publish();
      await _savePosition();
      return;
    }
    if (_chapter < _book!.chapters.length) {
      await _loadChapter(_book!, _chapter + 1, 0, play: true);
    } else {
      await engine.pause();
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
      activeLines: _lines.isEmpty
          ? const []
          : (_source == ListeningSource.synthesized && index >= 0
                ? q!.entries[index].utterance.lineIndices
                : [_line]),
      playing: !_loading && e.playing && _error == null,
      buffering: _loading || e.buffering,
      source: _source,
      position: _source == ListeningSource.synthesized
          ? e.position
          : Duration.zero,
      duration: _source == ListeningSource.synthesized
          ? q?.duration ?? Duration.zero
          : Duration.zero,
      speed: _speed,
      sleepRemaining: remaining == null
          ? null
          : (remaining.isNegative ? Duration.zero : remaining),
      sleepAfterChapter: _sleepAfterChapter,
      error: _error,
    );
  }

  Future<void> _savePosition() {
    final book = _book;
    if (book == null || _lines.isEmpty || _loading) return Future.value();
    final snapshot = value;
    _lastSavedLine = _line;
    final result = _saved.then((_) async {
      if (await store.get('books', book.id) == null) return;
      await store.put('listening', book.id, {
        'bookId': book.id,
        'chapter': snapshot.chapter,
        'line': snapshot.line,
        'progress':
            ((snapshot.chapter - 1 + snapshot.progress) / book.chapters.length)
                .clamp(0, 1),
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
          );
  }

  @override
  Future<void> play() => _command(() async {
    if (_book == null) return;
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
    _publish();
  });
  @override
  Future<void> pause() => _command(() async {
    await engine.pause();
    _publish();
    await _savePosition();
  });

  Future<void> _moveLine(int line, {required bool play}) async {
    if (_book == null || _lines.isEmpty) return;
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
  Future<void> _stepChapter(int direction) => _command(() async {
    if (_book == null) return;
    final chapter = (_chapter + direction).clamp(1, _book!.chapters.length);
    await _savePosition();
    await _loadChapter(_book!, chapter, 0, play: engine.state.playing);
  });
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
      store.get('books', bookId).then((book) {
        if (book == null && !_closed && _book?.id == bookId) {
          unawaited(
            _command(() async {
              await engine.pause();
              _book = null;
              _lines = [];
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
    store.removeListener(_onStore);
    await _subscription.cancel();
    await _commands;
    await _saved;
    _closed = true;
    await speech.close();
    await engine.dispose();
    super.dispose();
  }
}
