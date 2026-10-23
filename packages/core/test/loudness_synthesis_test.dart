import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('loudness-'));
  tearDown(() => temp.delete(recursive: true));

  test(
    'calibrates 997 Hz mono and gives different providers a common loudness',
    () async {
      const chapter = Chapter(number: 1, title: 'I', text: 'A.B.');
      final result =
          await Synthesizer(
            adapters: {
              'minimax': _Tts('minimax', (_) => _tone(0.1)),
              'bailian': _Tts('bailian', (_) => _tone(0.2)),
            },
          ).synthesize(
            chapter: chapter,
            script: _script(chapter, [
              const ScriptLine(
                start: 0,
                end: 2,
                direction: Direction(speakerId: 'narrator'),
              ),
              const ScriptLine(
                start: 2,
                end: 4,
                direction: Direction(speakerId: 'other'),
              ),
            ]),
            language: 'en',
            voices: const {
              'narrator': VoiceBinding(
                provider: 'minimax',
                model: 'fake',
                voiceId: 'one',
              ),
              'other': VoiceBinding(
                provider: 'bailian',
                model: 'fake',
                voiceId: 'two',
              ),
            },
            outputPath: '${temp.path}/chapter.wav',
          );
      final first = result.utterances.first;
      final second = result.utterances.last;
      // ITU-R BS.1770 mono 997 Hz calibration: -3.01 LKFS at full-scale peak.
      expect(first.loudness.inputLufs, closeTo(-23.01, 0.1));
      expect(second.loudness.inputLufs, closeTo(-16.99, 0.1));
      expect(first.loudness.estimatedOutputLufs, closeTo(-20, 0.001));
      expect(second.loudness.estimatedOutputLufs, closeTo(-20, 0.001));
      expect(first.loudness.measurement, LoudnessMeasurement.integrated);
      expect(first.audioPath, isNot(first.rawAudioPath));
      final a = await _read(first.audioPath);
      final b = await _read(second.audioPath);
      expect(a.samples.length, 240000);
      expect(
        List.generate(
          a.samples.length,
          (i) => (a.samples[i] - b.samples[i]).abs(),
        ).reduce(math.max),
        lessThanOrEqualTo(2),
      );
      final chapterAudio = await _read(result.path);
      expect(chapterAudio.samples.take(a.samples.length), a.samples);
      expect((await _read(first.rawAudioPath)).samples, _tone(0.1).samples);
    },
  );
  test(
    'relative gating excludes quiet sections from the integrated level',
    () async {
      // EBU Tech 3341 test 3 shape, adapted to one mono channel:
      // 10 s / 60 s / 10 s, sine peak levels -36 / -23 / -36 dBFS.
      final quiet = _tone(0.015848931924611134);
      final loud = _tone(0.0707945784384138, milliseconds: 60000);
      final input = PcmAudio(
        samples: Int16List.fromList([
          ...quiet.samples,
          ...loud.samples,
          ...quiet.samples,
        ]),
      );
      final result = await _single(temp, input);
      expect(result.utterances.single.loudness.inputLufs, closeTo(-26.01, 0.2));
    },
  );

  test(
    'sample-peak ceiling limits gain instead of clipping an impulse',
    () async {
      final samples = _tone(0.01).samples;
      samples[120000] = 32767;
      final result = await _single(temp, PcmAudio(samples: samples));
      final utterance = result.utterances.single;
      final audio = await _read(utterance.audioPath);
      expect(
        audio.samples.map((s) => s.abs()).reduce(math.max),
        lessThanOrEqualTo(29204),
      );
      expect(utterance.loudness.peakLimited, isTrue);
      expect(utterance.loudness.estimatedOutputLufs, lessThan(-20));
      expect((await _read(utterance.rawAudioPath)).samples[120000], 32767);
    },
  );

  test(
    'short interjections use a labelled estimate without adding padding',
    () async {
      final result = await _single(temp, _tone(0.1, milliseconds: 100));
      final utterance = result.utterances.single;
      expect(
        utterance.loudness.measurement,
        LoudnessMeasurement.shortClipEstimate,
      );
      expect(utterance.loudness.inputLufs, closeTo(-23.01, 0.2));
      expect(utterance.loudness.estimatedOutputLufs, closeTo(-20, 0.001));
      expect((await _read(utterance.audioPath)).samples.length, 2400);
      expect(result.duration, const Duration(milliseconds: 100));
    },
  );

  test(
    'silence and below-gate noise remain unchanged while boost is capped',
    () async {
      for (final input in [
        PcmAudio(samples: Int16List(0)),
        PcmAudio(samples: Int16List(720000)),
        _tone(0.00003),
      ]) {
        final directory = await temp.createTemp('case-');
        final result = await _single(directory, input);
        final utterance = result.utterances.single;
        expect(
          utterance.loudness.measurement,
          LoudnessMeasurement.unmeasurable,
        );
        expect(utterance.loudness.inputLufs, isNull);
        expect(utterance.loudness.gainDb, 0);
        expect((await _read(utterance.audioPath)).samples, input.samples);
      }
      final directory = await temp.createTemp('quiet-');
      final quiet = await _single(directory, _tone(0.001));
      expect(quiet.utterances.single.loudness.boostLimited, isTrue);
      expect(quiet.utterances.single.loudness.gainDb, closeTo(12, 0.0001));
    },
  );

  for (final fixture in [
    (100.0, -24.79155),
    (1000.0, -22.97774),
    (4000.0, -19.67392),
  ]) {
    test('K weighting matches independent ${fixture.$1} Hz response', () async {
      final result = await _single(temp, _tone(0.1, frequency: fixture.$1));
      expect(
        result.utterances.single.loudness.inputLufs,
        closeTo(fixture.$2, 0.1),
      );
    });
  }

  test(
    'joins provider chunks before gain and reprocesses raw cache for new settings',
    () async {
      const chapter = Chapter(number: 1, title: 'I', text: 'AB');
      final a = _tone(0.05, milliseconds: 100);
      final b = _tone(0.2, milliseconds: 100);
      final adapter = _Tts('fake', (r) => r.text == 'A' ? a : b, limit: 1);
      Future<SynthesisResult> run(LoudnessSettings settings) =>
          Synthesizer(adapters: {'fake': adapter}).synthesize(
            chapter: chapter,
            script: Script.narration(bookId: 'book', chapter: chapter),
            language: 'en',
            voices: const {
              'narrator': VoiceBinding(
                provider: 'fake',
                model: 'fake',
                voiceId: 'voice',
              ),
            },
            outputPath: '${temp.path}/chapter.wav',
            loudness: settings,
          );
      final first = await run(const LoudnessSettings());
      expect(first.requests, 2);
      final utterance = first.utterances.single;
      final audio = await _read(utterance.audioPath);
      expect(audio.samples.length, 4800);
      // One gain preserves the provider chunks' 4:1 amplitude relation.
      expect(audio.samples[2406] / audio.samples[6], closeTo(4, 0.002));
      final raw = await File(utterance.rawAudioPath).readAsBytes();
      final replay = await run(const LoudnessSettings());
      expect(replay.requests, 0);
      expect(
        (await _read(replay.utterances.single.audioPath)).samples,
        audio.samples,
      );
      final quieter = await run(const LoudnessSettings(targetLufs: -26));
      expect(quieter.requests, 0);
      expect(quieter.utterances.single.audioPath, isNot(utterance.audioPath));
      expect(
        quieter.utterances.single.loudness.estimatedOutputLufs,
        closeTo(-26, 0.0001),
      );
      expect(await File(utterance.rawAudioPath).readAsBytes(), raw);
      await File(utterance.audioPath).writeAsString('broken normalized output');
      final repaired = await run(const LoudnessSettings());
      expect(repaired.requests, 0);
      expect(
        (await _read(repaired.utterances.single.audioPath)).samples,
        audio.samples,
      );
    },
  );
}

