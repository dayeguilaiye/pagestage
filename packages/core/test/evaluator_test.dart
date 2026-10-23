import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'scores source overlap by Unicode scalars across different line cuts',
    () {
      // Four non-whitespace characters: A, B, 𠀀 and C. Only B is wrong.
      final book = Book(
        id: 'novel',
        title: 'Novel',
        language: 'zh',
        sourcePath: '',
        chapters: [const Chapter(number: 1, title: 'One', text: 'A B\n𠀀C')],
      );
      final cast = Cast(
        bookId: book.id,
        speakers: [
          Speaker(id: 'cast-narrator', name: '旁白', kind: SpeakerKind.narrator),
          Speaker(id: 'cast-hero', name: '主角'),
        ],
      );
      final script = Script(
        bookId: book.id,
        chapterNumber: 1,
        sourceTextHash: book.chapter(1).textHash,
        model: 'fake-director',
        promptVersion: 'director-test-v1',
        lines: const [
          ScriptLine(
            start: 0,
            end: 2,
            direction: Direction(speakerId: 'cast-narrator'),
          ),
          ScriptLine(
            start: 2,
            end: 6,
            direction: Direction(speakerId: 'cast-hero'),
          ),
          ScriptLine(
            start: 6,
            end: 7,
            direction: Direction(speakerId: 'cast-hero'),
          ),
        ],
      );
      final gold = GoldReference(
        bookId: book.id,
        chapterNumber: 1,
        sourceTextHash: book.chapter(1).textHash,
        humanReviewed: false,
        speakers: const {'narrator': '旁白', 'lead': '主角'},
        spans: const [
          GoldSpan(start: 0, end: 4, speakerId: 'narrator'),
          GoldSpan(start: 4, end: 7, speakerId: 'lead'),
        ],
      );
      final result = const Evaluator().evaluate(
        book: book,
        cast: cast,
        script: script,
        reference: gold,
        speakerMap: const {'narrator': 'cast-narrator', 'lead': 'cast-hero'},
      );
      expect(result.totalCharacters, 4);
      expect(result.correctCharacters, 3);
      expect(result.accuracy, .75);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.lineNumber, 2);
      expect(result.errors.single.text, 'B\n𠀀');
      expect(result.errors.single.mismatches.single.text, 'B\n');
      expect(
        result.errors.single.mismatches.single.expectedSpeakerId,
        'narrator',
      );
      expect(
        result.errors.single.mismatches.single.actualSpeakerId,
        'cast-hero',
      );
      expect(result.toJson()['status'], 'draft');
      expect(result.toJson()['model'], 'fake-director');
      expect(result.toJson()['promptVersion'], 'director-test-v1');
    },
  );
  test(
    'rejects mismatched book, chapter and source metadata before scoring',
    () {
      final book = fixtureBook();
      final invalidScripts = [
        fixtureScript(book, bookId: 'another-book'),
        fixtureScript(book, chapterNumber: 2),
        fixtureScript(book, sourceTextHash: 'stale'),
      ];
      for (final script in invalidScripts) {
        expect(() => evaluateFixture(script: script), throwsFormatException);
      }
      final invalidReferences = [
        fixtureGold(book, bookId: 'another-book'),
        fixtureGold(book, chapterNumber: 2),
        fixtureGold(book, sourceTextHash: 'stale'),
      ];
      for (final reference in invalidReferences) {
        expect(
          () => evaluateFixture(reference: reference),
          throwsFormatException,
        );
      }
      expect(
        () => evaluateFixture(cast: Cast(bookId: 'another-book')),
        throwsFormatException,
      );
    },
  );
  test('rejects missing, overlapping and invalid UTF16 source intervals', () {
    final book = fixtureBook('A𠀀B');
    final invalid = <List<(int, int)>>[
      [(0, 2), (2, 4)], // Splits the supplementary character.
      [(0, 1), (3, 4)], // Gap.
      [(0, 3), (1, 4)], // Overlap.
      [(0, 4), (4, 4)], // Empty interval.
      [(-1, 4)], [(0, 5)], [(1, 4)], [(0, 3)], [(3, 1)], [],
    ];
    for (final ranges in invalid) {
      final lines = ranges
          .map(
            (r) => ScriptLine(
              start: r.$1,
              end: r.$2,
              direction: const Direction(speakerId: 'cast-narrator'),
            ),
          )
          .toList();
      final spans = ranges
          .map((r) => GoldSpan(start: r.$1, end: r.$2, speakerId: 'narrator'))
          .toList();
      expect(
        () => evaluateFixture(
          book: book,
          script: fixtureScript(book, lines: lines),
          reference: fixtureGold(
            book,
            spans: const [GoldSpan(start: 0, end: 4, speakerId: 'narrator')],
          ),
        ),
        throwsFormatException,
        reason: 'script $ranges',
      );
      expect(
        () => evaluateFixture(
          book: book,
          reference: fixtureGold(book, spans: spans),
        ),
        throwsFormatException,
        reason: 'reference $ranges',
      );
    }
  });

  test('requires explicit distinct mappings to known cast IDs', () {
    for (final mapping in <Map<String, String>>[
      {'narrator': 'cast-narrator'},
      {'narrator': 'Narrator', 'hero': 'Hero'},
      {'narrator': 'cast-narrator', 'hero': 'typo'},
      {'narrator': 'cast-narrator', 'hero': 'cast-narrator'},
    ]) {
      expect(() => evaluateFixture(speakerMap: mapping), throwsFormatException);
    }
    final book = fixtureBook();
    expect(
      () => evaluateFixture(
        script: fixtureScript(
          book,
          lines: const [
            ScriptLine(
              start: 0,
              end: 2,
              direction: Direction(speakerId: 'missing'),
            ),
          ],
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => evaluateFixture(
        reference: fixtureGold(
          book,
          spans: const [GoldSpan(start: 0, end: 2, speakerId: 'undefined')],
        ),
      ),
      throwsFormatException,
    );
  });

  test(
    'ignores whitespace disagreements and resolves stable cast redirects',
    () {
      // Only A, 𠀀 and ! carry weight; the three spaces use another voice.
      final book = fixtureBook('A \u0085\u2003𠀀!');
      final cast = fixtureCast().copyWith(
        redirects: {
          'old-narrator': 'previous-narrator',
          'previous-narrator': 'cast-narrator',
        },
      );
      final result = evaluateFixture(
        book: book,
        cast: cast,
        script: fixtureScript(
          book,
          lines: const [
            ScriptLine(
              start: 0,
              end: 1,
              direction: Direction(speakerId: 'old-narrator'),
            ),
            ScriptLine(
              start: 1,
              end: 7,
              direction: Direction(speakerId: 'cast-hero'),
            ),
          ],
        ),
        reference: fixtureGold(
          book,
          spans: const [
            GoldSpan(start: 0, end: 4, speakerId: 'narrator'),
            GoldSpan(start: 4, end: 7, speakerId: 'hero'),
          ],
        ),
        speakerMap: const {'narrator': 'old-narrator', 'hero': 'cast-hero'},
      );
      expect(result.correctCharacters, 3);
      expect(result.totalCharacters, 3);
      expect(result.accuracy, 1);
      expect(result.errors, isEmpty);
      expect(result.toJson()['status'], 'reviewed');
      expect(result.toJson().containsKey('warning'), false);
    },
  );

  test('an all-whitespace chapter has no defined accuracy', () {
    final book = fixtureBook('\t\u3000\n');
    final result = evaluateFixture(
      book: book,
      reference: fixtureGold(
        book,
        spans: const [GoldSpan(start: 0, end: 3, speakerId: 'narrator')],
      ),
    );
    expect(result.totalCharacters, 0);
    expect(result.correctCharacters, 0);
    expect(result.accuracy, isNull);
    expect(result.errors, isEmpty);
  });

  test('malformed reference JSON is reported as invalid input', () {
    final valid = fixtureGold(fixtureBook()).toJson();
    for (final invalid in <Object?>[
      null,
      [],
      {...valid, 'schemaVersion': 2},
      {...valid, 'offsetUnit': 'bytes'},
      {...valid, 'humanReviewed': 'false'},
      {...valid, 'sourceTextHash': 'stale'},
      {
        ...valid,
        'speakers': {'narrator': 1},
      },
      {
        ...valid,
        'notes': [false],
      },
      {
        ...valid,
        'spans': [
          {'start': 0, 'end': 1, 'speakerId': false},
        ],
      },
    ]) {
      expect(() => GoldReference.fromJson(invalid), throwsFormatException);
    }
    final parsed = GoldReference.fromJson(valid);
    expect(parsed.spans.last.speakerId, 'hero');
    expect(parsed.spans.last.start, 1);
    expect(parsed.humanReviewed, true);
  });

  test('an explicitly absent cast member counts as a speaker error', () {
    final result = evaluateFixture(
      speakerMap: const {'narrator': 'cast-narrator', 'hero': null},
    );
    expect(result.correctCharacters, 1);
    expect(result.totalCharacters, 2);
    expect(result.accuracy, .5);
    expect(result.errors.single.mismatches.single.text, 'B');
    expect(result.errors.single.mismatches.single.expectedCastId, isNull);
  });

  test(
    'a zero score against an unreviewed reference remains explicitly draft',
    () {
      final book = fixtureBook();
      final result = evaluateFixture(
        reference: fixtureGold(
          book,
          humanReviewed: false,
          spans: const [GoldSpan(start: 0, end: 2, speakerId: 'hero')],
        ),
        speakerMap: const {'hero': null},
      );
      expect(result.accuracy, 0);
      expect(result.correctCharacters, 0);
      expect(result.totalCharacters, 2);
      expect(result.toJson()['status'], 'draft');
      expect(result.toJson()['warning'], contains('awaiting human correction'));
    },
  );
}

Book fixtureBook([String text = 'AB']) => Book(
  id: 'novel',
  title: 'Novel',
  language: 'en',
  sourcePath: '',
  chapters: [Chapter(number: 1, title: 'One', text: text)],
);
Cast fixtureCast() => Cast(
  bookId: 'novel',
  speakers: [
    Speaker(id: 'cast-narrator', name: 'Narrator', kind: SpeakerKind.narrator),
    Speaker(id: 'cast-hero', name: 'Hero'),
  ],
);
Script fixtureScript(
  Book book, {
  String? bookId,
  int chapterNumber = 1,
  String? sourceTextHash,
  List<ScriptLine>? lines,
}) => Script(
  bookId: bookId ?? book.id,
  chapterNumber: chapterNumber,
  sourceTextHash: sourceTextHash ?? book.chapter(1).textHash,
  model: 'fake-director',
  promptVersion: 'v1',
  lines:
      lines ??
      [
        ScriptLine(
          start: 0,
          end: book.chapter(1).text.length,
          direction: const Direction(speakerId: 'cast-narrator'),
        ),
      ],
);
GoldReference fixtureGold(
  Book book, {
  String? bookId,
  int chapterNumber = 1,
  String? sourceTextHash,
  List<GoldSpan>? spans,
  bool humanReviewed = true,
}) => GoldReference(
  bookId: bookId ?? book.id,
  chapterNumber: chapterNumber,
  sourceTextHash: sourceTextHash ?? book.chapter(1).textHash,
  humanReviewed: humanReviewed,
  speakers: const {'narrator': 'Narrator', 'hero': 'Hero'},
  spans:
      spans ??
      const [
        GoldSpan(start: 0, end: 1, speakerId: 'narrator'),
        GoldSpan(start: 1, end: 2, speakerId: 'hero'),
      ],
);
EvaluationResult evaluateFixture({
  Book? book,
  Cast? cast,
  Script? script,
  GoldReference? reference,
  Map<String, String?>? speakerMap,
}) {
  book ??= fixtureBook();
  return const Evaluator().evaluate(
    book: book,
    cast: cast ?? fixtureCast(),
    script: script ?? fixtureScript(book),
    reference: reference ?? fixtureGold(book),
    speakerMap:
        speakerMap ?? const {'narrator': 'cast-narrator', 'hero': 'cast-hero'},
  );
}
