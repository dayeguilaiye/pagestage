import 'dart:io';
import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  setUp(
    () async => temp = await Directory.systemTemp.createTemp('multivoice-'),
  );
  tearDown(() => temp.delete(recursive: true));

  test('maps provider performance and applies source-aware pauses', () async {
    const chapter = Chapter(number: 1, title: 'Chapter I', text: 'A.B.C.\nD.');
    final script = _script(chapter, [
      const ScriptLine(
        start: 0,
        end: 2,
        direction: Direction(speakerId: 'narrator'),
      ),
      const ScriptLine(
        start: 2,
        end: 4,
        direction: Direction(speakerId: 'narrator'),
      ),
      const ScriptLine(
        start: 4,
        end: 7,
        direction: Direction(
          speakerId: 'alice',
          emotion: Emotion.sad,
          intensity: Intensity.strong,
          note: 'Speak softly.',
        ),
      ),
      const ScriptLine(
        start: 7,
        end: 9,
        direction: Direction(speakerId: 'alice'),
      ),
    ]);
    final minimax = _FakeTts('minimax', EmotionControl.enumerated);
    final bailian = _FakeTts('bailian', EmotionControl.instruction);
    final result =
        await Synthesizer(
          adapters: {'minimax': minimax, 'bailian': bailian},
          cacheDirectory: Directory('${temp.path}/cache'),
        ).synthesize(
          chapter: chapter,
          script: script,
          language: 'en',
          voices: _voices,
          outputPath: '${temp.path}/chapter.wav',
        );
    expect(minimax.requests.map((r) => r.text), ['A.', 'B.']);
    expect(minimax.requests.first.emotion, 'calm');
    expect(minimax.requests.first.instruction, isNull);
    expect(bailian.requests.first.emotion, isNull);
    expect(
      bailian.requests.first.instruction,
      'Read with a sad emotion and strong intensity. Speak softly.',
    );
    expect(result.duration, const Duration(milliseconds: 620));
    expect(result.utterances.map((u) => u.pauseBefore.inMilliseconds), [
      0,
      100,
      180,
      300,
    ]);
    expect(result.utterances.map((u) => u.speakerId), [
      'narrator',
      'narrator',
      'alice',
      'alice',
    ]);
  });
  test(
    'persists raw utterance cache and invalidates only a changed voice',
    () async {
      const chapter = Chapter(number: 1, title: 'I', text: 'A.B.');
      final script = _script(chapter, [
        const ScriptLine(
          start: 0,
          end: 2,
          direction: Direction(speakerId: 'narrator'),
        ),
        const ScriptLine(
          start: 2,
          end: 4,
          direction: Direction(speakerId: 'alice'),
        ),
      ]);
      final first = _FakeTts('minimax', EmotionControl.enumerated);
      final second = _FakeTts('bailian', EmotionControl.instruction);
      final cache = Directory('${temp.path}/cache');
      Future<SynthesisResult> run(Map<String, VoiceBinding> voices) =>
          Synthesizer(
            adapters: {'minimax': first, 'bailian': second},
            cacheDirectory: cache,
          ).synthesize(
            chapter: chapter,
            script: script,
            language: 'en',
            voices: voices,
            outputPath: '${temp.path}/chapter.wav',
          );
      final initial = await run(_voices);
      expect(initial.requests, 2);
      expect(
        initial.utterances.every((item) => File(item.audioPath).existsSync()),
        isTrue,
      );
      final replay = await run(_voices);
      expect(replay.requests, 0);
      expect(replay.cacheHits, 2);
      expect(replay.characters, 0);
      expect(replay.duration, initial.duration);
      final changed = await run({
        ..._voices,
        'alice': const VoiceBinding(
          provider: 'bailian',
          model: 'qwen-audio-3.1-tts-flash',
          voiceId: 'new-voice',
        ),
      });
      expect(changed.requests, 1);
      expect(changed.cacheHits, 1);
      expect(first.requests, hasLength(1));
      expect(second.requests, hasLength(2));
      expect(
        PcmAudio.fromWav(
          await File(initial.utterances.first.audioPath).readAsBytes(),
        ).duration,
        const Duration(milliseconds: 10),
      );
    },
  );
  test(
    'performance modes skip nonstory and drama skips dialogue tags',
    () async {
      const chapter = Chapter(number: 1, title: 'I', text: 'A.tag.Note.B.');
      final script = _script(chapter, [
        const ScriptLine(
          start: 0,
          end: 2,
          direction: Direction(speakerId: 'alice'),
        ),
        const ScriptLine(
          start: 2,
          end: 6,
          direction: Direction(speakerId: 'narrator'),
          isDialogueTag: true,
        ),
        const ScriptLine(
          start: 6,
          end: 11,
          direction: Direction(speakerId: 'unbound'),
          isNonStory: true,
        ),
        const ScriptLine(
          start: 11,
          end: 13,
          direction: Direction(speakerId: 'alice'),
        ),
      ]);
      for (final mode in PerformanceMode.values) {
        final first = _FakeTts('minimax', EmotionControl.enumerated);
        final second = _FakeTts('bailian', EmotionControl.instruction);
        final result =
            await Synthesizer(
              adapters: {'minimax': first, 'bailian': second},
            ).synthesize(
              chapter: chapter,
              script: script,
              language: 'en',
              voices: _voices,
              mode: mode,
              outputPath: '${temp.path}/${mode.name}/chapter.wav',
            );
        expect(
          first.requests.map((r) => r.text),
          mode == PerformanceMode.drama ? isEmpty : ['tag.'],
        );
        expect(second.requests.map((r) => r.text), ['A.', 'B.']);
        expect(
          result.utterances.map((u) => u.lineIndices.single),
          mode == PerformanceMode.drama ? [0, 3] : [0, 1, 3],
        );
      }
    },
  );
  test(
    'merges adjacent narrator source without changing text or directions',
    () async {
      const chapter = Chapter(number: 1, title: 'I', text: 'A. B. C.');
      final script = _script(chapter, [
        const ScriptLine(
          start: 0,
          end: 3,
          direction: Direction(speakerId: 'narrator'),
        ),
        const ScriptLine(
          start: 3,
          end: 6,
          direction: Direction(speakerId: 'narrator'),
        ),
        const ScriptLine(
          start: 6,
          end: 8,
          direction: Direction(speakerId: 'narrator', emotion: Emotion.sad),
        ),
      ]);
      final adapter = _FakeTts('minimax', EmotionControl.enumerated);
      Future<SynthesisResult> run(bool merge) =>
          Synthesizer(adapters: {'minimax': adapter}).synthesize(
            chapter: chapter,
            script: script,
            language: 'en',
            voices: _voices,
            mergeAdjacentNarrator: merge,
            outputPath: '${temp.path}/$merge/chapter.wav',
          );
      expect((await run(false)).requests, 3);
      adapter.requests.clear();
      final merged = await run(true);
      expect(merged.requests, 2);
      expect(adapter.requests.map((request) => request.text), ['A. B. ', 'C.']);
      expect(
        adapter.requests.map((request) => request.text).join(),
        chapter.text,
      );
      expect(merged.utterances.map((item) => item.lineIndices), [
        [0, 1],
        [2],
      ]);
      expect(adapter.requests.last.emotion, 'sad');
    },
  );
  test(
    'cache follows exact text, direction and model and repairs a broken entry',
    () async {
      const chapter = Chapter(number: 1, title: 'I', text: 'Hello.');
      final adapter = _FakeTts('minimax', EmotionControl.enumerated);
      Future<SynthesisResult> run({
        String text = 'Hello.',
        Direction direction = const Direction(speakerId: 'narrator'),
        String model = 'speech-2.8-hd',
      }) {
        final input = Chapter(number: 1, title: chapter.title, text: text);
        return Synthesizer(
          adapters: {'minimax': adapter},
          cacheDirectory: Directory('${temp.path}/cache'),
        ).synthesize(
          chapter: input,
          script: _script(input, [
            ScriptLine(start: 0, end: text.length, direction: direction),
          ]),
          language: 'en',
          voices: {
            'narrator': VoiceBinding(
              provider: 'minimax',
              model: model,
              voiceId: 'voice',
            ),
          },
          outputPath: '${temp.path}/chapter.wav',
        );
      }

      final initial = await run();
      expect((await run()).requests, 0);
      expect((await run(text: 'Hello!')).requests, 1);
      expect(
        (await run(
          direction: const Direction(
            speakerId: 'narrator',
            intensity: Intensity.strong,
          ),
        )).requests,
        1,
      );
      expect(
        (await run(
          direction: const Direction(speakerId: 'narrator', note: 'whisper'),
        )).requests,
        1,
      );
      expect((await run(model: 'speech-2.8-turbo')).requests, 1);
      await File(initial.utterances.single.audioPath).writeAsString('broken');
      expect((await run()).requests, 1);
      expect((await run()).requests, 0);
    },
  );

  test(
    'rejects incomplete scripts and missing bindings before requesting audio',
    () async {
      const chapter = Chapter(number: 1, title: 'I', text: 'A.B.');
      final adapter = _FakeTts('minimax', EmotionControl.enumerated);
      Future<SynthesisResult> run(List<ScriptLine> lines) =>
          Synthesizer(adapters: {'minimax': adapter}).synthesize(
            chapter: chapter,
            script: _script(chapter, lines),
            language: 'en',
            voices: _voices,
            outputPath: '${temp.path}/chapter.wav',
          );
      await expectLater(
        run([
          const ScriptLine(
            start: 0,
            end: 2,
            direction: Direction(speakerId: 'narrator'),
          ),
        ]),
        throwsStateError,
      );
      await expectLater(
        run([
          const ScriptLine(
            start: 0,
            end: 2,
            direction: Direction(speakerId: 'narrator'),
          ),
          const ScriptLine(
            start: 2,
            end: 4,
            direction: Direction(speakerId: 'missing'),
          ),
        ]),
        throwsStateError,
      );
      expect(adapter.requests, isEmpty);
    },
  );
}

Script _script(Chapter chapter, List<ScriptLine> lines) => Script(
  bookId: 'book',
  chapterNumber: chapter.number,
  sourceTextHash: chapter.textHash,
  model: 'fake-director',
  promptVersion: 'test-v1',
  lines: lines,
);
const _voices = {
  'narrator': VoiceBinding(
    provider: 'minimax',
    model: 'speech-2.8-hd',
    voiceId: 'narrator-voice',
  ),
  'alice': VoiceBinding(
    provider: 'bailian',
    model: 'qwen-audio-3.1-tts-flash',
    voiceId: 'Emily_v3.1',
  ),
};

class _FakeTts implements TtsAdapter {
  _FakeTts(this.provider, this.control);
  @override
  final String provider;
  final EmotionControl control;
  final requests = <TtsRequest>[];
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) => TtsCapabilities(
    supportsVoiceDesign: false,
    emotionControl: control,
    supportsPronunciation: false,
    returnsTimestamps: false,
    maxCharacters: 9999,
  );
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    requests.add(request);
    return TtsAudio(
      audio: PcmAudio(samples: Int16List.fromList(List.filled(240, 1200))),
      characters: request.text.runes.length,
    );
  }
}
