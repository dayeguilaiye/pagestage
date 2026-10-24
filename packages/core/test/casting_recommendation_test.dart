import 'dart:convert';
import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late LocalStore store;
  final book = Book(
    id: 'book',
    title: 'Test',
    language: 'zh',
    sourcePath: '',
    chapters: [const Chapter(number: 1, title: 'One', text: '测试')],
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('recommendation-');
    store = LocalStore('${directory.path}/data.sqlite');
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });
  Future<void> save(List<Speaker> speakers) => CastRepository(
    store,
  ).save(Cast(bookId: book.id, profiledThrough: 1, speakers: speakers));

  test(
    'one incomplete preset fills 40 roles, narrator and later provisional',
    () async {
      await save([
        Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
        for (var i = 0; i < 40; i++)
          Speaker(
            id: 's$i',
            name: '角色$i',
            gender: i.isEven ? 'male' : 'female',
            ageGroup: 'senior',
            chapters: [1],
          ),
      ]);
      final casting = Casting(store, catalog: [preset('only')]);
      final result = await casting.recommend(book);
      expect(result.voices, hasLength(41));
      expect(result.voices.values.map((v) => v.binding.voiceId).toSet(), {
        'only',
      });
      expect(result.warnings, isNotEmpty);
      await CastRepository(store).save(
        result.cast.copyWith(
          speakers: [
            ...result.cast.speakers,
            Speaker(id: 'new', name: '临时角色', kind: SpeakerKind.provisional),
          ],
        ),
      );
      final prepared = await casting.prepareChapterBindings(
        book,
        1,
        speakerIds: ['new'],
      );
      expect(prepared, hasLength(42));
      expect(prepared['new']!.voiceId, 'only');
      final saved = await casting.getCasting(book.id);
      for (final id in result.voices.keys) {
        expect(saved.voices[id]!.id, result.voices[id]!.id);
        expect(saved.voices[id]!.binding.voiceId, 'only');
      }
      final again = await casting.recommend(book);
      expect(again.voices.values.map((v) => v.binding.voiceId).toSet(), {
        'only',
      });
    },
  );

  test('same gender and age win over unused incompatible voices', () async {
    await save([
      for (final id in ['a', 'b', 'c'])
        Speaker(id: id, name: id, gender: 'female', ageGroup: 'middleAged'),
    ]);
    final casting = Casting(
      store,
      catalog: [
        preset('a-wrong-gender', gender: 'male', age: 'middleAged'),
        preset('b-wrong-age', gender: 'female', age: 'child'),
        preset('z-match', gender: 'female', age: 'middleAged'),
      ],
    );
    final result = await casting.recommend(book, exclusiveCount: 2);
    expect(result.voices.values.map((v) => v.binding.voiceId).toSet(), {
      'z-match',
    });
    await casting.selectPreset(book, 'b', 'minimax:a-wrong-gender');
    final again = await casting.recommend(book);
    expect(again.voices['b']!.binding.voiceId, 'a-wrong-gender');
    expect(again.voices['b']!.manuallySelected, isTrue);
  });

  test(
    'age distance, unknown tags and opposite gender provide ordered fallbacks',
    () async {
      await save([
        Speaker(
          id: 'role',
          name: '角色',
          gender: 'female',
          ageGroup: 'middleAged',
        ),
      ]);
      final pools = [
        [
          preset('far', gender: 'female', age: 'child'),
          preset('near', gender: 'female', age: 'youngAdult'),
          preset('unknown', gender: 'female'),
        ],
        [
          preset('unknown', gender: 'female'),
          preset('male', gender: 'male', age: 'middleAged'),
        ],
        [preset('unknown'), preset('male', gender: 'male', age: 'middleAged')],
        [preset('male', gender: 'male', age: 'middleAged')],
      ];
      for (var i = 0; i < pools.length; i++) {
        final result = await Casting(store, catalog: pools[i]).recommend(book);
        expect(
          result.voices['role']!.binding.voiceId,
          ['near', 'unknown', 'unknown', 'male'][i],
        );
      }
    },
  );

  test(
    'delivery style breaks demographic ties across Chinese and English',
    () async {
      await save([
        Speaker(
          id: 'role',
          name: '角色',
          gender: 'male',
          ageGroup: 'youngAdult',
          speakingStyle: '低沉、冷静',
          voiceDescription: '沉稳而磁性',
        ),
      ]);
      final result = await Casting(
        store,
        catalog: [
          preset(
            'a-bright',
            gender: 'male',
            age: 'youngAdult',
            styles: ['bright'],
          ),
          preset(
            'z-calm',
            gender: 'male',
            age: 'youngAdult',
            styles: voiceStyleTags('calm, deep, magnetic'),
          ),
        ],
      ).recommend(book);
      expect(result.voices['role']!.binding.voiceId, 'z-calm');
    },
  );

  test(
    'reviewed narrator wins then official narrator then any compatible voice',
    () async {
      await save([
        Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
      ]);
      final pools = [
        [
          preset('a-unspecified'),
          preset('b-official', narrator: true),
          preset('z-reviewed', narrator: true, review: 'approved'),
        ],
        [preset('a-unspecified'), preset('b-official', narrator: true)],
        [preset('a-unspecified')],
      ];
      for (var i = 0; i < pools.length; i++) {
        final result = await Casting(store, catalog: pools[i]).recommend(book);
        expect(
          result.voices['narrator']!.binding.voiceId,
          ['z-reviewed', 'b-official', 'a-unspecified'][i],
        );
      }
    },
  );

  test(
    'narrator fallback prefers calm clear delivery and complete tags',
    () async {
      await save([
        Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
      ]);
      final result = await Casting(
        store,
        catalog: [
          preset(
            'a-playful',
            gender: 'male',
            age: 'youngAdult',
            styles: ['humorous'],
          ),
          preset('b-incomplete', styles: ['calm', 'clear']),
          preset(
            'z-calm',
            gender: 'male',
            age: 'middleAged',
            styles: ['calm', 'clear'],
          ),
        ],
      ).recommend(book);
      expect(result.voices['narrator']!.binding.voiceId, 'z-calm');
      expect(result.warnings, isNotEmpty);
    },
  );

  test(
    'explicit recommendation refreshes automatic choices after catalog enrichment',
    () async {
      await save([
        Speaker(
          id: 'role',
          name: '角色',
          gender: 'female',
          ageGroup: 'middleAged',
        ),
      ]);
      final first = await Casting(
        store,
        catalog: [preset('a'), preset('b')],
      ).recommend(book);
      expect(first.voices['role']!.binding.voiceId, 'a');
      final enriched = await Casting(
        store,
        catalog: [
          preset('a'),
          preset('b', gender: 'female', age: 'middleAged'),
        ],
      ).recommend(book);
      expect(enriched.voices['role']!.binding.voiceId, 'b');
    },
  );

  test('no compatible candidate leaves saved casting untouched', () async {
    await save([Speaker(id: 'role', name: '角色')]);
    final casting = Casting(store, catalog: [preset('only')]);
    final before = await casting.recommend(book);
    await expectLater(
      casting.recommend(book, providers: {'bailian'}),
      throwsStateError,
    );
    expect(
      (await casting.getCasting(book.id)).voices['role']!.binding.voiceId,
      before.voices['role']!.binding.voiceId,
    );
  });

  for (final name in ['aq', 'pride-and-prejudice']) {
    for (final provider in ['minimax', 'bailian']) {
      for (final region in ['beijing', 'singapore']) {
        test(
          '$name fills its saved spike cast with $provider in $region',
          () async {
            final file = File('packages/core/test/fixtures/casting/$name.json');
            final fixture =
                jsonDecode(
                      await (await file.exists()
                              ? file
                              : File('test/fixtures/casting/$name.json'))
                          .readAsString(),
                    )
                    as Map;
            final cast = Cast.fromJson(
              Map<String, Object?>.from(fixture['cast'] as Map),
            );
            final fixtureBook = Book(
              id: cast.bookId,
              title: fixture['title'] as String,
              language: fixture['language'] as String,
              sourcePath: '',
              chapters: book.chapters,
            );
            await CastRepository(store).save(cast);
            final casting = Casting(store);
            if (fixtureBook.language == 'zh' &&
                provider == 'bailian' &&
                region == 'singapore') {
              await expectLater(
                casting.recommend(
                  fixtureBook,
                  providers: {provider},
                  bailianRegion: region,
                ),
                throwsStateError,
              );
              expect(
                (await casting.getCasting(fixtureBook.id)).voices,
                isEmpty,
              );
              return;
            }
            final result = await casting.recommend(
              fixtureBook,
              providers: {provider},
              bailianRegion: region,
            );
            expect(result.voices.length, cast.speakers.length);
            final candidates = defaultVoiceCatalog
                .where(
                  (p) =>
                      p.binding.provider == provider &&
                      p.languages.contains(fixtureBook.language) &&
                      (provider != 'bailian' || p.regions.contains(region)),
                )
                .toList();
            for (final speaker in cast.speakers) {
              final voice = result.voices[speaker.id]!;
              final selected = candidates.singleWhere(
                (p) => p.binding.voiceId == voice.binding.voiceId,
              );
              if (speaker.kind == SpeakerKind.narrator) {
                if (candidates.any((p) => p.narratorCandidate)) {
                  expect(selected.narratorCandidate, isTrue);
                }
              } else if (speaker.gender != 'unknown' &&
                  candidates.any((p) => p.gender == speaker.gender)) {
                expect(selected.gender, speaker.gender, reason: speaker.name);
                if (speaker.ageGroup != 'unknown' &&
                    candidates.any(
                      (p) =>
                          p.gender == speaker.gender &&
                          p.ageGroup == speaker.ageGroup,
                    )) {
                  expect(
                    selected.ageGroup,
                    speaker.ageGroup,
                    reason: speaker.name,
                  );
                }
              }
            }
            final again = await casting.recommend(
              fixtureBook,
              providers: {provider},
              bailianRegion: region,
            );
            expect(
              again.voices.map((id, v) => MapEntry(id, v.binding.voiceId)),
              result.voices.map((id, v) => MapEntry(id, v.binding.voiceId)),
            );
          },
        );
      }
    }
  }
}

VoicePreset preset(
  String id, {
  String gender = 'unknown',
  String age = 'unknown',
  List<String> styles = const [],
  bool narrator = false,
  String review = 'notReviewed',
}) => VoicePreset(
  id: 'minimax:$id',
  binding: VoiceBinding(provider: 'minimax', model: 'fake', voiceId: id),
  languages: ['zh'],
  gender: gender,
  ageGroup: age,
  styles: styles,
  narratorCandidate: narrator,
  narratorReview: review,
);
