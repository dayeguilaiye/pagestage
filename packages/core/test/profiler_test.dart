import 'dart:convert';
import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

class FakeLlm implements LlmAdapter {
  FakeLlm(this.responses);
  final List<Object> responses;
  final List<LlmRequest> requests = [];
  Future<void> Function()? duringRequest;
  @override
  String get model => 'fake-profile';
  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    requests.add(request);
    await duringRequest?.call();
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
  VoicePreset preset(
    String id, {
    String language = 'zh',
    bool narrator = false,
  }) => VoicePreset(
    id: 'ming:$id',
    binding: VoiceBinding(provider: 'ming', model: '10steps', voiceId: id),
    languages: [language],
    gender: 'male',
    ageGroup: 'youngAdult',
    description: '声音 $id 的描述',
    styles: const ['clear'],
    narratorCandidate: narrator,
  );

  test(
    'casts in the profile request and checkpoints actual voices for later chapters',
    () async {
      final catalog = [
        preset('a-default'),
        preset('b'),
        preset('c'),
        preset('d'),
        preset('z-lead'),
        preset('narrator', narrator: true),
        preset('english', language: 'en'),
      ];
      final firstLlm = FakeLlm([
        {
          ...batch(
            characters: [
              character('lead', '林舟', [1], count: 9),
              character('guest', '访客', [1]),
              character('extra', '来人', [1]),
            ],
          ),
          'voiceChoices': [
            {'speakerId': 'lead', 'presetId': 'ming:z-lead'},
            {'speakerId': 'guest', 'presetId': 'ming:english'},
            {'speakerId': 'extra', 'presetId': 'ming:z-lead'},
            {'speakerId': 'narrator', 'presetId': 'ming:narrator'},
            {'speakerId': 'invented', 'presetId': 'ming:b'},
            42,
          ],
        },
      ]);
      final first = await Profiler(
        store,
        firstLlm,
        voiceCatalog: () => catalog,
      ).profile(book, throughChapter: 1);
      final request = firstLlm.requests.single;
      final input = jsonDecode(request.user) as Map;
      final offered = (input['voiceCatalog'] as List).cast<Map>();
      expect(
        offered.map((p) => p['presetId']),
        isNot(contains('ming:english')),
      );
      expect(offered.first['description'], '声音 a-default 的描述');
      expect(offered.first['styles'], ['clear']);
      expect((request.schema['properties'] as Map), contains('voiceChoices'));
      final casting = Casting(store, catalog: catalog);
      final old = await casting.getCasting(book.id);
      final lead = first.cast.findSpeaker('林舟')!.id,
          guest = first.cast.findSpeaker('访客')!.id;
      final extra = first.cast.findSpeaker('来人')!.id;
      expect(old.voices[lead]!.binding.voiceId, 'z-lead');
      expect(old.voices[lead]!.profileSelected, isTrue);
      expect(old.voices['narrator']!.profileSelected, isTrue);
      expect(old.voices[guest]!.profileSelected, isFalse);
      expect(old.voices[extra]!.profileSelected, isFalse);
      expect(
        old.voices.values.map((v) => v.binding.voiceId).toSet(),
        hasLength(4),
      );
      expect(first.cast.speakers.every((s) => s.voiceId != null), isTrue);

      final next = FakeLlm([
        {
          ...batch(
            characters: [
              character('alias', '林舟', [2]),
              character('new', '师傅', [2]),
            ],
          ),
          'voiceChoices': [
            {'speakerId': 'alias', 'presetId': 'ming:b'},
            {'speakerId': 'new', 'presetId': 'ming:d'},
          ],
        },
      ]);
      // The reader changes a binding while the LLM is processing chapter two.
      next.duringRequest = () async {
        await casting.selectPreset(book, guest, 'ming:c');
      };
      final second = await Profiler(
        store,
        next,
        voiceCatalog: () => catalog,
      ).profile(book, throughChapter: 2);
      final assigned =
          (jsonDecode(next.requests.single.user) as Map)['assignedVoices']
              as Map;
      expect(assigned[lead], 'ming:z-lead');
      expect(assigned['narrator'], 'ming:narrator');
      final newId = second.cast.findSpeaker('师傅')!.id;
      final extended = await casting.getCasting(book.id);
      expect(extended.voices[guest]!.binding.voiceId, 'c');
      expect(extended.voices[guest]!.manuallySelected, isTrue);
      expect(extended.voices[lead]!.binding.voiceId, 'z-lead');
      expect(
        extended.voices[extra]!.binding.voiceId,
        old.voices[extra]!.binding.voiceId,
      );
      expect(extended.voices[newId]!.binding.voiceId, 'd');
      final bindings = await Casting(
        store,
        catalog: catalog,
      ).prepareChapterBindings(book, 2);
      expect(bindings[lead]!.voiceId, 'z-lead');
      expect(bindings[newId]!.voiceId, 'd');
      final resumed = FakeLlm([]);
      await Profiler(
        store,
        resumed,
        voiceCatalog: () => catalog,
      ).profile(book, throughChapter: 2);
      expect(resumed.requests, isEmpty);
    },
  );

