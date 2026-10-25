import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/listening/chapter_lines.dart';

ListeningLine _line(int index, String text, {bool nonStory = false}) =>
    ListeningLine(
      index: index,
      text: text,
      start: 0,
      end: text.length,
      nonStory: nonStory,
      speakerName: index == 2 ? '赵太爷' : null,
    );

void main() {
  test('newlines in line text split paragraphs, blank ones are dropped', () {
    final paragraphs = layoutLines([
      _line(0, '　　第一章', nonStory: true),
      _line(1, '\n\n'),
      _line(2, '　　『你敢胡说！』'),
      _line(3, '赵太爷说。\n'),
      _line(4, '阿Q不开口。'),
    ]);

    expect(paragraphs, hasLength(3));
    expect(paragraphs[0].single.text, '第一章');
    expect(paragraphs[0].single.nonStory, isTrue);
    expect(paragraphs[0].single.spoken, isFalse);
    expect([for (final s in paragraphs[1]) s.text], ['『你敢胡说！』', '赵太爷说。']);
    expect([for (final s in paragraphs[1]) s.line], [2, 3]);
    expect(paragraphs[1].first.speaker, '赵太爷');
    expect(paragraphs[2].single.line, 4);
  });

  test('a line across paragraphs keeps its index and one cue', () {
    final paragraphs = layoutLines([_line(2, '『第一段\n第二段』')]);
    expect(paragraphs, hasLength(2));
    expect(paragraphs[0].single.line, 2);
    expect(paragraphs[1].single.line, 2);
    expect(paragraphs[0].single.speaker, '赵太爷');
    expect(paragraphs[1].single.speaker, isNull);
  });

  test('plain paragraphs are never spoken', () {
    final paragraphs = plainParagraphs(['一', '二']);
    expect(paragraphs.expand((p) => p).any((s) => s.spoken), isFalse);
  });
}
