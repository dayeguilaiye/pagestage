import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/settings/provider_pages.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _bookId = 'memory-1';

final _book = MemoryBook(
  title: '阿Q正传',
  chapters: [
    for (var i = 1; i <= 20; i++) MemoryChapter('第$i章', ['正文 $i']),
  ],
);

Future<Fakes> _pump(WidgetTester tester, {Fakes? fakes}) async {
  fakes ??= Fakes();
  reduceMotion(tester);
  await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
  return fakes;
}

Future<void> _openBook(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
  await tester.pumpAndSettle();
}

Future<void> _openVoiceSheet(WidgetTester tester) async {
  await tester.tap(find.text('听到哪里准备到哪里'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('listening never asks: there is no dialog to answer', (
    tester,
  ) async {
    final fakes = await _pump(tester);
    fakes.listening.value = const ListeningState(
      bookId: _bookId,
      bookTitle: '阿Q正传',
      chapter: 3,
      chapterTitle: '第3章',
      source: ListeningSource.system,
      playing: true,
      aiVoice: true,
      fallback: true,
    );
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(find.textContaining('还没有配音'), findsNothing);
    // No price anywhere.
    expect(find.textContaining('¥'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);

    await tester.tap(find.byType(PsMiniPlayer));
    await tester.pumpAndSettle();
    expect(find.text('AI 配音没能及时准备好，这一章先用系统声音，下一章自动换回。'), findsOneWidget);
  });

  testWidgets(
    'while AI voices are prepared the player offers the system voice',
    (tester) async {
      final fakes = await _pump(tester);
      fakes.listening.value = ListeningState(
        bookId: _bookId,
        bookTitle: '阿Q正传',
        chapter: 2,
        chapterTitle: '第2章',
        buffering: true,
        aiVoice: true,
        waitingSince: DateTime(2026),
      );
      fakes.generation.progress.value = const GenerationProgress([
        ChapterProgress(
          bookId: _bookId,
          chapter: 2,
          stage: ChapterStage.voicing,
          directed: true,
          voiced: 12,
          total: 80,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('正在准备 AI 配音…'), findsOneWidget);
      await tester.tap(find.byType(PsMiniPlayer));
      await tester.pumpAndSettle();
      expect(find.text('正在准备本章：配音中 12/80'), findsOneWidget);
      await tester.tap(find.text('先用系统声音听'));
      await tester.pumpAndSettle();
      expect(fakes.listening.calls, contains('useSystemVoice'));
    },
  );

  testWidgets('failures pause quietly and offer the fix for their reason', (
    tester,
  ) async {
    final fakes = await _pump(tester);
    fakes.listening.value = const ListeningState(
      bookId: _bookId,
      bookTitle: '阿Q正传',
      chapter: 2,
      chapterTitle: '第2章',
      playing: true,
    );
    await _openBook(tester);
    fakes.listening.calls.clear();

    fakes.generation.value = const GenerationState(
      failures: [
        GenerationFailure(
          bookId: _bookId,
          chapter: 4,
          provider: 'minimax',
          reason: 'network',
        ),
        GenerationFailure(
          bookId: 'other',
          chapter: 1,
          provider: 'llm',
          reason: 'unauthorized',
        ),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('AI 配音暂停了'), findsOneWidget);
    expect(find.textContaining('第 4 章 · MiniMax：网络连不上'), findsOneWidget);
    expect(find.textContaining('稍后会自动重试'), findsOneWidget);
    expect(find.textContaining('暂停期间用系统声音朗读'), findsOneWidget);
    expect(find.textContaining('密钥'), findsNothing);
    expect(fakes.listening.calls, isEmpty);

    await tester.tap(find.text('立即重试'));
    await tester.pumpAndSettle();
    expect(fakes.generation.resumes, [_bookId]);

    // A key problem opens the provider's settings instead of retrying.
    fakes.generation.value = const GenerationState(
      failures: [
        GenerationFailure(
          bookId: _bookId,
          chapter: 4,
          provider: 'minimax',
          reason: 'unauthorized',
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查 MiniMax 设置'));
    await tester.pumpAndSettle();
    expect(tester.widget<EnginePage>(find.byType(EnginePage)).id, 'minimax');
    expect(fakes.generation.resumes, [_bookId]);
  });

  testWidgets('out of credit offers the system voice for the whole book', (
    tester,
  ) async {
    final fakes = await _pump(tester);
    await _openBook(tester);
    fakes.generation.value = const GenerationState(
      failures: [
        GenerationFailure(
          bookId: _bookId,
          chapter: 1,
          provider: 'llm',
          reason: 'quotaExceeded',
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('这本书改用系统声音'));
    await tester.pumpAndSettle();
    expect(fakes.generation.aiChanges, [(_bookId, false)]);
  });

  testWidgets('the book says what AI voices still need, with the fix', (
    tester,
  ) async {
    final fakes = await _pump(tester);
    fakes.generation.voices[_bookId] = const BookVoice(
      bookId: _bookId,
      ai: true,
      gap: VoiceSetupGap.languageModel,
    );
    await _openBook(tester);
    expect(find.text('还差一个大模型账户'), findsOneWidget);
    await tester.tap(find.text('还差一个大模型账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('配置大模型'));
    await tester.pumpAndSettle();
    expect(find.byType(EnginePage), findsOneWidget);
  });

  testWidgets('the voice sheet turns AI voices off and sets the performance', (
    tester,
  ) async {
    final fakes = await _pump(tester);
    await _openBook(tester);
    await _openVoiceSheet(tester);
    expect(find.text('配音设置'), findsOneWidget);

    await tester.tap(find.text('念出「他说」这类提示'));
    await tester.pumpAndSettle();
    expect(fakes.generation.modeChanges, [
      (_bookId, BookPerformanceMode.drama),
    ]);
    await tester.tap(find.text('夸张'));
    await tester.pumpAndSettle();
    expect(fakes.generation.expressionChanges, [
      (_bookId, BookExpressiveness.dramatic),
    ]);

    await tester.tap(find.byKey(const ValueKey('bookAiVoice')));
    await tester.pumpAndSettle();
    expect(fakes.generation.aiChanges, [(_bookId, false)]);
    // Off, only the switch and the characters remain.
    expect(find.text('念出「他说」这类提示'), findsNothing);
  });

  testWidgets('turning AI voices on asks for agreement first', (tester) async {
    final fakes = await _pump(tester);
    fakes.generation.voices[_bookId] = const BookVoice(bookId: _bookId);
    fakes.generation.allowed = false;
    await _openBook(tester);
    expect(find.text('开启 AI 多角色配音'), findsOneWidget);
    await tester.tap(find.text('开启 AI 多角色配音'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('bookAiVoice')));
    await tester.pumpAndSettle();
    expect(fakes.generation.allows, [_bookId]);
    expect(fakes.generation.aiChanges, isEmpty);

    fakes.generation.allowed = true;
    await tester.tap(find.byKey(const ValueKey('bookAiVoice')));
    await tester.pumpAndSettle();
    expect(fakes.generation.aiChanges, [(_bookId, true)]);
  });

  testWidgets('a sample book is voiced in advance and cannot change', (
    tester,
  ) async {
    final fakes = await _pump(tester);
    fakes.generation.voices[_bookId] = const BookVoice(
      bookId: _bookId,
      ai: true,
      sample: true,
    );
    await _openBook(tester);
    await tester.tap(find.text('示例 · 已配好音'));
    await tester.pumpAndSettle();
    expect(find.text('示例书已经配好音'), findsOneWidget);
    expect(find.byKey(const ValueKey('bookAiVoice')), findsNothing);
    expect(find.text('念出「他说」这类提示'), findsNothing);
  });

  testWidgets('listening far ahead waits for a go-ahead to find characters', (
    tester,
  ) async {
    final fakes = await _pump(tester);
    fakes.generation.voices[_bookId] = const BookVoice(
      bookId: _bookId,
      ai: true,
      profiledThrough: 2,
      profileNeeded: 18,
    );
    await _openBook(tester);
    expect(find.text('从第 18 章用 AI 配音，要先分析前面的角色'), findsOneWidget);
    await tester.tap(find.text('开始分析'));
    await tester.pumpAndSettle();
    expect(fakes.generation.allows, [_bookId]);
    expect(fakes.generation.profiles, [(_bookId, 18)]);
  });

  testWidgets('the contents mark the chapter being listened to', (
    tester,
  ) async {
    final fakes = await _pump(tester);
    fakes.listening.value = const ListeningState(
      bookId: _bookId,
      bookTitle: '阿Q正传',
      chapter: 2,
      chapterTitle: '第2章',
    );
    await _openBook(tester);
    expect(find.text('正在听'), findsOneWidget);
  });
}
