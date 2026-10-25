import 'dart:async';
import 'dart:io';

import 'package:pagestage_app/application/provider_store.dart';
import 'package:pagestage_app/application/system_speech.dart';
import 'package:pagestage_app/playback/playback_engine.dart';
import 'package:pagestage_core/pagestage_core.dart';

class MemorySecrets implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

class MemoryEngine implements PlaybackEngine {
  final _events = StreamController<EngineState>.broadcast(sync: true);
  @override
  EngineState state = const EngineState();
  @override
  Stream<EngineState> get states => _events.stream;
  final loads = <String>[];
  void emit({
    Duration? position,
    bool? playing,
    bool completed = false,
    double? speed,
    Duration? duration,
  }) {
    state = EngineState(
      position: position ?? state.position,
      playing: playing ?? state.playing,
      completed: completed,
      speed: speed ?? state.speed,
      duration: duration ?? state.duration,
    );
    _events.add(state);
  }

  @override
  Future<void> load(String path, Duration duration) async {
    loads.add(path);
    emit(
      position: Duration.zero,
      playing: false,
      duration: duration == Duration.zero
          ? const Duration(seconds: 5)
          : duration,
    );
  }

  @override
  Future<void> play() async => emit(playing: true);
  @override
  Future<void> pause() async =>
      emit(playing: false, completed: state.completed);
  @override
  Future<void> seek(Duration position) async => emit(position: position);
  @override
  Future<void> setSpeed(double speed) async =>
      emit(speed: speed, completed: state.completed);
  @override
  Future<void> dispose() => _events.close();
  void complete() =>
      emit(position: state.duration, playing: false, completed: true);
}

class MemorySpeech implements SystemSpeech {
  final requests = <(String, String)>[];
  bool available = true;
  @override
  Future<String> render(String bookId, String text, String language) async {
    if (!available) throw const SpeechUnavailable();
    requests.add((text, language));
    return 'offline-$bookId-${requests.length}.wav';
  }

  @override
  Future<void> close() async {}
}

Future<Book> importBook(
  LocalStore store,
  Directory root, {
  String language = 'en',
}) async {
  final file = File('${root.path}/$language.txt');
  await file.writeAsString(
    language == 'en'
        ? 'Chapter 1\nFirst sentence. Second sentence!\nChapter 2\nAnother sentence. Last sentence.'
        : '第一章\n第一句话。第二句话！\n第二章\n另外一句话。最后一句话。',
  );
  return Library(store).importTxt(file.path);
}
