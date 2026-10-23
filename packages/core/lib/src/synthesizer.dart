import 'dart:io';
import 'dart:typed_data';

import 'models/book.dart';
import 'models/script.dart';
import 'models/voice.dart';
import 'pcm_audio.dart';
import 'providers/tts_adapter.dart';

class SynthesisResult {
  const SynthesisResult({
    required this.path,
    required this.duration,
    required this.characters,
    required this.requests,
    required this.elapsed,
  });
  final String path;
  final Duration duration;
  final int characters;
  final int requests;
  final Duration elapsed;
}

class Synthesizer {
  Synthesizer({required Map<String, TtsAdapter> adapters})
    : adapters = Map.unmodifiable(adapters);
  final Map<String, TtsAdapter> adapters;

  Future<SynthesisResult> synthesize({
    required Chapter chapter,
    required Script script,
    required String language,
    required Map<String, VoiceBinding> voices,
    required String outputPath,
    Duration paragraphPause = const Duration(milliseconds: 300),
  }) async {
    if (script.chapterNumber != chapter.number ||
        script.sourceTextHash != chapter.textHash) {
      throw StateError('The script does not match the chapter text.');
    }
    if (paragraphPause.isNegative) {
      throw ArgumentError.value(paragraphPause, 'paragraphPause');
    }
    final stopwatch = Stopwatch()..start();
    final samples = <int>[];
    var characters = 0;
    var requests = 0;
    int? sampleRate;
    for (final line in script.lines) {
      final binding = voices[line.direction.speakerId];
      if (binding == null) throw StateError('A speaker has no voice binding.');
      final adapter = adapters[binding.provider];
      if (adapter == null) {
        throw StateError('The voice provider is not configured.');
      }
      final result = await adapter.synthesize(
        TtsRequest(
          text: line.textIn(chapter.text),
          language: language,
          binding: binding,
          direction: line.direction,
        ),
      );
      sampleRate ??= result.audio.sampleRate;
      if (sampleRate != result.audio.sampleRate) {
        throw StateError('Audio sample rates must match.');
      }
      if (requests > 0) {
        samples.addAll(
          List.filled(sampleRate * paragraphPause.inMicroseconds ~/ 1000000, 0),
        );
      }
      samples.addAll(result.audio.samples);
      characters += result.characters;
      requests++;
    }
    final audio = PcmAudio(
      samples: Int16List.fromList(samples),
      sampleRate: sampleRate ?? 24000,
    );
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(audio.toWav(), flush: true);
    return SynthesisResult(
      path: file.absolute.path,
      duration: audio.duration,
      characters: characters,
      requests: requests,
      elapsed: stopwatch.elapsed,
    );
  }
}
