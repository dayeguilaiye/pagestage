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
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
  });
  final String path;
  final Duration duration;
  final int? characters;
  final int requests;
  final Duration elapsed;
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;
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
    int? characters = 0;
    var requests = 0;
    int? inputTokens, outputTokens, totalTokens;
    int? sampleRate;
    for (final line in script.lines) {
      final binding = voices[line.direction.speakerId];
      if (binding == null) throw StateError('A speaker has no voice binding.');
      final adapter = adapters[binding.provider];
      if (adapter == null) {
        throw StateError('The voice provider is not configured.');
      }
      final capabilities = adapter.capabilitiesFor(binding);
      if (capabilities.maxCharacters < 1) {
        throw StateError('The provider request limit must be positive.');
      }
      var firstInLine = true;
      for (final text in _sourceChunks(
        line.textIn(chapter.text),
        capabilities.maxCharacters,
      )) {
        final result = await adapter.synthesize(
          TtsRequest(
            text: text,
            language: language,
            binding: binding,
            direction: line.direction,
          ),
        );
        sampleRate ??= result.audio.sampleRate;
        if (sampleRate != result.audio.sampleRate) {
          throw StateError('Audio sample rates must match.');
        }
        if (requests > 0 && firstInLine) {
          samples.addAll(
            List.filled(
              sampleRate * paragraphPause.inMicroseconds ~/ 1000000,
              0,
            ),
          );
        }
        firstInLine = false;
        samples.addAll(result.audio.samples);
        characters = characters == null || result.characters == null
            ? null
            : characters + result.characters!;
        inputTokens = _addReported(inputTokens, result.inputTokens);
        outputTokens = _addReported(outputTokens, result.outputTokens);
        totalTokens = _addReported(totalTokens, result.totalTokens);
        requests++;
      }
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
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
    );
  }
}

int? _addReported(int? total, int? value) =>
    value == null ? total : (total ?? 0) + value;

Iterable<String> _sourceChunks(String text, int limit) sync* {
  final runes = text.runes.toList();
  const sentenceEnds = {0x2e, 0x21, 0x3f, 0x3b, 0x3002, 0xff01, 0xff1f, 0xff1b};
  const closingMarks = {
    0x22,
    0x27,
    0x29,
    0x5d,
    0x2019,
    0x201d,
    0x3009,
    0x300b,
    0x300d,
    0x300f,
  };
  bool whitespace(int rune) => String.fromCharCode(rune).trim().isEmpty;
  for (var start = 0; start < runes.length;) {
    final hardEnd = (start + limit).clamp(0, runes.length);
    var end = hardEnd;
    if (hardEnd < runes.length) {
      int? sentenceEnd;
      int? wordEnd;
      for (var i = start; i < hardEnd; i++) {
        if (sentenceEnds.contains(runes[i])) sentenceEnd = i + 1;
        if (whitespace(runes[i])) wordEnd = i + 1;
      }
      if (sentenceEnd != null) {
        end = sentenceEnd;
        while (end < hardEnd &&
            (closingMarks.contains(runes[end]) || whitespace(runes[end]))) {
          end++;
        }
      } else if (wordEnd != null &&
          runes.sublist(start, wordEnd).any((rune) => !whitespace(rune))) {
        end = wordEnd;
      }
    }
    yield String.fromCharCodes(runes.sublist(start, end));
    start = end;
  }
}
