import 'dart:io';
import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('pronounce-'));
  tearDown(() => temp.delete(recursive: true));

  test(
    'passes matching Chinese pronunciations without splitting a proper noun',
    () async {
      final tts = _Tts(limit: 4);
      const chapter = Chapter(number: 1, title: '章', text: '去找了长乐。');
      final result = await _run(
        temp,
        tts,
        chapter,
        lexicon: const [
          PronunciationEntry('长乐', 'cháng lè'),
          PronunciationEntry('长', 'zhǎng'),
          PronunciationEntry('重庆', 'chong2 qing4'),
        ],
      );
      expect(tts.requests.map((r) => r.text), ['去找了', '长乐。']);
      expect(tts.requests.last.pronunciations.map((e) => e.toJson()), [
        {'term': '长乐', 'pinyin': 'chang2 le4'},
      ]);
      expect(tts.requests.first.pronunciations, isEmpty);
      expect(result.utterances.single.pronunciationApplied, isTrue);
    },
  );
  test(
    'skips profiled entries whose pinyin does not cover each character',
    () async {
      final tts = _Tts();
      const chapter = Chapter(number: 1, title: '章', text: '小D和长乐。');
      await _run(
        temp,
        tts,
        chapter,
        lexicon: const [
          PronunciationEntry('小D', 'xiao3 D'),
          PronunciationEntry('小Don', 'xiao3 Don'),
          PronunciationEntry('长乐', 'chang2 le4'),
        ],
      );
      expect(tts.requests.single.pronunciations.map((e) => e.toJson()), [
        {'term': '长乐', 'pinyin': 'chang2 le4'},
      ]);
    },
  );
  test(
    'raw cache follows effective pronunciation and provider request changes',
    () async {
      const chapter = Chapter(number: 1, title: '章', text: '长乐来了。');
      final tts = _Tts();
      final first = await _run(
        temp,
        tts,
        chapter,
        lexicon: const [PronunciationEntry('长乐', 'chang2 le4')],
      );
      expect(
        (await _run(
          temp,
          tts,
          chapter,
          lexicon: const [
            PronunciationEntry('重庆', 'chong2 qing4'),
            PronunciationEntry('长乐', 'cháng  lè'),
          ],
        )).cacheHits,
        1,
      );
      final changed = await _run(
        temp,
        tts,
        chapter,
        lexicon: const [PronunciationEntry('长乐', 'zhang3 le4')],
      );
      expect(changed.requests, 1);
      expect(
        changed.utterances.single.cacheKey,
        isNot(first.utterances.single.cacheKey),
      );
      final split = await _run(
        temp,
        _Tts(limit: 3),
        chapter,
        lexicon: const [PronunciationEntry('长乐', 'zhang3 le4')],
      );
      expect(split.requests, 2);
    },
  );
  test(
    'English ignores the lexicon and unsupported voices explain the fallback',
    () async {
      const chapter = Chapter(number: 1, title: 'I', text: '长乐');
      const lexicon = [PronunciationEntry('长乐', 'chang2 le4')];
      final english = _Tts();
      final en = await _run(
        temp,
        english,
        chapter,
        lexicon: lexicon,
        language: 'en',
      );
      expect(english.requests.single.pronunciations, isEmpty);
      expect(en.utterances.single.pronunciationWarning, isNull);
      final unsupported = _Tts(supportsPronunciation: false);
      final fallback = await _run(temp, unsupported, chapter, lexicon: lexicon);
      expect(unsupported.requests.single.pronunciations, isEmpty);
      expect(fallback.utterances.single.pronunciationApplied, isFalse);
      expect(
        fallback.utterances.single.pronunciationWarning,
        contains('does not support'),
      );
    },
  );
  test('a too-long pronunciation term fails before any paid request', () async {
    final tts = _Tts(limit: 2);
    const chapter = Chapter(number: 1, title: '章', text: '来了。\n重庆市。');
    await expectLater(
      _run(
        temp,
        tts,
        chapter,
        lexicon: const [PronunciationEntry('重庆市', 'chong2 qing4 shi4')],
      ),
      throwsStateError,
    );
    expect(tts.requests, isEmpty);
  });
  test('reads terms with incomplete or invalid pinyin as written', () async {
    final tts = _Tts();
    const chapter = Chapter(number: 1, title: '章', text: '第一句。\n长乐来了。');
    await _run(
      temp,
      tts,
      chapter,
      lexicon: const [
        PronunciationEntry('长乐', 'chang2'),
        PronunciationEntry('来了', 'lai2 l!'),
      ],
    );
    expect(tts.requests.every((r) => r.pronunciations.isEmpty), isTrue);
  });
  test(
    'protected terms and adjacent supplementary CJK preserve the source',
    () async {
      final tts = _Tts(limit: 2);
      const chapter = Chapter(number: 1, title: '章', text: '𠀀长乐');
      await _run(
        temp,
        tts,
        chapter,
        lexicon: const [PronunciationEntry('长乐', 'chang2 le4')],
      );
      expect(tts.requests.map((r) => r.text), ['𠀀', '长乐']);
    },
  );
}

Future<SynthesisResult> _run(
  Directory temp,
  _Tts tts,
  Chapter chapter, {
  List<PronunciationEntry> lexicon = const [],
  String language = 'zh',
}) => Synthesizer(adapters: {'fake': tts}).synthesize(
  chapter: chapter,
  script: Script.narration(bookId: 'book', chapter: chapter),
  language: language,
  lexicon: lexicon,
  voices: const {
    'narrator': VoiceBinding(provider: 'fake', model: 'test', voiceId: 'voice'),
  },
  outputPath: '${temp.path}/chapter.wav',
);

class _Tts implements TtsAdapter {
  _Tts({this.limit = 600, this.supportsPronunciation = true});
  final int limit;
  final bool supportsPronunciation;
  final requests = <TtsRequest>[];
  @override
  String get provider => 'fake';
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) => TtsCapabilities(
    supportsPronunciation: supportsPronunciation,
    maxCharacters: limit,
  );
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    requests.add(request);
    return TtsAudio(
      audio: PcmAudio(samples: Int16List(240)),
      characters: request.text.runes.length,
    );
  }
}
