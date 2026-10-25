import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _bookId = 'memory-1';

final _book = MemoryBook(
  title: '阿Q正传',
  chapters: [
    const MemoryChapter('第一章　序', ['『你敢胡说！』赵太爷说。', '阿Q不开口。']),
  ],
);

List<ListeningLine> _lines(List<(String, String?, bool)> runs) {
  final out = <ListeningLine>[];
  var offset = 0;
  for (final (i, (text, speaker, nonStory)) in runs.indexed) {
    out.add(
      ListeningLine(
        index: i,
        text: text,
        start: offset,
        end: offset + text.length,
        speakerName: speaker,
        nonStory: nonStory,
      ),
    );
    offset += text.length;
  }
  return out;
}

/// What system speech reads: one line per sentence.
final _sentences = _lines([
  ('『你敢胡说！』', null, false),
  ('赵太爷说。', null, false),
  ('\n', null, true),
  ('阿Q不开口。', null, false),
]);

/// The directed script: the quote and its tag are one line, so every later
/// index moves.
final _script = _lines([
  ('『你敢胡说！』赵太爷说。', '赵太爷', false),
  ('\n', null, true),
  ('阿Q不开口。', null, false),
]);

/// A later revision splits the quote again, differently from system speech.
final _revised = _lines([
  ('『你敢胡说！』', '赵太爷', false),
  ('赵太爷说。', null, false),
  ('\n', null, true),
  ('阿Q', null, false),
  ('不开口。', null, false),
]);

ListeningState _state({
  required ListeningSource source,
  required int revision,
  required List<int> active,
}) => ListeningState(
  bookId: _bookId,
  bookTitle: '阿Q正传',
  chapter: 1,
  chapterTitle: '第一章　序',
  chapterCount: 1,
  source: source,
  lineRevision: revision,
  activeLines: active,
  playing: true,
);

Future<Fakes> _openReader(WidgetTester tester) async {
  final fakes = Fakes();
  fakes.listening.chapterLines[(_bookId, 1)] = _sentences;
  fakes.listening.value = _state(
    source: ListeningSource.system,
    revision: 0,
    active: [3],
  );
  reduceMotion(tester);
  await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
  await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PsChapterRow, '第一章　序'));
  await tester.pumpAndSettle();
  return fakes;
}

List<PsLine> _passageLines(WidgetTester tester) => [
  for (final passage in tester.widgetList<PsPassage>(find.byType(PsPassage)))
    for (final paragraph in passage.paragraphs) ...paragraph,
];

List<String> _texts(WidgetTester tester) => [
  for (final line in _passageLines(tester)) line.text,
];

List<String> _lit(WidgetTester tester) => [
  for (final line in _passageLines(tester))
    if (line.current) line.text,
];

void main() {
  testWidgets('system sentences give way to the directed script', (
    tester,
  ) async {
    final fakes = await _openReader(tester);
    expect(_texts(tester), ['『你敢胡说！』', '赵太爷说。', '阿Q不开口。']);
    expect(_lit(tester), ['阿Q不开口。']);

    // Generated audio arrives with a different segmentation.
    fakes.listening.chapterLines[(_bookId, 1)] = _script;
    fakes.listening.value = _state(
      source: ListeningSource.synthesized,
      revision: 1,
      active: [2],
    );
    await tester.pumpAndSettle();

    expect(_texts(tester), ['『你敢胡说！』赵太爷说。', '阿Q不开口。']);
    // Index 2 is the last sentence in the new script, not the newline.
    expect(_lit(tester), ['阿Q不开口。']);

    // Play from here uses the new index of the merged line.
    await tester.tapAt(
      tester.getTopLeft(find.textContaining('『你敢胡说！』', findRichText: true)) +
          const Offset(48, 12),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('从这里播放'));
    await tester.pumpAndSettle();
    expect(fakes.listening.opens, [(_bookId, 1, 0)]);

    // Highlighting the merged line lights the whole of it.
    fakes.listening.value = _state(
      source: ListeningSource.synthesized,
      revision: 1,
      active: [0],
    );
    await tester.pumpAndSettle();
    expect(_lit(tester), ['『你敢胡说！』赵太爷说。']);
  });

  testWidgets('a late answer for an old revision never replaces a newer one', (
    tester,
  ) async {
    final fakes = await _openReader(tester);
    final answers = <Completer<List<ListeningLine>>>[];
    fakes.listening.onLines = (_, _) {
      final answer = Completer<List<ListeningLine>>();
      answers.add(answer);
      return answer.future;
    };

    fakes.listening.value = _state(
      source: ListeningSource.synthesized,
      revision: 1,
      active: [2],
    );
    await tester.pump();
    fakes.listening.value = _state(
      source: ListeningSource.synthesized,
      revision: 2,
      active: [4],
    );
    await tester.pump();
    expect(answers, hasLength(2));

    // While the new lines load, the old text stays but nothing is lit or
    // offered, since its indexes are out of date.
    expect(_texts(tester), ['『你敢胡说！』', '赵太爷说。', '阿Q不开口。']);
    expect(_lit(tester), isEmpty);

    answers[1].complete(_revised);
    await tester.pumpAndSettle();
    answers[0].complete(_script);
    await tester.pumpAndSettle();

    expect(_texts(tester), ['『你敢胡说！』', '赵太爷说。', '阿Q', '不开口。']);
    expect(_lit(tester), ['不开口。']);
  });

  testWidgets('a menu opened on old lines does not play the old index', (
    tester,
  ) async {
    final fakes = await _openReader(tester);
    await tester.tapAt(
      tester.getTopLeft(find.textContaining('『你敢胡说！』', findRichText: true)) +
          const Offset(48, 12),
    );
    await tester.pumpAndSettle();
    expect(find.text('从这里播放'), findsOneWidget);

    fakes.listening.chapterLines[(_bookId, 1)] = _script;
    fakes.listening.value = _state(
      source: ListeningSource.synthesized,
      revision: 1,
      active: [2],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('从这里播放'));
    await tester.pumpAndSettle();
    expect(fakes.listening.opens, isEmpty);
  });
}
