import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/bookshelf.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _bookId = 'memory-1';

final _paragraphs = ['『你敢胡说！』', '赵太爷说。', '阿Q不开口。'];

final _book = MemoryBook(
  title: '阿Q正传',
  chapters: [
    MemoryChapter('第一章　序', _paragraphs, state: ChapterState.synthesized),
    const MemoryChapter('第二章　优胜记略', ['阿Q不独是姓名籍贯有些渺茫。']),
  ],
);

const _cast = CastState(
  bookId: _bookId,
  profiledThrough: 2,
  chapterCount: 2,
  status: ProfilingStatus.complete,
  members: [
    CastMember(id: 'narrator', name: 'Narrator', kind: CastMemberKind.narrator),
    CastMember(
      id: 'zhao',
      name: '赵太爷',
      kind: CastMemberKind.character,
      provider: 'minimax',
    ),
    CastMember(id: 'aq', name: '阿Q', kind: CastMemberKind.character),
  ],
);

/// The script line of paragraph [k] in [linesFor].
int _lineOf(int k) => 2 * k;

/// A directed chapter: the first line was given to 阿Q by mistake.
Fakes _fakes({bool directed = true}) {
  final fakes = Fakes(
    casts: FakeCasts(state: _cast),
    voices: FakeVoices(
      presetOptions: const [
        VoiceOption(id: 'minimax:a', name: 'Voice A', provider: 'minimax'),
      ],
    ),
  );
  fakes.listening.chapterLines[(_bookId, 1)] = linesFor(
    _paragraphs,
    speakers: {
      _lineOf(0): '阿Q',
      _lineOf(1): 'Narrator',
      _lineOf(2): 'Narrator',
    },
    speakerIds: directed
        ? {_lineOf(0): 'aq', _lineOf(1): 'narrator', _lineOf(2): 'narrator'}
        : const {},
    directed: directed,
  );
  return fakes;
}

Future<void> _openReader(WidgetTester tester, Fakes fakes) async {
  reduceMotion(tester);
  await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
  await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('第一章　序'));
  await tester.pumpAndSettle();
}

Future<void> _tapParagraph(WidgetTester tester, String text) async {
  await tester.tapAt(
    tester.getTopLeft(find.textContaining(text, findRichText: true)) +
        const Offset(48, 12),
  );
  await tester.pumpAndSettle();
}

Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a directed line offers its speaker\'s voice and its speaker', (
    tester,
  ) async {
    final fakes = _fakes();
    await _openReader(tester, fakes);
    await _tapParagraph(tester, '『你敢胡说！』');
    expect(find.text('从这里播放'), findsOneWidget);
    expect(find.text('换阿Q的声音'), findsOneWidget);
    expect(find.text('这句不是阿Q说的'), findsOneWidget);
    // Opening the menu changes nothing.
    expect(fakes.scripts.reassignments, isEmpty);
    expect(fakes.listening.calls, isEmpty);
  });

  testWidgets('narration is named as the narrator', (tester) async {
    await _openReader(tester, _fakes());
    await _tapParagraph(tester, '赵太爷说。');
    expect(find.text('换旁白的声音'), findsOneWidget);
    expect(find.text('这句不是旁白说的'), findsOneWidget);
  });

  testWidgets('text read by the system voice has nobody to correct', (
    tester,
  ) async {
    await _openReader(tester, _fakes(directed: false));
    await _tapParagraph(tester, '『你敢胡说！』');
    expect(find.text('从这里播放'), findsOneWidget);
    expect(find.textContaining('的声音'), findsNothing);
    expect(find.textContaining('说的'), findsNothing);
  });

  testWidgets('the reader says who really speaks the line', (tester) async {
    final fakes = _fakes();
    await _openReader(tester, fakes);
    await _tapParagraph(tester, '『你敢胡说！』');
    await tester.tap(find.text('这句不是阿Q说的'));
    await tester.pumpAndSettle();

    expect(find.text('这句是谁说的？'), findsOneWidget);
    expect(find.text('改了之后，这一章只有这一句重新配音。'), findsOneWidget);
    // Whoever has the line now cannot be chosen again.
    await tester.tap(find.byKey(const ValueKey('speaker-aq')));
    await tester.pumpAndSettle();
    expect(fakes.scripts.reassignments, isEmpty);

    await tester.tap(find.byKey(const ValueKey('speaker-zhao')));
    await tester.pumpAndSettle();
    expect(fakes.scripts.reassignments, [(_bookId, 1, _lineOf(0), 'zhao')]);
    expect(find.text('这句是谁说的？'), findsNothing);
    expect(find.text('已改为赵太爷'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('imported audio warns that the whole chapter is voiced again', (
    tester,
  ) async {
    final fakes = _fakes()..scripts.imported.add((_bookId, 1));
    await _openReader(tester, fakes);
    await _tapParagraph(tester, '『你敢胡说！』');
    await tester.tap(find.text('这句不是阿Q说的'));
    await tester.pumpAndSettle();
    expect(find.textContaining('这一章的音频是导入的'), findsOneWidget);
  });

  testWidgets('a failed correction stays open and says so', (tester) async {
    final fakes = _fakes()..scripts.failure = Exception();
    await _openReader(tester, fakes);
    await _tapParagraph(tester, '『你敢胡说！』');
    await tester.tap(find.text('这句不是阿Q说的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('speaker-narrator')));
    await tester.pumpAndSettle();
    expect(find.text('没能修改，请再试一次'), findsOneWidget);
    expect(find.text('这句是谁说的？'), findsOneWidget);
  });

  testWidgets('changing the voice opens that speaker\'s voices', (
    tester,
  ) async {
    final fakes = _fakes();
    await _openReader(tester, fakes);
    await _tapParagraph(tester, '『你敢胡说！』');
    await tester.tap(find.text('换阿Q的声音'));
    await tester.pumpAndSettle();
    expect(find.text('给阿Q换声音'), findsOneWidget);
    expect(find.text('Voice A'), findsOneWidget);
    // Nothing plays or changes until a voice is chosen.
    expect(fakes.voices.selectedPresets, isEmpty);
    expect(fakes.listening.calls, isEmpty);
  });
}
