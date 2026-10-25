import 'package:audio_service/audio_service.dart';

import 'contracts.dart';

/// One media session serves generated audio and local system speech.
class ListeningHandler extends BaseAudioHandler {
  ListeningHandler(this.listening) {
    listening.addListener(_publish);
    _publish();
  }
  final Listening listening;
  String? _queuedBook;
  int _queuedChapters = -1;
  void _publish() {
    final s = listening.value;
    final duration = s.duration == Duration.zero ? null : s.duration;
    final id = s.bookId == null ? null : '${s.bookId}:${s.chapter}';
    final previous = mediaItem.value;
    if (previous?.id != id ||
        previous?.title != s.chapterTitle ||
        previous?.album != s.bookTitle ||
        previous?.duration != duration) {
      mediaItem.add(
        id == null
            ? null
            : MediaItem(
                id: id,
                title: s.chapterTitle,
                album: s.bookTitle,
                duration: duration,
              ),
      );
    }
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          s.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: {
          MediaAction.playPause,
          MediaAction.setSpeed,
          MediaAction.skipToQueueItem,
          MediaAction.rewind,
          MediaAction.fastForward,
          if (s.duration > Duration.zero) MediaAction.seek,
        },
        playing: s.playing,
        updatePosition: s.position,
        speed: s.speed,
        processingState: s.bookId == null
            ? AudioProcessingState.idle
            : s.error == 'endOfBook'
            ? AudioProcessingState.completed
            : s.error != null
            ? AudioProcessingState.error
            : s.buffering
            ? AudioProcessingState.buffering
            : AudioProcessingState.ready,
        errorCode: s.error == null || s.error == 'endOfBook' ? null : 1,
      ),
    );
    if (_queuedBook != s.bookId || _queuedChapters != s.chapterCount) {
      _queuedBook = s.bookId;
      _queuedChapters = s.chapterCount;
      queue.add([
        for (var chapter = 1; chapter <= s.chapterCount; chapter++)
          MediaItem(
            id: '${s.bookId}:$chapter',
            title: '$chapter',
            album: s.bookTitle,
          ),
      ]);
    }
  }

  @override
  Future<void> play() => listening.play();
  @override
  Future<void> pause() => listening.pause();
  @override
  Future<void> seek(Duration position) => listening.seek(position);
  @override
  Future<void> skipToPrevious() => listening.previousLine();
  @override
  Future<void> skipToNext() => listening.nextLine();
  @override
  Future<void> rewind() => listening.previousChapter();
  @override
  Future<void> fastForward() => listening.nextChapter();
  @override
  Future<void> skipToQueueItem(int index) async {
    final id = listening.value.bookId;
    if (id != null && index >= 0 && index < listening.value.chapterCount) {
      await listening.open(id, chapter: index + 1);
    }
  }

  @override
  Future<void> setSpeed(double speed) => listening.setSpeed(speed);
  @override
  Future<void> stop() async {
    await listening.pause();
    playbackState.add(
      playbackState.value.copyWith(processingState: AudioProcessingState.idle),
    );
    await super.stop();
  }

  Future<void> close() async {
    listening.removeListener(_publish);
    await stop();
  }
}
