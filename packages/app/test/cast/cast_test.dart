import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/cast/cast_page.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _bookId = 'memory-1';

final _book = MemoryBook(
  title: '阿Q正传',
  chapters: [
    for (var i = 1; i <= 30; i++) MemoryChapter('第$i章', ['正文 $i']),
  ],
);

const _members = [
  CastMember(
    id: 'narrator',
    name: '旁白',
    kind: CastMemberKind.narrator,
    voiceName: '沉稳男声',
    provider: 'minimax',
  ),
  CastMember(
    id: 'zhao',
    name: '赵太爷',
    kind: CastMemberKind.character,
    gender: 'male',
    ageGroup: 'senior',
    personality: '势利',
    voiceName: '老年男声',
    provider: 'bailian',
    firstChapter: 1,
  ),
  CastMember(id: 'mask', name: '蒙面人', kind: CastMemberKind.persona),
  CastMember(id: 'new', name: '小D', kind: CastMemberKind.provisional),
];

/// A language model is set up unless [llm] is false.
Future<Fakes> _openCast(
  WidgetTester tester,
  CastState state, {
  bool llm = true,
  FakeListening? listening,
}) async {
  final fakes = Fakes(
    casts: FakeCasts(state: state),
    listening: listening,
    providers: FakeProviders(
      fakeEngines(llmKey: llm, profileModel: llm ? 'model' : ''),
    ),
  );
  await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
  await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('角色'));
  await tester.pumpAndSettle();
  return fakes;
}

