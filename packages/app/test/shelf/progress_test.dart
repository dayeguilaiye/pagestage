import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/bookshelf.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _bookId = 'memory-1';

MemoryBook _book({int profiled = 8, int synthesized = 1}) => MemoryBook(
  title: '阿Q正传',
  chapters: [
    for (var i = 1; i <= 12; i++)
      MemoryChapter(
        '第$i章',
        ['一。二。'],
        state: i <= synthesized
            ? ChapterState.synthesized
            : i <= profiled
            ? ChapterState.profiled
            : ChapterState.unprofiled,
      ),
  ],
);

/// Chapter 2 as its script splits it.
const _lines = [
  ListeningLine(index: 0, text: '一。', start: 0, end: 2, directed: true),
  ListeningLine(index: 1, text: '二。', start: 2, end: 4, directed: true),
];

Future<Fakes> _openBook(WidgetTester tester, {MemoryBook? book}) async {
  final fakes = Fakes();
  reduceMotion(tester);
  await pumpApp(tester, MemoryBookshelf(books: [book ?? _book()]), fakes);
  await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
  await tester.pumpAndSettle();
  return fakes;
}

void _progress(Fakes fakes, List<ChapterProgress> chapters) =>
    fakes.generation.progress.value = GenerationProgress(chapters);

List<bool> _pending(WidgetTester tester) => [
  for (final paragraph
      in tester.widget<PsPassage>(find.byType(PsPassage).first).paragraphs)
    for (final line in paragraph) line.pending,
];

void main() {
  testWidgets('the contents mark only chapters under way', (tester) async {
    final fakes = await _openBook(tester);
    expect(find.byType(PsStatusMark), findsNothing);

    _progress(fakes, const [
      ChapterProgress(
        bookId: _bookId,
        chapter: 2,
        stage: ChapterStage.voicing,
        directed: true,
        voiced: 18,
        total: 40,
      ),
      ChapterProgress(bookId: _bookId, chapter: 3, stage: ChapterStage.queued),
      ChapterProgress(bookId: _bookId, chapter: 4, stage: ChapterStage.paused),
      ChapterProgress(bookId: 'other', chapter: 5, stage: ChapterStage.queued),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('配音中 18/40'), findsOneWidget);
    expect(find.text('排队中'), findsOneWidget);
    expect(find.text('已暂停'), findsOneWidget);
    // Another book's work stays off this page.
    expect(find.byType(PsStatusMark), findsNWidgets(3));

    _progress(fakes, const []);
    await tester.pumpAndSettle();
    expect(find.byType(PsStatusMark), findsNothing);
  });

  testWidgets('directing shows the time it has taken', (tester) async {
    final fakes = await _openBook(tester);
    _progress(fakes, [
      ChapterProgress(
        bookId: _bookId,
        chapter: 2,
        stage: ChapterStage.directing,
        since: DateTime.now().subtract(const Duration(seconds: 14)),
      ),
    ]);
    await tester.pump();
    expect(find.text('导演中 0:14'), findsOneWidget);
    // Its clock stops with it, leaving no timer behind.
    _progress(fakes, const []);
    await tester.pumpAndSettle();
    expect(find.textContaining('导演中'), findsNothing);
  });

  testWidgets('a chapter being voiced shows which sentences wait', (
    tester,
  ) async {
    final fakes = await _openBook(tester);
    fakes.listening.chapterLines[(_bookId, 2)] = _lines;
    _progress(fakes, const [
      ChapterProgress(
        bookId: _bookId,
        chapter: 2,
        stage: ChapterStage.voicing,
        directed: true,
        voiced: 1,
        total: 2,
        unvoiced: {1},
      ),
    ]);
    await tester.tap(find.text('第2章'));
    await tester.pumpAndSettle();
    expect(find.text('配音中 1/2'), findsOneWidget);
    // One paragraph, its second sentence still waiting.
    expect(_pending(tester), [false, true]);

    _progress(fakes, const []);
    await tester.pumpAndSettle();
    expect(_pending(tester), [false, false]);
    expect(find.text('配音中 1/2'), findsNothing);
  });

  testWidgets('a chapter waits whole until its script arrives', (tester) async {
    final fakes = await _openBook(tester);
    var fetches = 0;
    fakes.listening.onLines = (bookId, chapter) async {
      if (chapter != 2) return const [];
      fetches++;
      return fetches == 1 ? const [] : _lines;
    };
    _progress(fakes, const [
      ChapterProgress(bookId: _bookId, chapter: 2, stage: ChapterStage.queued),
    ]);
    await tester.tap(find.text('第2章'));
    await tester.pumpAndSettle();
    expect(find.text('排队中'), findsOneWidget);
    expect(_pending(tester), [true]);

    // Directed: the chapter is read again, now as its script's lines.
    _progress(fakes, const [
      ChapterProgress(
        bookId: _bookId,
        chapter: 2,
        stage: ChapterStage.voicing,
        directed: true,
        total: 2,
        unvoiced: {0, 1},
      ),
    ]);
    await tester.pumpAndSettle();
    expect(fetches, 2);
    expect(_pending(tester), [true, true]);
    expect(find.text('配音中 0/2'), findsOneWidget);
  });

  testWidgets('generating ahead starts from the first chapter without voice', (
    tester,
  ) async {
    final fakes = await _openBook(tester);
    await tester.tap(find.text('提前生成'));
    await tester.pumpAndSettle();
    expect(find.text('第 2 章'), findsOneWidget);
    expect(find.text('第 6 章'), findsOneWidget);

    await tester.tap(find.text('到'));
    await tester.pumpAndSettle();
    final picker = find.byType(PsSheet).last;
    // Only the profiled chapters are offered.
    expect(
      find.descendant(of: picker, matching: find.text('第9章')),
      findsNothing,
    );
    await tester.tap(find.descendant(of: picker, matching: find.text('第8章')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('生成第 2–8 章'));
    await tester.pumpAndSettle();
    expect(fakes.generation.prepares, [(_bookId, 2, 8)]);
    expect(find.text('生成第 2–8 章'), findsNothing);
  });

  testWidgets('without a profiled chapter, generating ahead says why', (
    tester,
  ) async {
    final fakes = await _openBook(
      tester,
      book: _book(profiled: 0, synthesized: 0),
    );
    await tester.tap(find.text('提前生成'));
    await tester.pumpAndSettle();
    expect(find.text('建档范围内的章节才能生成。先在演员表里建档。'), findsOneWidget);
    expect(find.textContaining('生成第'), findsNothing);
    expect(fakes.generation.prepares, isEmpty);
  });
}
