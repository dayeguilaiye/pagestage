import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'playback_engine.dart';

class JustAudioEngine implements GrowingPlaybackEngine {
  JustAudioEngine() {
    _subscriptions.addAll([
      _player.currentIndexStream.listen((_) => _publish()),
      _player.positionStream.listen((_) => _publish()),
      _player.playerStateStream.listen((_) => _publish()),
      _player.speedStream.listen((_) => _publish()),
      _player.errorStream.listen((_) {
        _error = 'playback_failed';
        _publish();
      }),
    ]);
  }
  final _player = AudioPlayer();
  final _events = StreamController<EngineState>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];
  String? _error;
  final _segments = <PlaybackSegment>[];
  Duration get _offset => _segments
      .take(_player.currentIndex ?? 0)
      .fold(Duration.zero, (a, s) => a + s.duration);
  Duration get _total =>
      _segments.fold(Duration.zero, (a, s) => a + s.duration);
  @override
  EngineState get state => EngineState(
    position: _offset + _player.position,
    playing:
        _player.playing && _player.processingState != ProcessingState.completed,
    buffering:
        _player.processingState == ProcessingState.loading ||
        _player.processingState == ProcessingState.buffering,
    completed: _player.processingState == ProcessingState.completed,
    speed: _player.speed,
    error: _error,
    duration: _segments.isEmpty ? _player.duration : _total,
  );
  @override
  Stream<EngineState> get states => _events.stream;
  void _publish() => _events.add(state);
  @override
  Future<void> load(String path, Duration duration) async {
    _error = null;
    _segments.clear();
    await _player.setFilePath(path);
    _publish();
  }

  @override
  Future<void> play() async {
    if (state.completed) await seek(Duration.zero);
    unawaited(
      _player.play().catchError((Object _) {
        _error = 'playback_failed';
        _publish();
      }),
    );
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) async {
    if (_segments.isEmpty) return _player.seek(position);
    var offset = Duration.zero;
    for (var i = 0; i < _segments.length; i++) {
      if (position < offset + _segments[i].duration ||
          i == _segments.length - 1) {
        return _player.seek(position - offset, index: i);
      }
      offset += _segments[i].duration;
    }
  }

  @override
  Future<void> loadPlaylist(List<PlaybackSegment> segments) async {
    _error = null;
    _segments
      ..clear()
      ..addAll(segments);
    await _player.setAudioSources([
      for (final s in segments) AudioSource.file(s.path),
    ]);
    _publish();
  }

  @override
  Future<void> appendPlaylist(List<PlaybackSegment> segments) async {
    if (segments.isEmpty) return;
    final wasCompleted = state.completed;
    final position = state.position;
    _segments.addAll(segments);
    await _player.addAudioSources([
      for (final s in segments) AudioSource.file(s.path),
    ]);
    if (wasCompleted) await seek(position);
    _publish();
  }

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    await _events.close();
  }
}