/// Unfolds looking further ahead than listening needs.
Future<void> _ahead(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('profileAhead')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a cast page opened without contents loads them itself', (
    tester,
  ) async {
    final shelf = MemoryBookshelf(books: [_book]);
    final fakes = Fakes(
      casts: FakeCasts(
        state: const CastState(bookId: _bookId, chapterCount: 30),
      ),
      providers: FakeProviders(fakeEngines(llmKey: true, profileModel: 'm')),
    );
    await pumpApp(tester, shelf, fakes);
    final book = (await shelf.books()).single;
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => CastPage(services: fakes.services, book: book),
      ),
    );
    await tester.pumpAndSettle();

    await _ahead(tester);
    await tester.tap(find.text('分析到'));
    await tester.pumpAndSettle();
    expect(find.text('第12章'), findsOneWidget);
    await tester.tap(find.text('第12章'));
    await tester.pumpAndSettle();
    expect(find.text('第 12 章'), findsOneWidget);

    await tester.tap(find.text('开始分析'));
    await tester.pumpAndSettle();
    expect(fakes.casts.profiles, [(_bookId, 12)]);
  });

  testWidgets('finding characters follows listening on its own', (
    tester,
  ) async {
    await _openCast(tester, const CastState(bookId: _bookId, chapterCount: 30));
    expect(find.text('角色与声音'), findsWidgets);
    expect(find.text('还没有分析角色'), findsOneWidget);
    expect(find.text('听到哪里分析到哪里，不用手动操作。'), findsOneWidget);
    // Looking further ahead is folded away until asked for.
    expect(find.text('分析到'), findsNothing);
    expect(find.text('提前分析更多章节…'), findsOneWidget);
  });

  testWidgets('without a language model it says so and opens its settings', (
    tester,
  ) async {
    final fakes = await _openCast(
      tester,
      const CastState(bookId: _bookId, chapterCount: 30),
      llm: false,
    );
    await _ahead(tester);
    await tester.tap(find.text('开始分析'));
    await tester.pumpAndSettle();
    expect(fakes.casts.profiles, isEmpty);
    expect(find.textContaining('请稍后再试'), findsNothing);
    expect(find.text('还差一个大模型账户'), findsOneWidget);
    expect(find.text('配置大模型'), findsOneWidget);
  });

  testWidgets('progress and status show, and profiling extends later', (
    tester,
  ) async {
    final fakes = await _openCast(
      tester,
      const CastState(
        bookId: _bookId,
        profiledThrough: 8,
        targetChapter: 12,
        chapterCount: 30,
        status: ProfilingStatus.running,
      ),
    );
    expect(find.text('分析中'), findsOneWidget);
    expect(find.text('正在分析到第 12 章'), findsOneWidget);
    expect(find.text('已分析到第 8 章 · 共 30 章'), findsOneWidget);
    await _ahead(tester);
    // Past the running target by default.
    expect(find.text('第 22 章'), findsOneWidget);

    await tester.tap(find.text('继续往后分析'));
    await tester.pumpAndSettle();
    expect(fakes.casts.profiles, [(_bookId, 22)]);

    fakes.casts.update(
      const CastState(
        bookId: _bookId,
        profiledThrough: 30,
        targetChapter: 30,
        chapterCount: 30,
        status: ProfilingStatus.complete,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('全书的角色都分析好了。'), findsOneWidget);
    expect(find.text('提前分析更多章节…'), findsNothing);
  });

  testWidgets('a pause says who and why, and resumes', (tester) async {
    final fakes = await _openCast(
      tester,
      const CastState(
        bookId: _bookId,
        profiledThrough: 3,
        targetChapter: 10,
        chapterCount: 30,
        status: ProfilingStatus.paused,
        provider: 'llm',
        reason: 'rateLimited',
      ),
    );
    expect(find.text('已暂停'), findsOneWidget);
    expect(find.text('大模型：请求太频繁'), findsOneWidget);
    // One way on: continuing to the paused target.
    expect(find.text('重试'), findsNothing);

    await tester.tap(find.text('继续分析到第 10 章'));
    await tester.pumpAndSettle();
    expect(find.text('第 10 章'), findsOneWidget);
    await tester.tap(find.widgetWithText(PsButton, '继续分析到第 10 章'));
    await tester.pumpAndSettle();
    expect(fakes.casts.profiles, [(_bookId, 10)]);
  });

  testWidgets('a key problem opens the language model settings', (
    tester,
  ) async {
    await _openCast(
      tester,
      const CastState(
        bookId: _bookId,
        profiledThrough: 3,
        targetChapter: 10,
        chapterCount: 30,
        status: ProfilingStatus.paused,
        provider: 'llm',
        reason: 'unauthorized',
      ),
    );
    await tester.tap(find.text('去设置'));
    await tester.pumpAndSettle();
    expect(find.byType(CastPage), findsNothing);
  });

  testWidgets('a paused target can be moved before continuing', (tester) async {
    final fakes = await _openCast(
      tester,
      const CastState(
        bookId: _bookId,
        profiledThrough: 3,
        targetChapter: 10,
        chapterCount: 30,
        status: ProfilingStatus.paused,
        provider: 'llm',
        reason: 'invalidResponse',
      ),
    );
    await _ahead(tester);
    await tester.tap(find.text('分析到'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第8章'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('继续分析到第 8 章'));
    await tester.pumpAndSettle();
    expect(fakes.casts.profiles, [(_bookId, 8)]);
    expect(fakes.casts.resumes, isEmpty);
  });

  testWidgets('a pause after the range finished is retried from the banner', (
    tester,
  ) async {
    final fakes = await _openCast(
      tester,
      const CastState(
        bookId: _bookId,
        profiledThrough: 10,
        targetChapter: 10,
        chapterCount: 30,
        status: ProfilingStatus.paused,
        provider: 'system',
        reason: 'interrupted',
      ),
    );
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(fakes.casts.resumes, [_bookId]);
  });

  testWidgets('skipped chapters are listed under the progress', (tester) async {
    await _openCast(
      tester,
      const CastState(
        bookId: _bookId,
        profiledThrough: 10,
        targetChapter: 10,
        chapterCount: 30,
        status: ProfilingStatus.complete,
        skippedChapters: [3, 7],
      ),
    );
    expect(find.text('已跳过第 3、7 章：服务商没能处理这些内容'), findsOneWidget);
  });

  testWidgets('the cast lists everyone with voices, collapsed profiles', (
    tester,
  ) async {
    await _openCast(
      tester,
      const CastState(
        bookId: _bookId,
        profiledThrough: 10,
        chapterCount: 30,
        status: ProfilingStatus.complete,
        members: _members,
      ),
    );
    await tester.scrollUntilVisible(find.text('小D'), 200);
    expect(find.text('角色 · 4 位'), findsOneWidget);
    for (final name in ['旁白', '赵太爷', '蒙面人', '小D']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('老年男声 · 阿里云百炼'), findsOneWidget);
    expect(find.text('沉稳男声 · MiniMax'), findsOneWidget);
    expect(find.text('暂定'), findsOneWidget);
    // A persona carries no tag and nothing that points elsewhere.
    final persona = tester.widget<PsCastRow>(
      find.ancestor(of: find.text('蒙面人'), matching: find.byType(PsCastRow)),
    );
    expect(persona.tag, isNull);

    expect(find.text('势利'), findsNothing);
    await tester.tap(find.text('赵太爷'));
    await tester.pumpAndSettle();
    expect(find.text('势利'), findsOneWidget);
    expect(find.text('性格'), findsOneWidget);
    // Profiles speak the reader's language, not the data's.
    expect(find.text('男'), findsOneWidget);
    expect(find.text('老年'), findsOneWidget);
    expect(find.text('male'), findsNothing);
    await tester.tap(find.text('赵太爷'));
    await tester.pumpAndSettle();
    expect(find.text('势利'), findsNothing);
  });

  testWidgets('the narrator is named in the reader’s language', (tester) async {
    await _openCast(
      tester,
      const CastState(
        bookId: _bookId,
        profiledThrough: 10,
        chapterCount: 30,
        status: ProfilingStatus.complete,
        members: [
          CastMember(
            id: 'narrator',
            name: 'Narrator',
            kind: CastMemberKind.narrator,
          ),
        ],
      ),
    );
    expect(find.text('旁白'), findsOneWidget);
    expect(find.text('Narrator'), findsNothing);
  });

  testWidgets('characters who appear later are folded away', (tester) async {
    final listening = FakeListening()
      ..bookmarks[_bookId] = const ListeningBookmark(
        bookId: _bookId,
        chapter: 2,
        line: 0,
        progress: 0,
      );
    await _openCast(
      tester,
      const CastState(
        bookId: _bookId,
        profiledThrough: 10,
        chapterCount: 30,
        status: ProfilingStatus.complete,
        members: [
          CastMember(
            id: 'ah-q',
            name: '阿Q',
            kind: CastMemberKind.character,
            firstChapter: 1,
          ),
          CastMember(
            id: 'wu',
            name: '吴妈',
            kind: CastMemberKind.character,
            firstChapter: 4,
          ),
        ],
      ),
      listening: listening,
    );
    expect(find.text('阿Q'), findsOneWidget);
    expect(find.text('吴妈'), findsNothing);
    await tester.scrollUntilVisible(find.text('显示（可能剧透）'), 200);
    expect(find.text('后面章节登场的 1 位角色'), findsOneWidget);
    await tester.tap(find.text('显示（可能剧透）'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('吴妈'), 200);
    expect(find.text('吴妈'), findsOneWidget);
  });

  testWidgets('auditions start and stop', (tester) async {
    final fakes = await _openCast(
      tester,
      const CastState(
        bookId: _bookId,
        chapterCount: 30,
        status: ProfilingStatus.complete,
        profiledThrough: 30,
        members: _members,
      ),
    );
    final zhao = find.ancestor(
      of: find.text('赵太爷'),
      matching: find.byType(PsCastRow),
    );
    await tester.ensureVisible(zhao);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: zhao, matching: find.byTooltip('试听')));
    await tester.pump();
    expect(fakes.casts.auditions, [(_bookId, 'zhao')]);
    expect(find.text('试听中'), findsOneWidget);

    await tester.tap(
      find.descendant(of: zhao, matching: find.byTooltip('停止试听')),
    );
    await tester.pump();
    expect(fakes.casts.stops, 1);
    expect(find.text('试听中'), findsNothing);
  });
}
