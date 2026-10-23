import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

class FakeLlm implements LlmAdapter {
  FakeLlm(this.responses);
  final List<Object> responses;
  final List<LlmRequest> requests = [];
  @override
  String get model => 'fake-profile';
  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    requests.add(request);
    final next = responses.removeAt(0);
    if (next is Exception) throw next;
    return LlmResponse(
      data: next as Map<String, Object?>,
      usage: const TokenUsage(
        inputTokens: 10,
        outputTokens: 4,
        totalTokens: 14,
      ),
    );
  }
}

Map<String, Object?> character(
  String id,
  String name,
  List<int> chapters, {
  List<String> aliases = const [],
  int count = 2,
}) => {
  'id': id,
  'name': name,
  'aliases': aliases,
  'gender': 'male',
  'ageGroup': 'youngAdult',
  'personality': 'calm',
  'speakingStyle': 'measured',
  'voiceDescription': 'warm',
  'dialogueCount': count,
  'chapters': chapters,
};
Map<String, Object?> batch({
  List<Map<String, Object?>> characters = const [],
  List<Map<String, Object?>> personas = const [],
  List<Map<String, Object?>> merges = const [],
  List<Map<String, Object?>> resolutions = const [],
  List<Map<String, Object?>> lexicon = const [],
}) => {
  'characters': characters,
  'personas': personas,
  'merges': merges,
  'provisionalResolutions': resolutions,
  'lexicon': lexicon,
};
void main() {
  late Directory temp;
  late LocalStore store;
  final book = Book(
    id: 'book',
    title: 'Novel',
    language: 'zh',
    sourcePath: '',
    chapters: [
      for (var i = 1; i <= 5; i++)
        Chapter(number: i, title: '第$i章', text: '林舟走进长乐。'),
    ],
  );
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('profile-');
    store = LocalStore('${temp.path}/db.sqlite');
  });
  tearDown(() async {
    await store.close();
    await temp.delete(recursive: true);
  });
  test(
    'profiles batches and returns saved cast, pronunciation and usage',
    () async {
      final llm = FakeLlm([
        batch(
          characters: [
            character('new-lin', '林舟', [1, 2]),
          ],
          lexicon: [
            {'term': '长乐', 'pinyin': 'chang2 le4'},
          ],
        ),
        batch(
          characters: [
            character('new-lin', '林舟', [3]),
          ],
        ),
      ]);
      final progress = <int>[];
      final result = await Profiler(store, llm).profile(
        book,
        throughChapter: 3,
        batchSize: 2,
        onProgress: (p) => progress.add(p.lastChapter),
      );
      expect(result.cast.profiledThrough, 3);
      expect(
        result.cast.speakers.where((s) => s.kind == SpeakerKind.character),
        hasLength(1),
      );
      expect(result.cast.findSpeaker('林舟')!.chapters, [1, 2, 3]);
      expect(result.cast.lexicon.single.pinyin, 'chang2 le4');
      expect(result.usage.totalTokens, 28);
      expect(progress, [2, 3]);
      expect(
        (await Profiler(store, FakeLlm([])).getCast(book.id)).profiledThrough,
        3,
      );
    },
  );
  test(
    'resumes after a failed batch and preserves the existing speaker ID',
    () async {
      final first = FakeLlm([
        batch(
          characters: [
            character('x', '林舟', [1, 2]),
          ],
        ),
        const ProviderException(
          provider: 'llm',
          kind: ProviderErrorKind.rateLimited,
        ),
      ]);
      await expectLater(
        Profiler(store, first).profile(book, throughChapter: 5, batchSize: 2),
        throwsA(isA<ProviderException>()),
      );
      final before = await Profiler(store, FakeLlm([])).getCast(book.id);
      expect(before.profiledThrough, 2);
      final id = before.findSpeaker('林舟')!.id;
      final resumed = await Profiler(
        store,
        FakeLlm([
          batch(
            characters: [
              character(id, '林舟', [3, 4]),
            ],
          ),
          batch(
            characters: [
              character(id, '林舟', [5]),
            ],
          ),
        ]),
      ).profile(book, throughChapter: 5, batchSize: 2);
      expect(resumed.cast.findSpeaker('林舟')!.id, id);
      expect(resumed.cast.findSpeaker('林舟')!.chapters, [1, 2, 3, 4, 5]);
      expect(resumed.usage.totalTokens, 28);
    },
  );
  test(
    'links a persona to its stable character without collapsing its identity',
    () async {
      final result = await Profiler(
        store,
        FakeLlm([
          batch(
            characters: [
              character('lin', '林舟', [3]),
            ],
            personas: [
              {
                ...character('masked', '黑袍人', [1, 2]),
                'characterId': 'lin',
                'revealChapter': 3,
              },
            ],
          ),
        ]),
      ).profile(book, throughChapter: 3, batchSize: 3);
      final persona = result.cast.findSpeaker('黑袍人')!;
      expect(persona.kind, SpeakerKind.persona);
      expect(persona.characterId, result.cast.findSpeaker('林舟')!.id);
      expect(persona.revealChapter, 3);
      expect(persona.id, isNot(persona.characterId));
    },
  );
  test(
    'merges duplicate characters, retaining target identity and busier voice',
    () async {
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 1,
          speakers: [
            Speaker(
              id: 'narrator',
              name: 'Narrator',
              kind: SpeakerKind.narrator,
            ),
            Speaker(
              id: 'lin',
              name: '林舟',
              dialogueCount: 2,
              voiceId: 'voice-quiet',
              chapters: [1],
            ),
            Speaker(
              id: 'youth',
              name: '少年',
              dialogueCount: 8,
              voiceId: 'voice-busy',
              chapters: [1],
            ),
            Speaker(
              id: 'mask',
              name: '黑袍人',
              kind: SpeakerKind.persona,
              characterId: 'youth',
              revealChapter: 5,
            ),
          ],
        ),
      );
      final result = await Profiler(
        store,
        FakeLlm([
          batch(
            merges: [
              {'fromId': 'youth', 'intoId': 'lin'},
            ],
          ),
        ]),
      ).profile(book, throughChapter: 2);
      expect(
        result.cast.speakers.where((s) => s.kind == SpeakerKind.character),
        hasLength(1),
      );
      expect(result.cast.speaker('lin').voiceId, 'voice-busy');
      expect(result.cast.speaker('lin').dialogueCount, 10);
      expect(result.cast.speaker('mask').characterId, 'lin');
      expect(result.cast.findSpeaker('少年')!.id, 'lin');
      expect(result.cast.speaker('youth').id, 'lin');
    },
  );
  test(
    'resolves provisional characters by merging, promoting or keeping',
    () async {
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 1,
          speakers: [
            Speaker(id: 'lin', name: '林舟'),
            Speaker(
              id: 'tmp1',
              name: '少年',
              kind: SpeakerKind.provisional,
              voiceId: 'temp-voice',
            ),
            Speaker(
              id: 'tmp2',
              name: '客人',
              kind: SpeakerKind.provisional,
              voiceId: 'guest-voice',
            ),
            Speaker(id: 'tmp3', name: '店员', kind: SpeakerKind.provisional),
          ],
        ),
      );
      final result = await Profiler(
        store,
        FakeLlm([
          batch(
            resolutions: [
              {'id': 'tmp1', 'action': 'merge', 'characterId': 'lin'},
              {'id': 'tmp2', 'action': 'promote', 'characterId': null},
              {'id': 'tmp3', 'action': 'keep', 'characterId': null},
            ],
          ),
        ]),
      ).profile(book, throughChapter: 2);
      expect(result.cast.findSpeaker('少年')!.id, 'lin');
      expect(result.cast.speaker('tmp2').kind, SpeakerKind.character);
      expect(result.cast.speaker('tmp2').voiceId, 'guest-voice');
      expect(result.cast.speaker('tmp3').kind, SpeakerKind.provisional);
    },
  );
  test(
    'rejects malformed model data before advancing the saved range',
    () async {
      final malformed = batch(
        characters: [
          {
            ...character('lin', '林舟', [1]),
            'dialogueCount': -1,
          },
        ],
      );
      await expectLater(
        Profiler(store, FakeLlm([malformed])).profile(book, throughChapter: 1),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.kind,
            'kind',
            ProviderErrorKind.invalidResponse,
          ),
        ),
      );
      expect(
        (await Profiler(store, FakeLlm([])).getCast(book.id)).profiledThrough,
        0,
      );
    },
  );
  test('new speakers never reuse redirected IDs from earlier merges', () async {
    await CastRepository(store).save(
      Cast(
        bookId: book.id,
        profiledThrough: 1,
        speakers: [
          Speaker(id: 'book-speaker-1', name: '林舟'),
          Speaker(id: 'book-speaker-2', name: '少年'),
        ],
      ),
    );
    await Profiler(
      store,
      FakeLlm([
        batch(
          merges: [
            {'fromId': 'book-speaker-2', 'intoId': 'book-speaker-1'},
          ],
        ),
      ]),
    ).profile(book, throughChapter: 2);
    final result = await Profiler(
      store,
      FakeLlm([
        batch(
          characters: [
            character('new', '客人', [3]),
          ],
        ),
      ]),
    ).profile(book, throughChapter: 3);
    expect(result.cast.findSpeaker('客人')!.id, 'book-speaker-3');
    expect(result.cast.speaker('book-speaker-2').name, '林舟');
  });
  test(
    'ambiguous IDs in one model response leave the cast unchanged',
    () async {
      await expectLater(
        Profiler(
          store,
          FakeLlm([
            batch(
              characters: [
                character('same', '林舟', [1]),
                character('same', '客人', [1]),
              ],
            ),
          ]),
        ).profile(book, throughChapter: 1),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.kind,
            'kind',
            ProviderErrorKind.invalidResponse,
          ),
        ),
      );
      expect(
        (await Profiler(store, FakeLlm([])).getCast(book.id)).profiledThrough,
        0,
      );
    },
  );
}