PcmAudio _tone(
  double amplitude, {
  int milliseconds = 10000,
  double frequency = 997,
}) => PcmAudio(
  samples: Int16List.fromList(
    List.generate(
      milliseconds * 24,
      (i) => (32768 * amplitude * math.sin(2 * math.pi * frequency * i / 24000))
          .round(),
    ),
  ),
);
Future<PcmAudio> _read(String path) async =>
    PcmAudio.fromWav(await File(path).readAsBytes());
Script _script(Chapter chapter, List<ScriptLine> lines) => Script(
  bookId: 'book',
  chapterNumber: 1,
  sourceTextHash: chapter.textHash,
  model: 'fake',
  promptVersion: 'test',
  lines: lines,
);

class _Tts implements TtsAdapter {
  _Tts(this.provider, this.audio, {this.limit = 9999});
  @override
  final String provider;
  final PcmAudio Function(TtsRequest) audio;
  final int limit;
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) => TtsCapabilities(
    supportsVoiceDesign: false,
    emotionControl: EmotionControl.none,
    supportsPronunciation: true,
    returnsTimestamps: false,
    maxCharacters: limit,
  );
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async =>
      TtsAudio(audio: audio(request), characters: request.text.runes.length);
}

Future<SynthesisResult> _single(
  Directory temp,
  PcmAudio audio, {
  LoudnessSettings loudness = const LoudnessSettings(),
}) {
  const chapter = Chapter(number: 1, title: 'I', text: 'A.');
  return Synthesizer(adapters: {'fake': _Tts('fake', (_) => audio)}).synthesize(
    chapter: chapter,
    script: Script.narration(bookId: 'book', chapter: chapter),
    language: 'en',
    loudness: loudness,
    voices: const {
      'narrator': VoiceBinding(
        provider: 'fake',
        model: 'fake',
        voiceId: 'voice',
      ),
    },
    outputPath: '${temp.path}/chapter.wav',
  );
}
