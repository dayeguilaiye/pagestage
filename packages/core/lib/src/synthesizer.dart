import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'delivery.dart';
import 'models/book.dart';
import 'models/loudness.dart';
import 'audio/loudness.dart';
import 'models/cast.dart';
import 'pronunciation.dart';
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
    required this.rawAudioPath,
    required this.loudness,
    required this.cacheKey,
    required this.cacheHit,
    required this.duration,
    required this.pauseBefore,
    this.pronunciationApplied = false,
    this.pronunciationWarning,
  });
  final int start;
  final int end;
  final List<int> lineIndices;
  final String speakerId;
  final String audioPath;
  final String rawAudioPath;
  final LoudnessReport loudness;
  final String cacheKey;
  final bool cacheHit;
  final Duration duration;
  final Duration pauseBefore;
  final bool pronunciationApplied;
  final String? pronunciationWarning;

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'lineIndices': lineIndices,
    'speakerId': speakerId,
    'audioPath': audioPath,
    'rawAudioPath': rawAudioPath,
    'loudness': loudness.toJson(),
    'cacheKey': cacheKey,
    'cacheHit': cacheHit,
    'durationUs': duration.inMicroseconds,
    'pauseBeforeUs': pauseBefore.inMicroseconds,
    'pronunciationApplied': pronunciationApplied,
    'pronunciationWarning': pronunciationWarning,
  };

  factory SynthesizedUtterance.fromJson(Map<String, Object?> json) =>
      SynthesizedUtterance(
        start: json['start'] as int,
        end: json['end'] as int,
        lineIndices: (json['lineIndices'] as List).cast<int>(),
        speakerId: json['speakerId'] as String,
        audioPath: json['audioPath'] as String,
        rawAudioPath: json['rawAudioPath'] as String,
        loudness: LoudnessReport.fromJson(
          Map<String, Object?>.from(json['loudness'] as Map),
        ),
        cacheKey: json['cacheKey'] as String,
        cacheHit: json['cacheHit'] as bool,
        duration: Duration(microseconds: json['durationUs'] as int),
        pauseBefore: Duration(microseconds: json['pauseBeforeUs'] as int),
        pronunciationApplied: json['pronunciationApplied'] as bool? ?? false,
        pronunciationWarning: json['pronunciationWarning'] as String?,
      );
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
  Synthesizer({
    required Map<String, TtsAdapter> adapters,
    this.cacheDirectory,
    this.fallbackCacheDirectory,
  }) : adapters = Map.unmodifiable(adapters);
  final Map<String, TtsAdapter> adapters;
  final Directory? cacheDirectory;

  /// Read-only migration source for previously shared CLI caches.
  final Directory? fallbackCacheDirectory;

  // Advance when request semantics or an adapter's wire mapping changes.
  // Audio is keyed by the lowered delivery, so direction a voice cannot
  // perform never splits its cache.
  static const _cacheVersion = 'tts-raw-v4-delivery-v1';

  Future<SynthesisResult> synthesize({
    required Chapter chapter,
    required Script script,
    required String language,
    required Map<String, VoiceBinding> voices,
    required String outputPath,
    List<PronunciationEntry> lexicon = const [],
    LoudnessSettings loudness = const LoudnessSettings(),
    PerformanceMode mode = PerformanceMode.audiobook,
    Expressiveness expressiveness = Expressiveness.natural,
    bool mergeAdjacentNarrator = false,
    Duration paragraphPause = const Duration(milliseconds: 300),
    Duration sameSpeakerPause = const Duration(milliseconds: 100),
    Duration speakerSwitchPause = const Duration(milliseconds: 180),
    FutureOr<void> Function(SynthesizedUtterance utterance)? onUtterance,
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
    if (!loudness.targetLufs.isFinite ||
        loudness.targetLufs <= -70 ||
        loudness.targetLufs > 0 ||
        !loudness.maxBoostDb.isFinite ||
        loudness.maxBoostDb < 0 ||
        loudness.maxBoostDb > 60 ||
        !loudness.samplePeakDbfs.isFinite ||
        loudness.samplePeakDbfs < -60 ||
        loudness.samplePeakDbfs > 0) {
      throw ArgumentError(
        'Invalid loudness target, boost or sample-peak ceiling.',
      );
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
    // Prepare all effective requests before the first potentially paid call.
    final prepared = <_PreparedUtterance>[];
    for (final entry in plan) {
      final binding = voices[entry.line.direction.speakerId];
      if (binding == null) throw StateError('A speaker has no voice binding.');
      final adapter = adapters[binding.provider];
      if (adapter == null) {
        throw StateError('The voice provider is not configured.');
      }
      final capabilities = adapter.capabilitiesFor(binding);
      if (capabilities.maxCharacters < 1) {
        throw StateError('The provider request limit must be positive.');
      }
      final text = entry.line.textIn(chapter.text);
      final matches = language == 'zh'
          ? pronunciationMatches(text, lexicon)
          : <PronunciationMatch>[];
      final effectiveMatches = capabilities.supportsPronunciation
          ? matches
          : <PronunciationMatch>[];
      final pronunciations = matchedPronunciations(effectiveMatches);
      final delivery = Delivery.lower(
        entry.line.direction,
        capabilities,
        expressiveness: expressiveness,
      );
      final chunks = _sourceChunks(
        text,
        capabilities.maxCharacters,
        effectiveMatches,
      ).toList();
      final requests = <TtsRequest>[];
      var offset = 0;
      for (final (index, chunk) in chunks.indexed) {
        final end = offset + chunk.length;
        final chunkDelivery = delivery.chunk(
          offset,
          end,
          last: index == chunks.length - 1,
        );
        offset = end;
        // Blank source still occupies script offsets. Only send it to a
        // voice when the director placed a supported vocal cue there.
        if (chunk.trim().isEmpty && chunkDelivery.cues.isEmpty) continue;
        requests.add(
          TtsRequest(
            text: chunk,
            language: language,
            binding: binding,
            delivery: chunkDelivery,
            pronunciations: List.unmodifiable(
              matchedPronunciations(
                pronunciationMatches(chunk, pronunciations),
              ),
            ),
          ),
        );
      }
      prepared.add(
        _PreparedUtterance(
          entry,
          adapter,
          requests,
          capabilities.pairedSynthesis && adapter is PairedTtsAdapter,
          matches.isNotEmpty && !capabilities.supportsPronunciation
              ? 'Selected voice does not support pronunciation; synthesized plain text.'
              : null,
        ),
      );
    }
    String keyFor(_PreparedUtterance item) {
      return sha256
          .convert(
            utf8.encode(
              jsonEncode(
                _canonical({
                  'version': _cacheVersion,
                  'requests': [
                    for (final request in item.requests)
                      {
                        'text': request.text,
                        'language': request.language,
                        'binding': request.binding.toJson(),
                        'delivery': request.delivery.toJson(),
                        'pronunciations': request.pronunciations
                            .map((e) => e.toJson())
                            .toList(),
                      },
                  ],
                }),
              ),
            ),
          )
          .toString();
    }

    File fileFor(String cacheKey) => File(
      '${cacheDirectory?.path ?? '${File(outputPath).parent.path}/.utterances'}/$cacheKey.wav',
    );

    TtsAudio? firstOfNext;
    for (var index = 0; index < prepared.length; index++) {
      final item = prepared[index];
      final entry = item.entry;
      final line = entry.line;
      final cacheKey = keyFor(item);
      final cacheFile = fileFor(cacheKey);
      final carried = firstOfNext;
      firstOfNext = null;
      var raw = await _readCache(cacheFile);
      if (raw == null && fallbackCacheDirectory != null) {
        raw = await _readCache(
          File('${fallbackCacheDirectory!.path}/$cacheKey.wav'),
        );
        if (raw != null) await _writeCache(cacheFile, raw);
      }
      final cacheHit = raw != null;
      if (raw == null) {
        final utteranceSamples = <int>[];
        int? utteranceRate;
        void collect(TtsAudio result) {
          utteranceRate ??= result.audio.sampleRate;
          if (utteranceRate != result.audio.sampleRate) {
            throw StateError('Audio sample rates must match.');
          }
          utteranceSamples.addAll(result.audio.samples);
          characters = characters == null || result.characters == null
              ? null
              : characters! + result.characters!;
          inputTokens = _addReported(inputTokens, result.inputTokens);
          outputTokens = _addReported(outputTokens, result.outputTokens);
          totalTokens = _addReported(totalTokens, result.totalTokens);
          requests++;
        }

        final adapter = item.adapter;
        final pair = item.canPair ? adapter as PairedTtsAdapter : null;
        if (carried != null) collect(carried);
        var cursor = carried == null ? 0 : 1;
        while (cursor < item.requests.length) {
          final request = item.requests[cursor++];
          if (pair != null && cursor < item.requests.length) {
            final (first, second) = await pair.synthesizePair(
              request,
              item.requests[cursor++],
            );
            collect(first);
            collect(second);
            continue;
          }
          if (pair != null && index + 1 < prepared.length) {
            final next = prepared[index + 1];
            if (identical(next.adapter, adapter) &&
                next.requests.isNotEmpty &&
                next.canPair) {
              final nextKey = keyFor(next);
              final legacy = fallbackCacheDirectory;
              if (nextKey != cacheKey &&
                  !await fileFor(nextKey).exists() &&
                  (legacy == null ||
                      !await File('${legacy.path}/$nextKey.wav').exists())) {
                final (first, second) = await pair.synthesizePair(
                  request,
                  next.requests.first,
                );
                collect(first);
                firstOfNext = second;
                continue;
              }
            }
          }
          collect(await adapter.synthesize(request));
        }
        raw = PcmAudio(
          samples: Int16List.fromList(utteranceSamples),
          sampleRate: utteranceRate ?? 24000,
        );
        await _writeCache(cacheFile, raw);
      }
      sampleRate ??= raw.sampleRate;
      final normalized = normalizeLoudness(raw, loudness);
      final settingsKey = sha256
          .convert(utf8.encode(jsonEncode(_canonical(loudness.toJson()))))
          .toString();
      final normalizedFile = File(
        '${cacheFile.parent.path}/normalized/$cacheKey-$settingsKey.wav',
      );
      await _writeCache(normalizedFile, normalized.audio);
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
      samples.addAll(normalized.audio.atSampleRate(sampleRate).samples);
      utterances.add(
        SynthesizedUtterance(
          start: line.start,
          end: line.end,
          lineIndices: List.unmodifiable(entry.indices),
          speakerId: line.direction.speakerId,
          audioPath: normalizedFile.absolute.path,
          rawAudioPath: cacheFile.absolute.path,
          loudness: normalized.report,
          cacheKey: cacheKey,
          cacheHit: cacheHit,
          duration: raw.duration,
          pauseBefore: pause,
          pronunciationApplied: item.requests.any(
            (r) => r.pronunciations.isNotEmpty,
          ),
          pronunciationWarning: item.warning,
        ),
      );
      await onUtterance?.call(utterances.last);
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

class _PreparedUtterance {
  const _PreparedUtterance(
    this.entry,
    this.adapter,
    this.requests,
    this.canPair,
    this.warning,
  );
  final _PlannedUtterance entry;
  final TtsAdapter adapter;
  final List<TtsRequest> requests;
  final bool canPair;
  final String? warning;
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
        previous.line.direction.speakerId == 'narrator' &&
        // Notes are unique per line, so they cannot gate merging; the
        // merged block keeps the first line's note.
        previous.line.direction.emotion == line.direction.emotion &&
        previous.line.direction.intensity == line.direction.intensity &&
        previous.line.direction.pace == line.direction.pace &&
        previous.line.direction.volume == line.direction.volume &&
        // Cues belong at a particular position within their own line.
        previous.line.direction.cues.isEmpty &&
        line.direction.cues.isEmpty) {
      previous.line = ScriptLine(
        start: previous.line.start,
        end: line.end,
        direction: previous.line.direction,
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

Iterable<String> _sourceChunks(
  String text,
  int limit,
  List<PronunciationMatch> matches,
) sync* {
  final ranges = [
    for (final match in matches)
      (
        text.substring(0, match.start).runes.length,
        text.substring(0, match.end).runes.length,
      ),
  ];
  if (ranges.any((range) => range.$2 - range.$1 > limit)) {
    throw StateError(
      'A pronunciation term exceeds the provider request limit.',
    );
  }
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
    for (final range in ranges) {
      if (range.$1 < end && end < range.$2) {
        end = range.$1 > start ? range.$1 : range.$2;
        break;
      }
    }
    yield String.fromCharCodes(runes.sublist(start, end));
    start = end;
  }
}
