import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/bookshelf.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _bookId = 'memory-1';

final _book = MemoryBook(
  title: '阿Q正传',
  chapters: [
    MemoryChapter('第一章　序', const [
      '我要给阿Q做正传。',
    ], state: ChapterState.synthesized),
    const MemoryChapter('第二章　优胜记略', ['阿Q不独是姓名籍贯有些渺茫。']),
  ],
);

Finder _shelfBook(String title) => find.widgetWithText(PsShelfItem, title);

Finder _inDialog(String text) =>
    find.descendant(of: find.byType(PsDialog), matching: find.text(text));

Future<void> _openBook(WidgetTester tester, Fakes fakes) async {
  reduceMotion(tester);
  await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
  await tester.tap(_shelfBook('阿Q正传'));
  await tester.pumpAndSettle();
}

Future<void> _openShare(WidgetTester tester) async {
  await tester.tap(find.byTooltip('更多'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('分享'));
  await tester.pumpAndSettle();
}

/// Lets a toast time out so no timer is left pending.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  group('importing a package', () {
    testWidgets('an audio package says what arrived ready to hear', (
      tester,
    ) async {
      final shelf = MemoryBookshelf(
        onImport: (shelf) => PackageImported(
          shelf.add(_book),
          scriptChapters: 2,
          audioChapters: 1,
          replaced: false,
        ),
      );
      await pumpApp(tester, shelf, Fakes());
      await tester.tap(find.text('导入一本书'));
      await tester.pumpAndSettle();
      expect(_shelfBook('阿Q正传'), findsOneWidget);
      expect(find.text('已导入《阿Q正传》：2 章剧本，1 章可以直接听'), findsOneWidget);
      await _settleToast(tester);
    });

    testWidgets('a script package says how much is already directed', (
      tester,
    ) async {
      final shelf = MemoryBookshelf(
        onImport: (shelf) => PackageImported(
          shelf.add(_book),
          scriptChapters: 2,
          audioChapters: 0,
          replaced: false,
        ),
      );
      await pumpApp(tester, shelf, Fakes());
      await tester.tap(find.text('导入一本书'));
      await tester.pumpAndSettle();
      expect(find.text('已导入《阿Q正传》：2 章剧本'), findsOneWidget);
      await _settleToast(tester);
    });

    testWidgets('a package for a book on the shelf asks before replacing', (
      tester,
    ) async {
      final answers = <bool>[];
      final shelf = MemoryBookshelf(
        books: [_book],
        onReplace: (confirm) async {
          answers.add(await confirm('阿Q正传'));
          return const ImportCancelled();
        },
      );
      await pumpApp(tester, shelf, Fakes());

      // The import spinner turns while the question is open, so the page
      // never settles until it is answered.
      Future<void> open() async {
        await tester.tap(find.byTooltip('导入'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      await open();
      expect(find.text('替换《阿Q正传》？'), findsOneWidget);
      await tester.tap(_inDialog('取消'));
      await tester.pumpAndSettle();

      await open();
      await tester.tap(_inDialog('替换'));
      await tester.pumpAndSettle();
      expect(answers, [false, true]);
    });

    testWidgets('a damaged package says so and leaves the shelf alone', (
      tester,
    ) async {
      final shelf = MemoryBookshelf(
        books: [_book],
        onImport: (_) =>
            const ImportFailed('坏掉的.pagestage', ImportFailure.invalidPackage),
      );
      await pumpApp(tester, shelf, Fakes());
      await tester.tap(find.byTooltip('导入'));
      await tester.pumpAndSettle();
      expect(find.text('「坏掉的.pagestage」不是有效的剧本包或有声包'), findsOneWidget);
      expect(find.text('全部 · 1 本'), findsOneWidget);
    });
  });

  group('sharing a book', () {
    testWidgets('offers the script package and the audio package', (
      tester,
    ) async {
      final fakes = Fakes(
        packages: FakePackages(
          const PackageContents(scriptChapters: 12, audioChapters: 5),
        ),
      );
      await _openBook(tester, fakes);
      await _openShare(tester);
      expect(find.text('分享《阿Q正传》'), findsOneWidget);
      expect(find.textContaining('12 章台词'), findsOneWidget);
      expect(find.textContaining('5 章音频'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('share-audio')));
      await tester.pumpAndSettle();
      expect(fakes.packages.shares, [(_bookId, true)]);
      // Handed to the system; the sheet is done.
      expect(find.text('分享《阿Q正传》'), findsNothing);

      await _openShare(tester);
      await tester.tap(find.byKey(const ValueKey('share-script')));
      await tester.pumpAndSettle();
      expect(fakes.packages.shares.last, (_bookId, false));
    });

    testWidgets('without voiced chapters only the script can go', (
      tester,
    ) async {
      final fakes = Fakes(
        packages: FakePackages(const PackageContents(scriptChapters: 3)),
      );
      await _openBook(tester, fakes);
      await _openShare(tester);
      expect(find.text('还没有配好音的章节。'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('share-audio')));
      await tester.pumpAndSettle();
      expect(fakes.packages.shares, isEmpty);
      expect(find.text('分享《阿Q正传》'), findsOneWidget);
    });

    testWidgets('a book nothing was directed for has nothing to share', (
      tester,
    ) async {
      await _openBook(tester, Fakes());
      await _openShare(tester);
      expect(find.textContaining('还没有可以分享的内容'), findsOneWidget);
      expect(find.byKey(const ValueKey('share-script')), findsNothing);
    });

    testWidgets('a failed export stays open and says so', (tester) async {
      final fakes = Fakes(
        packages: FakePackages(const PackageContents(scriptChapters: 3))
          ..shareFailure = Exception('/private/path'),
      );
      await _openBook(tester, fakes);
      await _openShare(tester);
      await tester.tap(find.byKey(const ValueKey('share-script')));
      await tester.pumpAndSettle();
      expect(find.text('没能打包，请再试一次'), findsOneWidget);
      expect(find.textContaining('/private'), findsNothing);
    });
  });

  group('expression', () {
    Future<void> openVoice(WidgetTester tester) async {
      await tester.tap(find.text('AI 配音'));
      await tester.pumpAndSettle();
    }

    testWidgets('is chosen per book beside reading the tags', (tester) async {
      final fakes = Fakes();
      await _openBook(tester, fakes);
      await openVoice(tester);
      expect(find.text('情绪'), findsOneWidget);
      expect(find.textContaining('按台词里的情绪和语气演。'), findsOneWidget);

      await tester.tap(find.text('平淡'));
      await tester.pumpAndSettle();
      expect(fakes.generation.expressionChanges, [
        (_bookId, BookExpressiveness.plain),
      ]);
      expect(find.textContaining('只分角色朗读'), findsOneWidget);
      // Reading the tags keeps its own choice.
      expect(fakes.generation.modeChanges, isEmpty);
    });

    testWidgets('a failed change goes back and says so', (tester) async {
      final fakes = Fakes()..generation.expressionFailure = Exception();
      await _openBook(tester, fakes);
      await openVoice(tester);
      await tester.tap(find.text('夸张'));
      await tester.pumpAndSettle();
      expect(find.text('没能保存，请再试一次'), findsOneWidget);
      expect(
        tester
            .widget<PsSegmentedControl<BookExpressiveness>>(
              find.byKey(const ValueKey('expressiveness')),
            )
            .value,
        BookExpressiveness.natural,
      );
    });
  });
}
