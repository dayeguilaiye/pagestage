import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/design/design.dart';

Widget _host(Widget child) => MaterialApp(
  theme: PsTheme.light,
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(20), child: child),
  ),
);

void main() {
  test('voice tones match the web design system', () {
    // Values from Pagestage.voiceTone in the design system bundle.
    expect(psVoiceTone('阿Q'), 3);
    expect(psVoiceTone('赵太爷'), 3);
    expect(psVoiceTone('旁白'), 5);
    expect(psVoiceTone('Mrs. Bennet'), 3);
    expect(psVoiceTone('阿Q正传'), 8);
    expect(psVoiceTone('Pride and Prejudice'), 5);
  });

  testWidgets('seals show the first character, the narrator shows 旁', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Row(
          children: [
            PsSeal(name: '赵太爷', tone: 3),
            PsSeal(name: 'mrs. Bennet'),
            PsSeal(narrator: true),
          ],
        ),
      ),
    );
    expect(find.text('赵'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
    expect(find.text('旁'), findsOneWidget);
  });

  testWidgets('tapping a line reports it and leaves the spotlight alone', (
    tester,
  ) async {
    final taps = <(int, int)>[];
    await tester.pumpWidget(
      _host(
        PsPassage(
          paragraphs: const [
            [
              PsLine('赵太爷愈看愈生气了，抢进几步说：'),
              PsLine('『你敢胡说！』', speaker: '赵太爷', current: true),
            ],
            [PsLine('阿Q不开口。')],
          ],
          onLineTap: (p, l, _) => taps.add((p, l)),
        ),
      ),
    );

    final second = tester.renderObject<RenderParagraph>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('阿Q不开口'),
      ),
    );
    // Offset 1 skips the paragraph indent placeholder.
    final box = second.getBoxesForSelection(
      const TextSelection(baseOffset: 1, extentOffset: 2),
    );
    await tester.tapAt(second.localToGlobal(box.first.toRect().center));
    await tester.pump();

    expect(taps, [(1, 0)]);
    expect(find.text('赵太爷'), findsOneWidget, reason: 'cue stays put');
  });

  testWidgets('chapter rows announce their state', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            PsChapterRow(
              index: 3,
              title: '第三章　续优胜记略',
              status: PsChapterStatus.directed,
            ),
          ],
        ),
      ),
    );
    expect(find.text('003'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('已导演')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the primary button is vermilion with on-vermilion text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PsButton(
          label: '生成本章',
          variant: PsButtonVariant.primary,
          onPressed: () {},
        ),
      ),
    );
    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, PsPalette.light.vermilion);
    expect(material.textStyle?.color, PsPalette.light.onVermilion);
  });
}
