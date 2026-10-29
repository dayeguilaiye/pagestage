import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/listening/generation_gate.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _bookId = 'memory-1';

final _book = MemoryBook(
  title: '阿Q正传',
  chapters: [
    for (var i = 1; i <= 20; i++) MemoryChapter('第$i章', ['正文 $i']),
  ],
);

GenerationRequest _request({int id = 1, int chapter = 3, bool can = true}) =>
    GenerationRequest(
      id: id,
      bookId: _bookId,
      bookTitle: '阿Q正传',
      chapter: chapter,
      canGenerate: can,
    );

Future<Fakes> _pump(WidgetTester tester, {Fakes? fakes}) async {
  fakes ??= Fakes();
  reduceMotion(tester);
  await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
  return fakes;
}

Future<void> _ask(Fakes fakes, WidgetTester tester, GenerationRequest r) async {
  fakes.generation.value = GenerationState(request: r);
  await tester.pumpAndSettle();
}

void main() {
  group('a chapter without audio', () {
    testWidgets('cancelling answers cancel', (tester) async {
      final fakes = await _pump(tester);
      await _ask(fakes, tester, _request());
      expect(find.text('第 3 章还没有配音'), findsOneWidget);
      // No price anywhere.
      expect(find.textContaining('¥'), findsNothing);
      expect(find.textContaining(r'$'), findsNothing);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(fakes.generation.responses, [(1, GenerationChoice.cancel)]);
      expect(find.byType(GenerationDialog), findsNothing);
    });

    testWidgets('generating and the system voice answer as chosen', (
      tester,
    ) async {
      final fakes = await _pump(tester);
      await _ask(fakes, tester, _request(id: 1));
      await tester.tap(find.text('生成配音'));
      await tester.pumpAndSettle();
      await _ask(fakes, tester, _request(id: 2));
      await tester.tap(find.text('用系统声音朗读'));
      await tester.pumpAndSettle();
      expect(fakes.generation.responses, [
        (1, GenerationChoice.generate),
        (2, GenerationChoice.system),
      ]);
    });

    testWidgets('dismissing the dialog cancels', (tester) async {
      final fakes = await _pump(tester);
      await _ask(fakes, tester, _request());
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(fakes.generation.responses, [(1, GenerationChoice.cancel)]);
    });

    testWidgets('a withdrawn request closes without an answer', (tester) async {
      final fakes = await _pump(tester);
      await _ask(fakes, tester, _request());
      fakes.generation.value = const GenerationState();
      await tester.pumpAndSettle();
      expect(find.byType(GenerationDialog), findsNothing);
      expect(fakes.generation.responses, isEmpty);
    });

    testWidgets('outside the profiled range it explains and offers profiling', (
      tester,
    ) async {
      final fakes = await _pump(tester);
      await _ask(fakes, tester, _request(chapter: 12, can: false));

      expect(find.text('生成配音'), findsNothing);
      expect(find.textContaining('还没有建档'), findsOneWidget);
      await tester.tap(find.text('把建档延伸到第 12 章'));
      await tester.pumpAndSettle();

      expect(fakes.generation.responses, [(1, GenerationChoice.cancel)]);
      // The cast page opens with profiling preset to that chapter.
      expect(find.text('建档到'), findsOneWidget);
      expect(find.text('第 12 章'), findsOneWidget);
      await tester.tap(find.text('开始建档'));
      await tester.pumpAndSettle();
      expect(fakes.casts.profiles, [(_bookId, 12)]);
    });
  });

  testWidgets('failures pause quietly and resume without stopping playback', (
    tester,
  ) async {
    final fakes = await _pump(tester);
    fakes.listening.value = const ListeningState(
      bookId: _bookId,
      bookTitle: '阿Q正传',
      chapter: 2,
      chapterTitle: '第2章',
      playing: true,
      buffering: true,
    );
    await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
    await tester.pumpAndSettle();
    fakes.listening.calls.clear();

    fakes.generation.value = const GenerationState(
      failures: [
        GenerationFailure(
          bookId: _bookId,
          chapter: 4,
          provider: 'minimax',
          reason: 'voiceUnavailable',
        ),
        GenerationFailure(
          bookId: 'other',
          chapter: 1,
          provider: 'llm',
          reason: 'network',
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('配音生成暂停了'), findsOneWidget);
    expect(find.text('第 4 章 · MiniMax：分配的声音已不可用，请在演员表里换一个'), findsOneWidget);
    expect(find.textContaining('网络'), findsNothing);
    expect(fakes.listening.calls, isEmpty);
    expect(find.byType(PsMiniPlayer), findsOneWidget);

    await tester.tap(find.text('继续生成'));
    await tester.pumpAndSettle();
    expect(fakes.generation.resumes, [_bookId]);

    // The player says it is waiting for synthesis and shows the pause too.
    await tester.tap(find.byType(PsMiniPlayer));
    await tester.pumpAndSettle();
    expect(find.text('正在生成接下来的配音，好了就继续播放'), findsOneWidget);
    expect(find.text('配音生成暂停了'), findsOneWidget);
  });

  testWidgets('the performance mode is saved per book', (tester) async {
    final fakes = await _pump(tester);
    await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
    await tester.pumpAndSettle();
    final control = tester.widget<PsSegmentedControl<BookPerformanceMode>>(
      find.byType(PsSegmentedControl<BookPerformanceMode>),
    );
    expect(control.value, BookPerformanceMode.audiobook);

    await tester.tap(find.text('广播剧'));
    await tester.pumpAndSettle();
    expect(fakes.generation.modeChanges, [
      (_bookId, BookPerformanceMode.drama),
    ]);
    expect(find.textContaining('跳过「他说」'), findsOneWidget);

    // Back and in again: the stored mode is shown.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PsSegmentedControl<BookPerformanceMode>>(
            find.byType(PsSegmentedControl<BookPerformanceMode>),
          )
          .value,
      BookPerformanceMode.drama,
    );
  });
}
