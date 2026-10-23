import 'dart:io';
import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late LocalStore store;
  late Book book;
  late Casting casting;
  late FakeTts fake;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('casting-');
    store = LocalStore('${directory.path}/data.sqlite');
    book = Book(
      id: 'book',
      title: 'Test',
      language: 'zh',
      sourcePath: '',
      chapters: [
        const Chapter(number: 1, title: 'First', text: '你好。'),
        const Chapter(number: 2, title: 'Second', text: '你好。'),
        const Chapter(number: 3, title: 'Third', text: '你好。'),
      ],
    );
    fake = FakeTts();
    casting = Casting(store, catalog: catalog, adapters: {'minimax': fake});
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test(
    'top requested characters own distinct voices separate from narrator',
    () async {
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 3,
          speakers: [
            Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
            Speaker(
              id: 'minor',
              name: '次角',
              dialogueCount: 2,
              gender: 'female',
              ageGroup: 'youngAdult',
              chapters: [1],
            ),
            Speaker(
              id: 'hero',
              name: '主角',
              dialogueCount: 100,
              gender: 'male',
              ageGroup: 'youngAdult',
              chapters: [1],
            ),
            Speaker(
              id: 'heroine',
              name: '主角二',
              dialogueCount: 50,
              gender: 'female',
              ageGroup: 'youngAdult',
              chapters: [1],
            ),
          ],
        ),
      );
      final result = await casting.recommend(book, exclusiveCount: 2);
      expect(result.exclusiveSpeakerIds, {'hero', 'heroine'});
      expect(result.voices['narrator']!.binding.voiceId, 'narrator-zh');
      expect(result.voices['hero']!.binding.voiceId, 'male-young');
      expect(result.voices['heroine']!.binding.voiceId, 'female-young-a');
      expect(result.voices['minor']!.binding.voiceId, 'female-young-b');
      expect(
        (await casting.getCasting(book.id)).voices['hero']!.id,
        result.voices['hero']!.id,
      );
    },
  );

  test(
    'same-chapter extras avoid sharing and preserve voices when a provisional arrives',
    () async {
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 3,
          speakers: [
            Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
            Speaker(
              id: 'a',
              name: '甲',
              gender: 'female',
              ageGroup: 'youngAdult',
              chapters: [1],
            ),
            Speaker(
              id: 'b',
              name: '乙',
              gender: 'female',
              ageGroup: 'youngAdult',
              chapters: [1],
            ),
            Speaker(
              id: 'c',
              name: '丙',
              gender: 'female',
              ageGroup: 'youngAdult',
              chapters: [2],
            ),
          ],
        ),
      );
      final initial = await casting.recommend(
        book,
        exclusiveCount: 0,
        providers: {'minimax'},
      );
      expect(initial.voices['a']!.binding.voiceId, 'female-young-a');
      expect(initial.voices['b']!.binding.voiceId, 'female-young-b');
      expect(initial.voices['c']!.binding.voiceId, 'female-young-a');
      await CastRepository(store).save(
        initial.cast.copyWith(
          speakers: [
            ...initial.cast.speakers,
            Speaker(
              id: 'd',
              name: '新人物',
              kind: SpeakerKind.provisional,
              gender: 'female',
            ),
          ],
        ),
      );
      final bindings = await casting.prepareChapterBindings(
        book,
        1,
        speakerIds: ['a', 'b', 'd'],
      );
      expect(bindings['a']!.voiceId, 'female-young-a');
      expect(bindings['b']!.voiceId, 'female-young-b');
      expect(bindings['d']!.voiceId, 'female-young-a');
      expect((await casting.getCasting(book.id)).exclusiveSpeakerIds, isEmpty);
    },
  );

  test(
    'manual preset selection persists and auditions every cast member through fake TTS',
    () async {
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 3,
          speakers: [
            Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
            Speaker(id: 'hero', name: '主角', dialogueCount: 10),
          ],
        ),
      );
      await casting.recommend(book, exclusiveCount: 1);
      final selected = await casting.selectPreset(
        book,
        'hero',
        'minimax:zzz-old',
      );
      expect(selected.binding.voiceId, 'zzz-old');
      expect(selected.id, isNot(selected.binding.voiceId));
      final again = await casting.recommend(book, exclusiveCount: 1);
      expect(again.voices['hero']!.binding.voiceId, 'zzz-old');
      final samples = await casting.audition(
        book,
        outputDirectory: '${directory.path}/samples',
      );
      expect(samples, hasLength(2));
      expect(fake.requests.map((r) => r.binding.voiceId), [
        'narrator-zh',
        'zzz-old',
      ]);
      for (final voice in samples) {
        expect(await File(voice.samplePath!).exists(), isTrue);
        expect((await casting.getVoice(voice.id)).samplePath, voice.samplePath);
        expect(
          PcmAudio.fromWav(await File(voice.samplePath!).readAsBytes()).samples,
          [1, 2, 3, 4],
        );
      }
    },
  );

  test(
    'persona uses own voice before reveal and established owner voice after',
    () async {
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 3,
          speakers: [
            Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
            Speaker(
              id: 'owner',
              name: '父亲',
              dialogueCount: 10,
              chapters: [1, 3],
            ),
            Speaker(
              id: 'mask',
              name: '黑袍人',
              kind: SpeakerKind.persona,
              characterId: 'owner',
              revealChapter: 3,
              chapters: [2, 3],
            ),
          ],
        ),
      );
      final result = await casting.recommend(book, exclusiveCount: 1);
      final before = await casting.prepareChapterBindings(
        book,
        2,
        speakerIds: ['mask'],
      );
      final after = await casting.prepareChapterBindings(
        book,
        3,
        speakerIds: ['mask', 'owner'],
      );
      expect(before['mask']!.voiceId, result.voices['mask']!.binding.voiceId);
      expect(after['mask']!.voiceId, result.voices['owner']!.binding.voiceId);
      expect(after['mask']!.voiceId, isNot(before['mask']!.voiceId));
    },
  );

  test('owner first appearing at reveal inherits the persona voice', () async {
    await CastRepository(store).save(
      Cast(
        bookId: book.id,
        profiledThrough: 3,
        speakers: [
          Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
          Speaker(id: 'owner', name: '小李', dialogueCount: 10, chapters: [3]),
          Speaker(
            id: 'mask',
            name: '小红',
            kind: SpeakerKind.persona,
            characterId: 'owner',
            revealChapter: 3,
            chapters: [1, 2, 3],
          ),
        ],
      ),
    );
    final result = await casting.recommend(book, exclusiveCount: 1);
    final after = await casting.prepareChapterBindings(
      book,
      3,
      speakerIds: ['owner'],
    );
    expect(after['owner']!.voiceId, result.voices['mask']!.binding.voiceId);
    expect(after['mask']!.voiceId, result.voices['mask']!.binding.voiceId);
    final inherited = after['owner']!.voiceId;
    await casting.selectPreset(book, 'mask', 'minimax:male-young');
    final stable = await casting.prepareChapterBindings(
      book,
      3,
      speakerIds: ['owner'],
    );
    expect(stable['owner']!.voiceId, inherited);
    expect(
      (await casting.prepareChapterBindings(book, 2))['mask']!.voiceId,
      'male-young',
    );
    await casting.selectPreset(book, 'owner', 'minimax:zzz-old');
    final changed = await casting.prepareChapterBindings(
      book,
      3,
      speakerIds: ['owner'],
    );
    expect(changed['owner']!.voiceId, 'zzz-old');
    expect(changed['mask']!.voiceId, 'zzz-old');
  });

  test(
    'preparation persists the earliest revealed persona voice across multiple reveals',
    () async {
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 3,
          speakers: [
            Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
            Speaker(id: 'owner', name: '主人', dialogueCount: 10, chapters: [3]),
            Speaker(
              id: 'later',
              name: '后身份',
              kind: SpeakerKind.persona,
              characterId: 'owner',
              revealChapter: 3,
              chapters: [1, 3],
            ),
            Speaker(
              id: 'earlier',
              name: '先身份',
              kind: SpeakerKind.persona,
              characterId: 'owner',
              revealChapter: 2,
              chapters: [1, 2],
            ),
          ],
        ),
      );
      final initial = await casting.recommend(book, exclusiveCount: 1);
      final prepared = await casting.prepareChapterBindings(
        book,
        3,
        speakerIds: ['owner'],
      );
      final expected = initial.voices['earlier']!.binding.voiceId;
      expect(prepared['owner']!.voiceId, expected);
      expect(prepared['earlier']!.voiceId, expected);
      expect(prepared['later']!.voiceId, expected);
      final reopened = Casting(store, catalog: catalog);
      final saved = await reopened.getCasting(book.id);
      expect(saved.voices['owner']!.inheritedFromPersonaId, 'earlier');
      expect(saved.voices['owner']!.binding.voiceId, expected);
      final voiceCount = (await store.list('voices')).length;
      await reopened.prepareChapterBindings(book, 3, speakerIds: ['owner']);
      expect((await store.list('voices')).length, voiceCount);
      final beforeReveal = await reopened.prepareChapterBindings(book, 1);
      expect(
        beforeReveal['later']!.voiceId,
        initial.voices['later']!.binding.voiceId,
      );
      expect(
        beforeReveal['earlier']!.voiceId,
        initial.voices['earlier']!.binding.voiceId,
      );
    },
  );
  test(
    'built-in catalog supports default twenty exclusive characters in both languages',
    () async {
      final builtIn = Casting(store);
      for (final language in ['zh', 'en']) {
        final fixture = Book(
          id: language,
          title: language,
          language: language,
          sourcePath: '',
          chapters: book.chapters,
        );
        await CastRepository(store).save(
          Cast(
            bookId: language,
            profiledThrough: 3,
            speakers: [
              Speaker(
                id: 'narrator',
                name: 'Narrator',
                kind: SpeakerKind.narrator,
              ),
              for (var i = 0; i < 23; i++)
                Speaker(
                  id: 's$i',
                  name: 'Speaker $i',
                  dialogueCount: 100 - i,
                  chapters: [1],
                ),
            ],
          ),
        );
        final result = await builtIn.recommend(fixture);
        expect(result.exclusiveSpeakerIds, hasLength(20));
        final exclusiveBindings = result.exclusiveSpeakerIds
            .map(
              (id) =>
                  '${result.voices[id]!.binding.provider}:${result.voices[id]!.binding.voiceId}',
            )
            .toSet();
        expect(exclusiveBindings, hasLength(20));
        expect(result.voices, hasLength(24));
        final narrator = result.voices['narrator']!.binding;
        expect(
          defaultVoiceCatalog
              .singleWhere(
                (preset) =>
                    preset.binding.provider == narrator.provider &&
                    preset.binding.voiceId == narrator.voiceId,
              )
              .languages,
          contains(language),
        );
        expect(
          exclusiveBindings,
          isNot(contains('${narrator.provider}:${narrator.voiceId}')),
        );
      }
    },
  );

  test('catalog shortage fails before changing saved selections', () async {
    await CastRepository(store).save(
      Cast(
        bookId: book.id,
        profiledThrough: 3,
        speakers: [
          Speaker(id: 'narrator', name: 'Narrator', kind: SpeakerKind.narrator),
          for (var i = 0; i < 5; i++)
            Speaker(id: 's$i', name: 'Speaker $i', dialogueCount: 10 - i),
        ],
      ),
    );
    await expectLater(casting.recommend(book), throwsStateError);
    expect((await casting.getCasting(book.id)).voices, isEmpty);
  });

  test('senior age tag from profiling matches a senior extra preset', () async {
    await CastRepository(store).save(
      Cast(
        bookId: book.id,
        profiledThrough: 3,
        speakers: [
          Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
          Speaker(
            id: 'elder',
            name: '老人',
            gender: 'male',
            ageGroup: 'senior',
            chapters: [1],
          ),
        ],
      ),
    );
    final result = await casting.recommend(book, exclusiveCount: 0);
    expect(result.voices['elder']!.binding.voiceId, 'zzz-old');
  });

  test(
    'explicit provider and region recommendation updates automatic voices only',
    () async {
      VoicePreset regional(
        String provider,
        String id,
        List<String> regions, {
        bool narrator = false,
      }) => VoicePreset(
        id: '$provider:$id',
        binding: VoiceBinding(provider: provider, model: 'fake', voiceId: id),
        languages: ['zh'],
        gender: 'female',
        ageGroup: 'youngAdult',
        narratorCandidate: narrator,
        regions: regions,
      );
      final selection = Casting(
        store,
        catalog: [
          regional('bailian', 'beijing-narrator', ['beijing'], narrator: true),
          regional('bailian', 'beijing-character', ['beijing']),
          regional('bailian', 'singapore-narrator', [
            'singapore',
          ], narrator: true),
          regional('bailian', 'singapore-character', ['singapore']),
          regional('minimax', 'narrator', [
            'beijing',
            'singapore',
          ], narrator: true),
          regional('minimax', 'character', ['beijing', 'singapore']),
        ],
      );
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 3,
          speakers: [
            Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
            Speaker(
              id: 'automatic',
              name: '甲',
              gender: 'female',
              ageGroup: 'youngAdult',
              chapters: [1],
            ),
            Speaker(
              id: 'manual',
              name: '乙',
              gender: 'female',
              ageGroup: 'youngAdult',
              chapters: [2],
            ),
          ],
        ),
      );
      await selection.recommend(
        book,
        exclusiveCount: 0,
        providers: {'bailian'},
      );
      await selection.selectPreset(book, 'manual', 'bailian:beijing-character');
      final singapore = await selection.recommend(
        book,
        exclusiveCount: 0,
        providers: {'bailian'},
        bailianRegion: 'singapore',
      );
      expect(
        singapore.voices['narrator']!.binding.voiceId,
        'singapore-narrator',
      );
      expect(
        singapore.voices['automatic']!.binding.voiceId,
        'singapore-character',
      );
      expect(singapore.voices['manual']!.binding.voiceId, 'beijing-character');
      final minimax = await selection.recommend(
        book,
        exclusiveCount: 0,
        providers: {'minimax'},
      );
      expect(minimax.voices['narrator']!.binding.provider, 'minimax');
      expect(minimax.voices['automatic']!.binding.provider, 'minimax');
      expect(minimax.voices['manual']!.binding.provider, 'bailian');
      await CastRepository(store).save(
        minimax.cast.copyWith(
          speakers: [
            ...minimax.cast.speakers,
            Speaker(
              id: 'new',
              name: '新角色',
              kind: SpeakerKind.provisional,
              gender: 'female',
              ageGroup: 'youngAdult',
            ),
          ],
        ),
      );
      final filled = await selection.prepareChapterBindings(
        book,
        2,
        speakerIds: ['new'],
      );
      expect(filled['new']!.provider, 'minimax');
      expect(filled['manual']!.provider, 'bailian');
      expect(
        (await selection.getCasting(book.id)).exclusiveSpeakerIds,
        isEmpty,
      );
    },
  );

  test(
    'unknown demographic fallbacks are deterministic and avoid compatible collisions',
    () async {
      final selection = Casting(
        store,
        catalog: [
          preset('narrator-zh', 'unknown', narrator: true),
          preset('a-unknown', 'unknown'),
          preset('b-male', 'male'),
        ],
      );
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 3,
          speakers: [
            Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
            Speaker(
              id: 'a',
              name: '甲',
              gender: 'female',
              ageGroup: 'youngAdult',
              chapters: [1],
            ),
            Speaker(
              id: 'b',
              name: '乙',
              gender: 'female',
              ageGroup: 'youngAdult',
              chapters: [1],
            ),
            Speaker(id: 'c', name: '丙', chapters: [1]),
          ],
        ),
      );
      final result = await selection.recommend(book, exclusiveCount: 0);
      expect(result.voices['a']!.binding.voiceId, 'a-unknown');
      expect(result.voices['b']!.binding.voiceId, 'a-unknown');
      expect(result.voices['c']!.binding.voiceId, 'b-male');
      expect(result.warnings, hasLength(1));
    },
  );
}

VoicePreset preset(
  String id,
  String gender, {
  bool narrator = false,
  String language = 'zh',
  String age = 'youngAdult',
}) => VoicePreset(
  id: 'minimax:$id',
  binding: VoiceBinding(provider: 'minimax', model: 'fake', voiceId: id),
  languages: [language],
  gender: gender,
  ageGroup: age,
  description: 'Test voice $id',
  narratorCandidate: narrator,
);
final catalog = [
  preset('narrator-zh', 'unknown', narrator: true),
  preset('narrator-en', 'unknown', narrator: true, language: 'en'),
  preset('male-young', 'male'),
  preset('female-young-a', 'female'),
  preset('female-young-b', 'female'),
  preset('zzz-old', 'male', age: 'senior'),
];

class FakeTts implements TtsAdapter {
  final List<TtsRequest> requests = [];
  @override
  String get provider => 'minimax';
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) =>
      const TtsCapabilities(supportsPronunciation: true, maxCharacters: 9999);
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    requests.add(request);
    return TtsAudio(
      audio: PcmAudio(samples: Int16List.fromList([1, 2, 3, 4])),
      characters: request.text.runes.length,
    );
  }
}
