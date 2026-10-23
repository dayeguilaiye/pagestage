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
      expect(data.getInt16(44, Endian.little), 1000);
      expect(data.getInt16(44 + 240 * 2, Endian.little), 0);
      expect(data.getInt16(44 + 7440 * 2, Endian.little), 2000);
    },
  );
}

class _FakeTts implements TtsAdapter {
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