  test(
    'skips withdrawn and malformed choices independently without retrying the profile',
    () async {
      final a = preset('a'), b = preset('b'), c = preset('c');
      var available = [a, b, c];
      final llm =
          FakeLlm([
              {
                ...batch(
                  characters: [
                    character('first', '甲', [1]),
                    character('second', '乙', [1]),
                  ],
                ),
                'voiceChoices': [
                  {'speakerId': 'first', 'presetId': c.id},
                  {'speakerId': 'second', 'presetId': b.id},
                  {'speakerId': 'second', 'presetId': a.id},
                ],
              },
            ])
            ..duringRequest = () async {
              available = [a, b];
            };
      final profile = await Profiler(
        store,
        llm,
        voiceCatalog: () => available,
      ).profile(book, throughChapter: 1);
      final current = await Casting(store).getCasting(book.id);
      expect(llm.requests, hasLength(1));
      expect(profile.cast.profiledThrough, 1);
      expect(
        current.voices.values.every(
          (v) => !v.profileSelected && v.binding.voiceId != 'c',
        ),
        isTrue,
      );
      expect(current.voices, hasLength(3));
    },
  );

  test('keeps the system narrator out of character profiling input', () async {
    await CastRepository(store).save(
      Cast(
        bookId: book.id,
        speakers: [
          Speaker(id: 'narrator', name: 'Narrator', kind: SpeakerKind.narrator),
          Speaker(id: 'lin', name: '林舟'),
          Speaker(id: 'guest', name: '访客', kind: SpeakerKind.provisional),
        ],
      ),
    );
    final llm = FakeLlm([batch()]);
    final result = await Profiler(store, llm).profile(book, throughChapter: 1);
    final input = jsonDecode(llm.requests.single.user) as Map;
    final speakers = (input['existingCast'] as Map)['speakers'] as List;
    expect(speakers.map((s) => (s as Map)['id']), ['lin', 'guest']);
    expect(result.cast.speaker('narrator').kind, SpeakerKind.narrator);
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
        Profiler(
          store,
          FakeLlm([malformed, malformed]),
        ).profile(book, throughChapter: 1),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.kind, 'kind', ProviderErrorKind.invalidResponse)
              .having((e) => e.code, 'code', 'Invalid dialogue count.')
              .having(
                (e) => e.toString(),
                'message',
                contains('Invalid dialogue count.'),
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
      final ambiguous = batch(
        characters: [
          character('same', '林舟', [1]),
          character('same', '客人', [1]),
        ],
      );
      await expectLater(
        Profiler(
          store,
          FakeLlm([ambiguous, ambiguous]),
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
  test('an unusable reply is retried once with the same request', () async {
    final llm = FakeLlm([
      const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidResponse,
        code: LlmFailure.malformed,
      ),
      batch(
        characters: [
          character('lin', '林舟', [1]),
        ],
      ),
    ]);
    final result = await Profiler(store, llm).profile(book, throughChapter: 1);
    expect(llm.requests, hasLength(2));
    expect(llm.requests.last.user, llm.requests.first.user);
    expect(result.cast.profiledThrough, 1);
    expect(result.cast.findSpeaker('林舟'), isNotNull);
  });
  test('a rejected request is not retried', () async {
    final llm = FakeLlm([
      const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidResponse,
        code: LlmFailure.requestRejected,
      ),
    ]);
    await expectLater(
      Profiler(store, llm).profile(book, throughChapter: 1),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.code,
          'code',
          LlmFailure.requestRejected,
        ),
      ),
    );
    expect(llm.requests, hasLength(1));
  });
  test(
    'a chapter the provider will not profile is skipped and kept on record',
    () async {
      final llm = FakeLlm([
        const ProviderException(
          provider: 'llm',
          kind: ProviderErrorKind.invalidResponse,
          code: LlmFailure.contentFilter,
        ),
        batch(
          characters: [
            character('guest', '客人', [2]),
          ],
        ),
      ]);
      final result = await Profiler(
        store,
        llm,
      ).profile(book, throughChapter: 2);
      expect(llm.requests, hasLength(2));
      expect(result.cast.profiledThrough, 2);
      expect(result.cast.findSpeaker('客人'), isNotNull);
      final saved = await Profiler(store, FakeLlm([])).getCast(book.id);
      expect(saved.skippedChapters, {1: LlmFailure.contentFilter});
      final prompt = jsonDecode(llm.requests.last.user) as Map;
      expect(
        (prompt['existingCast'] as Map).containsKey('skippedChapters'),
        false,
      );
    },
  );
}
