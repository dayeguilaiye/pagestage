import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/bookshelf.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _bookId = 'memory-1';

final _paragraphs = [
  '（本章由某某书屋整理）',
  '『你敢胡说！』赵太爷说。',
  for (var i = 0; i < 40; i++) '阿Q不开口，只是看着地上的影子。（$i）',
];

final _book = MemoryBook(
  title: '阿Q正传',
  chapters: [
    MemoryChapter('第一章　序', _paragraphs, state: ChapterState.synthesized),
    const MemoryChapter('第二章　优胜记略', ['阿Q不独是姓名籍贯有些渺茫。']),
  ],
);

/// The story line of paragraph [k] in [linesFor].
int _lineOf(int k) => 2 * k;

Fakes _fakes() {
  final fakes = Fakes();
  fakes.listening.chapterLines[(_bookId, 1)] = linesFor(
    _paragraphs,
    nonStory: {0},
    speakers: {_lineOf(1): '赵太爷'},
  );
  return fakes;
}

ListeningState _playing({
  int chapter = 1,
  int chapterCount = 2,
  List<int> active = const [],
  bool playing = true,
  ListeningSource source = ListeningSource.synthesized,
  Duration duration = const Duration(minutes: 10),
  String? error,
}) => ListeningState(
  bookId: _bookId,
  bookTitle: '阿Q正传',
  chapter: chapter,
  chapterTitle: '第一章　序',
  chapterCount: chapterCount,
  line: active.isEmpty ? 0 : active.first,
  lineCount: 84,
  activeLines: active,
  playing: playing,
  source: source,
  position: duration ~/ 4,
  duration: duration,
  error: error,
);

Future<void> _openReader(WidgetTester tester, Fakes fakes) async {
  await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
  await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('第一章　序'));
  await tester.pumpAndSettle();
}

Finder _paragraph(String text) => find.textContaining(text, findRichText: true);

/// Taps just past the paragraph's indent, on its first characters.
Future<void> _tapParagraph(WidgetTester tester, String text) async {
  await tester.tapAt(
    tester.getTopLeft(_paragraph(text)) + const Offset(48, 12),
  );
  await tester.pumpAndSettle();
}

List<PsLine> _lines(WidgetTester tester) => [
  for (final passage in tester.widgetList<PsPassage>(find.byType(PsPassage)))
    for (final paragraph in passage.paragraphs) ...paragraph,
];

