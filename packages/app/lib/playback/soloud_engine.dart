import 'dart:async';

import 'package:flutter_soloud/flutter_soloud.dart';

import 'playback_engine.dart';

/// Comparison candidate for #27. Relative speed changes native resampling rate.
class SoloudEngine implements PlaybackEngine {
  final _soloud = SoLoud.instance;
  final _events = StreamController<EngineState>.broadcast();
  AudioSource? _source;
  SoundHandle? _handle;
  Timer? _timer;
  var _duration = Duration.zero;
  var _position = Duration.zero;
  var _playing = false;
  var _completed = false;
  var _speed = 1.0;
  @override
  EngineState get state => EngineState(
    position: _position,
    playing: _playing,
    completed: _completed,
    speed: _speed,
  );
  @override
  Stream<EngineState> get states => _events.stream;
  void _publish() => _events.add(state);
  @override
  Future<void> load(String path, Duration duration) async {
    await _soloud.init();
    _source = await _soloud.loadFile(path);
    _handle = _soloud.play(_source!, paused: true);
    _duration = duration;
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      final handle = _handle;
      if (handle == null) return;
      if (!_soloud.getIsValidVoiceHandle(handle)) {
        if (_playing) {
          _playing = false;
          _completed = true;
          _position = _duration;
        }
      } else {
        _position = _soloud.getPosition(handle);
      }
      _publish();
    });
    _publish();
  }

  Future<void> _ensureHandle() async {
    if (_handle == null || !_soloud.getIsValidVoiceHandle(_handle!)) {
      _handle = _soloud.play(_source!, paused: true);
      _soloud.setRelativePlaySpeed(_handle!, _speed);
    }
  }

  @override
  Future<void> play() async {
    if (_completed) await seek(Duration.zero);
    await _ensureHandle();
    _soloud.setPause(_handle!, false);
    _playing = true;
    _publish();
  }

  @override
  Future<void> pause() async {
    if (_handle != null && _soloud.getIsValidVoiceHandle(_handle!)) {
      _soloud.setPause(_handle!, true);
    }
    _playing = false;
    _publish();
  }

  @override
  Future<void> seek(Duration position) async {
    await _ensureHandle();
    _soloud.seek(_handle!, position);
    _position = position;
    _completed = false;
    _publish();
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    if (_handle != null && _soloud.getIsValidVoiceHandle(_handle!)) {
      _soloud.setRelativePlaySpeed(_handle!, speed);
    }
    _publish();
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    if (_source != null) await _soloud.disposeSource(_source!);
    _soloud.deinit();
    await _events.close();
  }
}
