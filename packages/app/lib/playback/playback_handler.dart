import 'package:audio_service/audio_service.dart';

import 'chapter_player.dart';

/// Lock screen, notification and on-screen controls all drive the same player.
class PlaybackHandler extends BaseAudioHandler {
  PlaybackHandler(
    this.player, {
    required String bookId,
    required String title,
    required String chapterTitle,
  }) {
    mediaItem.add(
      MediaItem(
        id: bookId,
        title: chapterTitle,
        album: title,
        duration: player.queue.duration,
      ),
    );
    player.addListener(_publish);
    _publish();
  }
  final ChapterPlayer player;
  void _publish() {
    final state = player.state;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          state.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.playPause,
          MediaAction.seek,
          MediaAction.setSpeed,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: state.error != null
            ? AudioProcessingState.error
            : state.completed
            ? AudioProcessingState.completed
            : state.buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        playing: state.playing,
        updatePosition: state.position,
        speed: state.speed,
        errorCode: state.error == null ? null : 1,
        errorMessage: state.error,
      ),
    );
  }

  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> seek(Duration position) => player.seek(position);
  @override
  Future<void> skipToPrevious() => player.previous();
  @override
  Future<void> skipToNext() => player.next();
  @override
  Future<void> setSpeed(double speed) => player.setSpeed(speed);
  @override
  Future<void> stop() async {
    await player.pause();
    playbackState.add(
      playbackState.value.copyWith(processingState: AudioProcessingState.idle),
    );
    await super.stop();
  }

  Future<void> close() async {
    player.removeListener(_publish);
    await stop();
    await player.close();
  }
}
