import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'models/book.dart';
import 'models/script.dart';
import 'models/voice.dart';
import 'pcm_audio.dart';
import 'providers/tts_adapter.dart';

enum PerformanceMode { audiobook, drama }

class SynthesizedUtterance {
  const SynthesizedUtterance({
    required this.start,
    required this.end,
    required this.lineIndices,
    required this.speakerId,
    required this.audioPath,
    required this.cacheKey,
    required this.cacheHit,
    required this.duration,
    required this.pauseBefore,
  });
  final int start;
  final int end;
  final List<int> lineIndices;
  final String speakerId;
  final String audioPath;
  final String cacheKey;
  final bool cacheHit;
  final Duration duration;
  final Duration pauseBefore;
}

class SynthesisResult {
  const SynthesisResult({
    required this.path,
    required this.duration,
    required this.characters,
    required this.requests,
    required this.elapsed,
    this.utterances = const [],
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
  });
  final String path;
  final Duration duration;
  final int? characters;
  final int requests;
  final Duration elapsed;
  final List<SynthesizedUtterance> utterances;
  int get cacheHits => utterances.where((item) => item.cacheHit).length;
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;
}

class Synthesizer {
  Synthesizer({required Map<String, TtsAdapter> adapters, this.cacheDirectory})
    : adapters = Map.unmodifiable(adapters);
  final Map<String, TtsAdapter> adapters;
  final Directory? cacheDirectory;

  Future<SynthesisResult> synthesize({
    required Chapter chapter,
    required Script script,
    required String language,
    required Map<String, VoiceBinding> voices,
    required String outputPath,
    PerformanceMode mode = PerformanceMode.audiobook,
    bool mergeAdjacentNarrator = false,
    Duration paragraphPause = const Duration(milliseconds: 300),
    Duration sameSpeakerPause = const Duration(milliseconds: 100),
    Duration speakerSwitchPause = const Duration(milliseconds: 180),
  }) async {
    if (script.chapterNumber != chapter.number ||
        script.sourceTextHash != chapter.textHash) {
      throw StateError('The script does not match the chapter text.');
    }
    for (final pause in [
      paragraphPause,
      sameSpeakerPause,
      speakerSwitchPause,
    ]) {
      if (pause.isNegative) throw ArgumentError.value(pause, 'pause');
    }
    _validateRanges(chapter.text, script);
    final stopwatch = Stopwatch()..start();
    final samples = <int>[];
    final utterances = <SynthesizedUtterance>[];
    int? characters = 0;
    var requests = 0;
    int? inputTokens, outputTokens, totalTokens;
    int? sampleRate;
    ScriptLine? previous;
    final plan = _utterances(chapter.text, script, mode, mergeAdjacentNarrator);
    // Validate every audible voice before the first potentially paid request.
    for (final entry in plan) {
      final binding = voices[entry.line.direction.speakerId];
      if (binding == null) throw StateError('A speaker has no voice binding.');
      final adapter = adapters[binding.provider];
      if (adapter == null) {
        throw StateError('The voice provider is not configured.');
      }
      if (adapter.capabilitiesFor(binding).maxCharacters < 1) {
        throw StateError('The provider request limit must be positive.');
      }
    }
    for (final entry in plan) {
      final line = entry.line;
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
      final text = line.textIn(chapter.text);
      final cacheKey = sha256
          .convert(
            utf8.encode(
              jsonEncode(
                _canonical({
                  'version': 'tts-raw-v1',
                  'text': text,
                  'language': language,
                  'binding': binding.toJson(),
                  'direction': line.direction.toJson(),
                }),
              ),
            ),
          )
          .toString();
      final cacheFile = File(
        '${cacheDirectory?.path ?? '${File(outputPath).parent.path}/.utterances'}/$cacheKey.wav',
      );
      var raw = await _readCache(cacheFile);
      final cacheHit = raw != null;
      if (raw == null) {
        final utteranceSamples = <int>[];
        int? utteranceRate;
        for (final chunk in _sourceChunks(text, capabilities.maxCharacters)) {
          final result = await adapter.synthesize(
            TtsRequest.forCapabilities(
              text: chunk,
              language: language,
              binding: binding,
              direction: line.direction,
              capabilities: capabilities,
            ),
          );
          utteranceRate ??= result.audio.sampleRate;
          if (utteranceRate != result.audio.sampleRate) {
            throw StateError('Audio sample rates must match.');
          }
          utteranceSamples.addAll(result.audio.samples);
          characters = characters == null || result.characters == null
              ? null
              : characters + result.characters!;
          inputTokens = _addReported(inputTokens, result.inputTokens);
          outputTokens = _addReported(outputTokens, result.outputTokens);
          totalTokens = _addReported(totalTokens, result.totalTokens);
          requests++;
        }
        raw = PcmAudio(
          samples: Int16List.fromList(utteranceSamples),
          sampleRate: utteranceRate ?? 24000,
        );
        await _writeCache(cacheFile, raw);
      }
      sampleRate ??= raw.sampleRate;
      if (sampleRate != raw.sampleRate) {
        throw StateError('Audio sample rates must match.');
      }
      final pause = previous == null
          ? Duration.zero
          : _pauseBefore(
              chapter.text,
              previous,
              line,
              paragraphPause,
              sameSpeakerPause,
              speakerSwitchPause,
            );
      samples.addAll(
        List.filled(sampleRate * pause.inMicroseconds ~/ 1000000, 0),
      );
      samples.addAll(raw.samples);
      utterances.add(
        SynthesizedUtterance(
          start: line.start,
          end: line.end,
          lineIndices: List.unmodifiable(entry.indices),
          speakerId: line.direction.speakerId,
          audioPath: cacheFile.absolute.path,
          cacheKey: cacheKey,
          cacheHit: cacheHit,
          duration: raw.duration,
          pauseBefore: pause,
        ),
      );
      previous = line;
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
      utterances: List.unmodifiable(utterances),
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: totalTokens,
    );
  }
}

