import 'dart:async';

import 'package:flutter/foundation.dart';

import 'playback_engine.dart';
import 'playback_queue.dart';

/// Chapter playback controls and line position, independent of native audio.
class ChapterPlayer extends ChangeNotifier {
  ChapterPlayer(this.engine, this.queue) {
    _subscription = engine.states.listen((_) => notifyListeners());
  }
  final PlaybackEngine engine;
  final PlaybackQueue queue;
  late final StreamSubscription<EngineState> _subscription;
  EngineState get state => engine.state;
  int get index => queue.indexAt(state.position);
  List<int> get currentLines =>
      index < 0 ? const [] : queue.entries[index].utterance.lineIndices;
  double get progress => queue.duration == Duration.zero
      ? 0
      : (state.position.inMicroseconds / queue.duration.inMicroseconds).clamp(
          0,
          1,
        );

  Future<void> load(String path) => engine.load(path, queue.duration);
  Future<void> play() => engine.play();
  Future<void> pause() => engine.pause();
  Future<void> toggle() => state.playing ? pause() : play();
  Future<void> playFromLine(int line) async {
    await engine.seek(queue.positionForLine(line));
    await play();
  }

  Future<void> previous() async {
    if (index > 0) {
      await engine.seek(queue.entries[index - 1].audioStart);
    } else if (index == 0) {
      await engine.seek(queue.entries.first.audioStart);
    }
  }

  Future<void> next() async {
    if (index >= 0 && index + 1 < queue.entries.length) {
      await engine.seek(queue.entries[index + 1].audioStart);
    }
  }

  Future<void> seek(Duration position) => engine.seek(
    Duration(
      microseconds: position.inMicroseconds.clamp(
        0,
        queue.duration.inMicroseconds,
      ),
    ),
  );
  Future<void> setSpeed(double speed) {
    if (!speed.isFinite || speed < 0.5 || speed > 3) {
      throw ArgumentError.value(speed, 'speed');
    }
    return engine.setSpeed(speed);
  }

  Future<void> close() async {
    await _subscription.cancel();
    await engine.dispose();
    super.dispose();
  }
}
