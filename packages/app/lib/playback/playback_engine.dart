class EngineState {
  const EngineState({
    this.position = Duration.zero,
    this.playing = false,
    this.buffering = false,
    this.completed = false,
    this.speed = 1,
    this.error,
  });
  final Duration position;
  final bool playing;
  final bool buffering;
  final bool completed;
  final double speed;
  final String? error;
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