void main() {
  testWidgets('tapping a spoken line only offers to play from it', (
    tester,
  ) async {
    final fakes = _fakes();
    await _openReader(tester, fakes);

    await _tapParagraph(tester, '『你敢胡说！』');
    expect(find.text('从这里播放'), findsOneWidget);
    expect(fakes.listening.calls, isEmpty);

    // Dismissing the menu leaves playback alone.
    await tester.tapAt(const Offset(5, 400));
    await tester.pumpAndSettle();
    expect(find.text('从这里播放'), findsNothing);
    expect(fakes.listening.calls, isEmpty);
  });

  testWidgets('play from here opens the chapter at that line', (tester) async {
    final fakes = _fakes();
    await _openReader(tester, fakes);

    await _tapParagraph(tester, '『你敢胡说！』');
    await tester.tap(find.text('从这里播放'));
    await tester.pumpAndSettle();

    expect(fakes.listening.opens, [(_bookId, 1, _lineOf(1))]);
  });

  testWidgets('non-story text offers nothing and is never lit', (tester) async {
    final fakes = _fakes();
    await _openReader(tester, fakes);

    await _tapParagraph(tester, '（本章由某某书屋整理）');
    expect(find.text('从这里播放'), findsNothing);

    fakes.listening.value = _playing(active: [0, _lineOf(1)]);
    await tester.pumpAndSettle();
    final lines = _lines(tester);
    final note = lines.firstWhere((l) => l.text == '（本章由某某书屋整理）');
    expect(note.skip, isTrue);
    expect(note.current, isFalse);
    final spoken = lines.where((l) => l.current).toList();
    expect(spoken.map((l) => l.text), ['『你敢胡说！』赵太爷说。']);
    expect(spoken.single.speaker, '赵太爷');
  });

  testWidgets('the reader follows the spoken line into view', (tester) async {
    final fakes = _fakes();
    await _openReader(tester, fakes);
    const far = '（36）';
    expect(_paragraph(far).hitTestable(), findsNothing);

    fakes.listening.value = _playing(active: [_lineOf(38)]);
    await tester.pumpAndSettle();

    expect(_paragraph(far).hitTestable(), findsOneWidget);
    final top = tester.getTopLeft(_paragraph(far)).dy;
    expect(top, greaterThan(0));
    expect(top, lessThan(tester.view.physicalSize.height / 3 * 0.75));
  });

  testWidgets('the reader can start listening at its chapter', (tester) async {
    final fakes = _fakes();
    await _openReader(tester, fakes);

    await tester.tap(find.text('听这一章'));
    await tester.pump();
    expect(fakes.listening.opens, [(_bookId, 1, null)]);
  });

  testWidgets('a book page resumes from the bookmark', (tester) async {
    final fakes = _fakes();
    fakes.listening.bookmarks[_bookId] = const ListeningBookmark(
      bookId: _bookId,
      chapter: 2,
      line: 4,
      progress: 0.5,
    );
    await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
    expect(find.text('听到第 2 章'), findsOneWidget);
    final item = tester.widget<PsShelfItem>(find.byType(PsShelfItem));
    expect(item.progress, 0.5);

    await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续听 · 第 2 章'));
    await tester.pumpAndSettle();
    // No chapter: the service restores the bookmark itself.
    expect(fakes.listening.opens, [(_bookId, null, null)]);
  });

  testWidgets('the shelf docks the player while a book is open', (
    tester,
  ) async {
    final fakes = _fakes();
    await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
    expect(find.byType(PsMiniPlayer), findsNothing);

    fakes.listening.value = _playing();
    await tester.pumpAndSettle();
    expect(find.byType(PsMiniPlayer), findsOneWidget);
    expect(find.text('AI 合成'), findsOneWidget);

    await tester.tap(find.byTooltip('暂停'));
    await tester.tap(find.byTooltip('下一句'));
    expect(fakes.listening.calls, ['pause', 'nextLine']);
  });

  testWidgets('player controls call the matching commands', (tester) async {
    final fakes = _fakes();
    fakes.listening.value = _playing(active: [_lineOf(1)]);
    await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);

    await tester.tap(find.byType(PsMiniPlayer));
    await tester.pumpAndSettle();
    expect(find.text('正在听'), findsOneWidget);
    // The line being read is shown large.
    expect(find.text('『你敢胡说！』赵太爷说。'), findsOneWidget);
    // No chapter before the first.
    final first = tester.widget<PsIconButton>(
      find.ancestor(
        of: find.byTooltip('上一章'),
        matching: find.byType(PsIconButton),
      ),
    );
    expect(first.onPressed, isNull);

    fakes.listening.value = _playing(chapter: 2, chapterCount: 3);
    await tester.pumpAndSettle();
    final calls = fakes.listening.calls..clear();
    await tester.tap(find.byTooltip('上一章'));
    await tester.tap(find.byTooltip('上一句'));
    await tester.tap(find.byTooltip('暂停'));
    await tester.tap(find.byTooltip('下一句'));
    await tester.tap(find.byTooltip('下一章'));
    expect(calls, [
      'previousChapter',
      'previousLine',
      'pause',
      'nextLine',
      'nextChapter',
    ]);

    await tester.tap(find.byType(Slider));
    await tester.pumpAndSettle();
    expect(fakes.listening.seeks, hasLength(1));
    expect(
      fakes.listening.seeks.single.inSeconds,
      closeTo(const Duration(minutes: 5).inSeconds, 20),
    );

    await tester.tap(find.byTooltip('播放速度'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5×'));
    await tester.pumpAndSettle();
    expect(fakes.listening.speeds, [1.5]);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('睡眠定时'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 分钟后'));
    await tester.pumpAndSettle();
    expect(fakes.listening.sleepTimers, [const Duration(minutes: 30)]);
    expect(fakes.listening.sleepAfterChapter, [false]);

    await tester.tap(find.byTooltip('睡眠定时'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('听完本章'));
    await tester.pumpAndSettle();
    expect(fakes.listening.sleepTimers.last, isNull);
    expect(fakes.listening.sleepAfterChapter.last, isTrue);
  });

  testWidgets('choosing a chapter in the player opens it', (tester) async {
    final fakes = _fakes();
    fakes.listening.value = _playing();
    await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
    await tester.tap(find.byType(PsMiniPlayer));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第二章　优胜记略'));
    await tester.pumpAndSettle();
    expect(fakes.listening.opens, [(_bookId, 2, null)]);
  });

  testWidgets('system speech is labelled and its errors explained', (
    tester,
  ) async {
    final fakes = _fakes();
    fakes.listening.value = _playing(
      source: ListeningSource.system,
      duration: Duration.zero,
      error: 'systemVoiceUnavailable',
    );
    await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
    expect(find.text('系统朗读'), findsOneWidget);

    await tester.tap(find.byType(PsMiniPlayer));
    await tester.pumpAndSettle();
    expect(find.text('系统朗读'), findsOneWidget);
    expect(find.textContaining('没有可用的朗读声音'), findsOneWidget);
    expect(find.text('systemVoiceUnavailable'), findsNothing);
    // Without a known duration the player counts sentences, not time.
    expect(find.byType(Slider), findsNothing);
    expect(find.text('第 1 / 84 句'), findsOneWidget);

    fakes.listening.value = _playing(error: 'endOfBook');
    await tester.pumpAndSettle();
    expect(find.text('全书听完了'), findsOneWidget);

    fakes.listening.value = const ListeningState();
    await tester.pumpAndSettle();
    expect(find.text('现在没有在听的书'), findsOneWidget);
  });

  testWidgets('the player reads in English too', (tester) async {
    final fakes = _fakes();
    fakes.listening.value = _playing();
    await pumpApp(
      tester,
      MemoryBookshelf(books: [_book]),
      fakes,
      locale: const Locale('en'),
    );
    expect(find.text('AI voice'), findsOneWidget);
    await tester.tap(find.byType(PsMiniPlayer));
    await tester.pumpAndSettle();
    expect(find.text('NOW LISTENING'), findsOneWidget);
    expect(find.byTooltip('Next chapter'), findsOneWidget);
  });
}
