import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:pagestage_core/pagestage_core.dart';

/// One voice the phone offers for reading aloud.
class SystemVoice {
  const SystemVoice({
    required this.name,
    required this.locale,
    this.quality = 0,
    this.selected = false,
  });
  final String name;
  final String locale;

  /// 0 for a basic voice, 1 enhanced, 2 premium, as the system says.
  final int quality;

  /// The one used for this language now.
  final bool selected;
}

/// Native speech renders a sentence locally; the shared audio engine supplies
/// precise playback rate, pause, seeking and system media controls.
abstract interface class SystemSpeech {
  Future<String> render(String bookId, String text, String language);

  /// Renders [text] ahead, so the next sentence starts without a gap.
  Future<void> prefetch(String bookId, String text, String language);

  /// The phone's offline voices for [language], the one in use marked.
  Future<List<SystemVoice>> voices(String language);

  /// Reads in [name] for [language] from now on; null goes back to the
  /// best voice the phone has.
  Future<void> choose(String language, String? name);

  /// Speaks a short sample in [name], without the shared player.
  Future<void> preview(String language, String name);
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

  @override
  Future<void> prefetch(String bookId, String text, String language) => render(
    bookId,
    text,
    language,
  ).then<void>((_) {}, onError: (Object _, StackTrace _) {});

  Future<void> _initialize() async {
    if (_initialized) return;
    await _tts.awaitSynthCompletion(true);
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1);
    _initialized = true;
  }

  /// Apple's novelty voices (Bubbles, Bad News …) and its older robotic
  /// ones read a book badly: they come last, never chosen by default.
  static const _novelty = {
    'Albert', 'Bad News', 'Bahh', 'Bells', 'Boing', 'Bubbles', 'Cellos',
    'Good News', 'Jester', 'Organ', 'Superstar', 'Trinoids', 'Whisper',
    'Wobble', 'Zarvox', 'Fred', 'Junior', 'Kathy', 'Ralph',
    // Eloquence voices.
    'Eddy', 'Flo', 'Grandma', 'Grandpa', 'Reed', 'Rocko', 'Sandy', 'Shelley',
  };

  static bool _isNovelty(Map voice) {
    final id = '${voice['identifier']}'.toLowerCase();
    if (id.contains('speech.synthesis.voice') || id.contains('eloquence')) {
      return true;
    }
    final name = '${voice['name']}';
    return _novelty.contains(name) ||
        _novelty.any((n) => name.startsWith('$n ('));
  }

  /// How good the system says a voice is: premium above enhanced above the
  /// basic voices most phones ship with.
  static int _quality(Map voice) {
    final quality = voice['quality'];
    if (quality is num) {
      // Android reports 100–500; 400 and up are its high-quality voices.
      return quality >= 500 ? 2 : (quality >= 400 ? 1 : 0);
    }
    final text = '$quality ${voice['name']} ${voice['identifier']}'
        .toLowerCase();
    if (text.contains('premium')) return 2;
    if (text.contains('enhanced')) return 1;
    return 0;
  }

  /// Offline voices for [language], best first: the exact locale, then
  /// quality, then name.
  Future<List<Map>> _available(String language) async {
    final locale = language == 'zh' ? 'zh-CN' : 'en-US';
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
    available.sort((a, b) {
      final noveltyA = _isNovelty(a) ? 1 : 0;
      final noveltyB = _isNovelty(b) ? 1 : 0;
      if (noveltyA != noveltyB) return noveltyA.compareTo(noveltyB);
      final exactA = '${a['locale']}'.replaceAll('_', '-') == locale ? 0 : 1;
      final exactB = '${b['locale']}'.replaceAll('_', '-') == locale ? 0 : 1;
      if (exactA != exactB) return exactA.compareTo(exactB);
      final quality = _quality(b).compareTo(_quality(a));
      return quality != 0 ? quality : '${a['name']}'.compareTo('${b['name']}');
    });
    return available;
  }

  Future<String?> _preferred(String language) async =>
      (await audio.store.get('settings', 'systemVoice'))?[language] as String?;

  @override
  Future<List<SystemVoice>> voices(String language) async {
    await _initialize();
    final available = await _available(language);
    final preferred = await _preferred(language);
    final inUse =
        available.where((v) => v['name'] == preferred).firstOrNull?['name'] ??
        available.firstOrNull?['name'];
    return [
      for (final voice in available)
        SystemVoice(
          name: '${voice['name']}',
          locale: '${voice['locale']}',
          quality: _quality(voice),
          selected: voice['name'] == inUse,
        ),
    ];
  }

  @override
  Future<void> choose(String language, String? name) async {
    final json = {...?await audio.store.get('settings', 'systemVoice')};
    if (name == null) {
      json.remove(language);
    } else {
      json[language] = name;
    }
    await audio.store.put('settings', 'systemVoice', json);
  }

  @override
  Future<void> preview(String language, String name) async {
    await _initialize();
    final voice = (await _available(
      language,
    )).where((v) => v['name'] == name).firstOrNull;
    if (voice == null) return;
    await _tts.stop();
    await _tts.setLanguage('${voice['locale']}');
    await _tts.setVoice({'name': name, 'locale': '${voice['locale']}'});
    await _tts.speak(
      language == 'zh' ? '这是用这个声音朗读的效果。' : 'This is how this voice reads.',
    );
  }

  Future<String> _render(String bookId, String text, String language) async {
    await _initialize();
    final locale = language == 'zh' ? 'zh-CN' : 'en-US';
    if (await _tts.isLanguageAvailable(locale) != true) {
      throw const SpeechUnavailable();
    }
    final available = await _available(language);
    if (available.isEmpty) throw const SpeechUnavailable();
    final preferred = await _preferred(language);
    final voice =
        available.where((v) => v['name'] == preferred).firstOrNull ??
        available.first;
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
