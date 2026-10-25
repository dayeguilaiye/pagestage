import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'playback_engine.dart';

class JustAudioEngine implements PlaybackEngine {
  JustAudioEngine() {
    _subscriptions.addAll([
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
  @override
  EngineState get state => EngineState(
    position: _player.position,
    playing:
        _player.playing && _player.processingState != ProcessingState.completed,
    buffering:
        _player.processingState == ProcessingState.loading ||
        _player.processingState == ProcessingState.buffering,
    completed: _player.processingState == ProcessingState.completed,
    speed: _player.speed,
    error: _error,
    duration: _player.duration,
  );
  @override
  Stream<EngineState> get states => _events.stream;
  void _publish() => _events.add(state);
  @override
  Future<void> load(String path, Duration duration) async {
    _error = null;
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
  Future<void> seek(Duration position) => _player.seek(position);
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
