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
    gender: '男',
    personality: '势利',
    voiceName: '老年男声',
    provider: 'bailian',
  ),
  CastMember(id: 'mask', name: '蒙面人', kind: CastMemberKind.persona),
  CastMember(id: 'new', name: '小D', kind: CastMemberKind.provisional),
];

Future<Fakes> _openCast(WidgetTester tester, CastState state) async {
  final fakes = Fakes(casts: FakeCasts(state: state));
  await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
  await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('演员表'));
  await tester.pumpAndSettle();
  return fakes;
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

    await tester.tap(find.text('建档到'));
    await tester.pumpAndSettle();
    expect(find.text('第12章'), findsOneWidget);
    await tester.tap(find.text('第12章'));
    await tester.pumpAndSettle();
    expect(find.text('第 12 章'), findsOneWidget);

    await tester.tap(find.text('开始建档'));
    await tester.pumpAndSettle();
    expect(fakes.casts.profiles, [(_bookId, 12)]);
  });

  testWidgets('profiling runs through the chosen chapter', (tester) async {
    final fakes = await _openCast(
      tester,
      const CastState(bookId: _bookId, chapterCount: 30),
    );
    expect(find.text('第 10 章'), findsOneWidget);

    await tester.tap(find.text('建档到'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第12章'));
    await tester.pumpAndSettle();
    expect(find.text('第 12 章'), findsOneWidget);

    await tester.tap(find.text('开始建档'));
    await tester.pumpAndSettle();
    expect(fakes.casts.profiles, [(_bookId, 12)]);
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
    expect(find.text('建档中'), findsOneWidget);
    expect(find.text('正在建档到第 12 章'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('/ 30'), findsOneWidget);
    // Past the running target by default.
    expect(find.text('第 22 章'), findsOneWidget);

    await tester.tap(find.text('继续往后建档'));
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
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('全书都已建档。'), findsOneWidget);
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
    expect(find.text('大模型：请求太频繁，过一会儿再继续'), findsOneWidget);

    await tester.tap(find.text('继续建档'));
    await tester.pumpAndSettle();
    expect(fakes.casts.resumes, [_bookId]);
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
    expect(find.text('演员 · 4 位'), findsOneWidget);
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
    await tester.tap(find.text('赵太爷'));
    await tester.pumpAndSettle();
    expect(find.text('势利'), findsNothing);
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
