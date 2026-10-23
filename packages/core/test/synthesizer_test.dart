import 'dart:io';
import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'narrates the original chapter with silence between paragraphs',
    () async {
      final directory = await Directory.systemTemp.createTemp('pagestage-tts-');
      addTearDown(() => directory.delete(recursive: true));
      const chapter = Chapter(
        number: 1,
        title: '第一章',
        text: '\n风来了。\n\n他回家。\n',
      );
      final script = Script.narration(bookId: 'book', chapter: chapter);
      final tts = _FakeTts();
      final result = await Synthesizer(adapters: {'fake': tts}).synthesize(
        chapter: chapter,
        script: script,
        language: 'zh',
        voices: {
          'narrator': const VoiceBinding(
            provider: 'fake',
            model: 'fake-model',
            voiceId: 'voice',
          ),
        },
        outputPath: '${directory.path}/chapter.wav',
      );
      expect(tts.requests.map((r) => r.text).toList(), [
        '\n风来了。\n\n',
        '他回家。\n',
      ]);
      expect(tts.requests.map((r) => r.direction.speakerId).toSet(), {
        'narrator',
      });
      expect(result.duration, const Duration(milliseconds: 320));
      expect(result.characters, 12);
      final bytes = await File(result.path).readAsBytes();
      final data = ByteData.sublistView(bytes);
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(data.getUint32(24, Endian.little), 24000);
      expect(data.getUint32(40, Endian.little), 15360);
      final first = PcmAudio.fromWav(
        await File(result.utterances.first.audioPath).readAsBytes(),
      );
      final last = PcmAudio.fromWav(
        await File(result.utterances.last.audioPath).readAsBytes(),
      );
      expect(data.getInt16(44, Endian.little), first.samples.first);
      expect(
        PcmAudio.fromWav(
          await File(result.utterances.first.rawAudioPath).readAsBytes(),
        ).samples.first,
        1000,
      );
      expect(data.getInt16(44 + 240 * 2, Endian.little), 0);
      expect(data.getInt16(44 + 7440 * 2, Endian.little), last.samples.first);
    },
  );
  for (final provider in ['minimax', 'bailian']) {
    test(
      'splits long $provider text at its declared limit without chunk pauses',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'pagestage-chunks-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final limit = provider == 'minimax' ? 9999 : 600;
        final prefix = '${'文' * (limit - 2)}𠀀。';
        final chapter = Chapter(number: 1, title: '章', text: '$prefix尾句。\n再见。');
        final tts = _LimitedTts(provider, limit);
        final result = await Synthesizer(adapters: {provider: tts}).synthesize(
          chapter: chapter,
          script: Script.narration(bookId: 'book', chapter: chapter),
          language: 'zh',
          voices: {
            'narrator': VoiceBinding(
              provider: provider,
              model: 'fake',
              voiceId: 'voice',
            ),
          },
          outputPath: '${directory.path}/chapter.wav',
        );
        expect(tts.requests.map((r) => r.text), [prefix, '尾句。\n', '再见。']);
        expect(result.duration, const Duration(milliseconds: 330));
        expect(result.requests, 3);
        expect(result.inputTokens, 6);
        expect(result.outputTokens, 9);
        expect(result.totalTokens, 15);
        final data = ByteData.sublistView(
          await File(result.path).readAsBytes(),
        );
        final first = PcmAudio.fromWav(
          await File(result.utterances.first.audioPath).readAsBytes(),
        );
        final last = PcmAudio.fromWav(
          await File(result.utterances.last.audioPath).readAsBytes(),
        );
        expect(data.getInt16(44 + 240 * 2, Endian.little), first.samples[240]);
        expect(
          PcmAudio.fromWav(
            await File(result.utterances.first.rawAudioPath).readAsBytes(),
          ).samples[240],
          2000,
        );
        expect(data.getInt16(44 + 480 * 2, Endian.little), 0);
        expect(data.getInt16(44 + 7680 * 2, Endian.little), last.samples.first);
      },
    );
  }
  test(
    'prefers a sentence boundary and preserves every original character',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pagestage-sentences-',
      );
      addTearDown(() => directory.delete(recursive: true));
      const chapter = Chapter(
        number: 1,
        title: 'Chapter I.',
        text: 'First. Nextpart.',
      );
      final tts = _LimitedTts('fake', 10);
      final result = await Synthesizer(adapters: {'fake': tts}).synthesize(
        chapter: chapter,
        script: Script.narration(bookId: 'book', chapter: chapter),
        language: 'en',
        voices: {
          'narrator': const VoiceBinding(
            provider: 'fake',
            model: 'fake',
            voiceId: 'voice',
          ),
        },
        outputPath: '${directory.path}/chapter.wav',
      );
      expect(tts.requests.map((r) => r.text), ['First. ', 'Nextpart.']);
      expect(result.duration, const Duration(milliseconds: 20));
    },
  );
}

class _FakeTts implements TtsAdapter {
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) =>
      const TtsCapabilities(
        supportsVoiceDesign: false,
        emotionControl: EmotionControl.none,
        supportsPronunciation: false,
        returnsTimestamps: false,
        maxCharacters: 9999,
      );
  final requests = <TtsRequest>[];
  @override
  String get provider => 'fake';
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    requests.add(request);
    return TtsAudio(
      audio: PcmAudio(
        samples: Int16List.fromList(List.filled(240, requests.length * 1000)),
      ),
      characters: request.text.runes.length,
    );
  }
}

class _LimitedTts implements TtsAdapter {
  _LimitedTts(this.provider, this.limit);
  @override
  final String provider;
  final int limit;
  final requests = <TtsRequest>[];
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) => TtsCapabilities(
    supportsVoiceDesign: false,
    emotionControl: EmotionControl.none,
    supportsPronunciation: false,
    returnsTimestamps: false,
    maxCharacters: limit,
  );
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    if (request.text.runes.length > limit) {
      throw StateError('Source request exceeds provider limit.');
    }
    requests.add(request);
    return TtsAudio(
      audio: PcmAudio(
        samples: Int16List.fromList(List.filled(240, requests.length * 1000)),
      ),
      characters: request.text.runes.length,
      inputTokens: 2,
      outputTokens: 3,
      totalTokens: 5,
    );
  }
}
