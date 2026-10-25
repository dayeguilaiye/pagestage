import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:pagestage_core/pagestage_core.dart';

/// Native speech renders a sentence locally; the shared audio engine supplies
/// precise playback rate, pause, seeking and system media controls.
abstract interface class SystemSpeech {
  Future<String> render(String bookId, String text, String language);
  Future<void> close();
}

class PlatformSystemSpeech implements SystemSpeech {
  PlatformSystemSpeech(this.audio, {FlutterTts? tts})
    : _tts = tts ?? FlutterTts();
  final AudioRepository audio;
  final FlutterTts _tts;
  bool _initialized = false;
  Future<void> _queue = Future.value();

  @override
  Future<String> render(String bookId, String text, String language) {
    final operation = _queue.then((_) => _render(bookId, text, language));
    _queue = operation.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return operation;
  }

  Future<String> _render(String bookId, String text, String language) async {
    if (!_initialized) {
      await _tts.awaitSynthCompletion(true);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1);
      _initialized = true;
    }
    final locale = language == 'zh' ? 'zh-CN' : 'en-US';
    if (await _tts.isLanguageAvailable(locale) != true) {
      throw const SpeechUnavailable();
    }
    final voices = (await _tts.getVoices as List).cast<Map>();
    final available = voices
        .where(
          (v) =>
              (v['locale'] as String? ?? '')
                  .replaceAll('_', '-')
                  .startsWith(language) &&
              v['network_required'] != '1' &&
              v['network_required'] != 1 &&
              v['network_required'] != 'true' &&
              v['network_required'] != true &&
              v['networkRequired'] != true &&
              v['networkRequired'] != 'true',
        )
        .toList();
    if (available.isEmpty) throw const SpeechUnavailable();
    available.sort((a, b) {
      final exactA = a['locale'] == locale ? 0 : 1;
      final exactB = b['locale'] == locale ? 0 : 1;
      return exactA == exactB
          ? '${a['name']}'.compareTo('${b['name']}')
          : exactA.compareTo(exactB);
    });
    final voice = available.first;
    await _tts.setLanguage('${voice['locale']}');
    await _tts.setVoice({
      'name': '${voice['name']}',
      'locale': '${voice['locale']}',
    });
    // A filesystem-safe deterministic cache key without introducing a new
    // hashing implementation: Chapter uses the core UTF-8 content hash.
    final hash = Chapter(
      number: 1,
      title: '',
      text: jsonEncode([text, language, voice['name'], 0.5]),
    ).textHash;
    final directory = Directory('${audio.bookDirectory(bookId).path}/system');
    await directory.create(recursive: true);
    final file = File('${directory.path}/$hash.wav');
    if (await file.exists() && await file.length() > 44) return file.path;
    final temporary = '${directory.path}/$hash.part.wav';
    try {
      final result = await _tts.synthesizeToFile(text, temporary, true);
      final staged = File(temporary);
      if (result != 1 ||
          !await staged.exists() ||
          await staged.length() <= 44) {
        throw const SpeechUnavailable();
      }
      await staged.rename(file.path);
      return file.path;
    } catch (_) {
      final staged = File(temporary);
      if (await staged.exists()) await staged.delete();
      throw const SpeechUnavailable();
    }
  }

  @override
  Future<void> close() async {
    await _queue;
    await _tts.stop();
  }
}

class SpeechUnavailable implements Exception {
  const SpeechUnavailable();
  @override
  String toString() => 'systemVoiceUnavailable';
}
