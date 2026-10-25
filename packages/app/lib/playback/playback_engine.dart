class EngineState {
  const EngineState({
    this.position = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.speed = 1,
    this.error,
    this.duration,
  });
  final Duration position;
  final bool playing;
  final bool buffering;
  final bool completed;
  final double speed;
  final String? error;
  final Duration? duration;
}

/// Native engine seam exercised by just_audio, SoLoud and the offline fake.
abstract interface class PlaybackEngine {
  EngineState get state;
  Stream<EngineState> get states;
  Future<void> load(String path, Duration duration);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> dispose();
}

class PlaybackSegment {
  const PlaybackSegment(this.path, this.duration);
  final String path;
  final Duration duration;
}

/// A growing native playlist with global timeline positions and gapless tracks.
abstract interface class GrowingPlaybackEngine implements PlaybackEngine {
  Future<void> loadPlaylist(List<PlaybackSegment> segments);
  Future<void> appendPlaylist(List<PlaybackSegment> segments);
}