void _validateRanges(String source, Script script) {
  var end = 0;
  for (final line in script.lines) {
    if (line.start != end ||
        line.end <= line.start ||
        line.end > source.length) {
      throw StateError(
        'Script lines must cover the original chapter in order.',
      );
    }
    if (line.end < source.length &&
        source.codeUnitAt(line.end) >= 0xdc00 &&
        source.codeUnitAt(line.end) <= 0xdfff &&
        source.codeUnitAt(line.end - 1) >= 0xd800 &&
        source.codeUnitAt(line.end - 1) <= 0xdbff) {
      throw StateError(
        'Script lines must preserve complete Unicode characters.',
      );
    }
    end = line.end;
  }
  if (end != source.length &&
      !(script.lines.isEmpty && source.trim().isEmpty)) {
    throw StateError('Script lines must cover the original chapter in order.');
  }
}

class _PlannedUtterance {
  _PlannedUtterance(this.line, this.indices);
  ScriptLine line;
  final List<int> indices;
}

List<_PlannedUtterance> _utterances(
  String source,
  Script script,
  PerformanceMode mode,
  bool mergeNarrator,
) {
  final result = <_PlannedUtterance>[];
  for (var index = 0; index < script.lines.length; index++) {
    final line = script.lines[index];
    if (line.isNonStory ||
        (mode == PerformanceMode.drama && line.isDialogueTag) ||
        line.textIn(source).trim().isEmpty) {
      continue;
    }
    final previous = result.isEmpty ? null : result.last;
    if (mergeNarrator &&
        previous != null &&
        previous.indices.last == index - 1 &&
        previous.line.end == line.start &&
        line.direction.speakerId == 'narrator' &&
        jsonEncode(previous.line.direction.toJson()) ==
            jsonEncode(line.direction.toJson())) {
      previous.line = ScriptLine(
        start: previous.line.start,
        end: line.end,
        direction: line.direction,
      );
      previous.indices.add(index);
    } else {
      result.add(_PlannedUtterance(line, [index]));
    }
  }
  return result;
}

// Cache joined raw utterances. Chapter pauses and future mastering are separate.
Future<PcmAudio?> _readCache(File file) async {
  try {
    return PcmAudio.fromWav(await file.readAsBytes());
  } on FileSystemException {
    return null;
  } on FormatException {
    return null;
  }
}

Future<void> _writeCache(File file, PcmAudio audio) async {
  await file.parent.create(recursive: true);
  final temporary = await file.parent.createTemp('.write-');
  // A unique staging filename in the cache directory keeps rename atomic.
  final staging = File('${temporary.path}/utterance.wav');
  try {
    await staging.writeAsBytes(audio.toWav(), flush: true);
    await staging.rename(file.path);
  } finally {
    if (await staging.exists()) await staging.delete();
    await temporary.delete();
  }
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

Duration _pauseBefore(
  String source,
  ScriptLine previous,
  ScriptLine next,
  Duration paragraph,
  Duration sameSpeaker,
  Duration switched,
) {
  final previousText = previous.textIn(source);
  final nextText = next.textIn(source);
  final gap = source.substring(
    previous.start + previousText.trimRight().length,
    next.end - nextText.trimLeft().length,
  );
  if (gap.contains(RegExp(r'[\r\n]'))) return paragraph;
  return previous.direction.speakerId == next.direction.speakerId
      ? sameSpeaker
      : switched;
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
