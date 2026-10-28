import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/app.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/bookshelf.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';
import 'package:pagestage_app/shelf/reading_settings.dart';

final _aq = MemoryBook(
  title: '阿Q正传',
  chapters: [
    MemoryChapter('第一章　序', [
      for (var i = 0; i < 40; i++) '我要给阿Q做正传，已经不止一两年了。（$i）',
    ], state: ChapterState.synthesized),
    MemoryChapter('第二章　优胜记略', [
      for (var i = 0; i < 40; i++) '阿Q不独是姓名籍贯有些渺茫。（$i）',
    ]),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  Bookshelf shelf, {
  Locale locale = const Locale('zh', 'CN'),
  ReadingSettings? settings,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    PagestageApp(
      bookshelf: shelf,
      readingSettings: settings ?? MemoryReadingSettings(),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

Finder _book(String title) => find.widgetWithText(PsShelfItem, title);

void main() {
  testWidgets('an imported book appears on the shelf', (tester) async {
    final shelf = MemoryBookshelf(
      onImport: (shelf) => BookImported(shelf.add(_aq)),
    );
    await _pump(tester, shelf);
    expect(find.text('书架还是空的'), findsOneWidget);

    await tester.tap(find.text('导入一本书'));
    await tester.pumpAndSettle();

    expect(_book('阿Q正传'), findsOneWidget);
    expect(find.text('共 2 章'), findsOneWidget);
    expect(find.text('已导入《阿Q正传》'), findsOneWidget);
    expect(find.text('书架还是空的'), findsNothing);
    // Let the toast time out.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a deleted book leaves the shelf', (tester) async {
    final shelf = MemoryBookshelf(books: [_aq]);
    await _pump(tester, shelf);

    await tester.longPress(_book('阿Q正传'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除《阿Q正传》？'), findsOneWidget);
    await tester.tap(find.text('删除这本书'));
    await tester.pumpAndSettle();

    expect(_book('阿Q正传'), findsNothing);
    expect(await shelf.books(), isEmpty);
    expect(find.text('书架还是空的'), findsOneWidget);
  });

  testWidgets('cancelling the delete keeps the book', (tester) async {
    final shelf = MemoryBookshelf(books: [_aq]);
    await _pump(tester, shelf);

    await tester.longPress(_book('阿Q正传'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(_book('阿Q正传'), findsOneWidget);
  });

  testWidgets('a failed import says why and leaves the shelf alone', (
    tester,
  ) async {
    final shelf = MemoryBookshelf(
      books: [_aq],
      onImport: (_) =>
          const ImportFailed('红楼梦.pdf', ImportFailure.unsupportedFormat),
    );
    await _pump(tester, shelf);

    await tester.tap(find.byTooltip('导入'));
    await tester.pumpAndSettle();

    expect(find.text('不支持「红楼梦.pdf」的格式'), findsOneWidget);
    expect(find.textContaining('TXT 和没有 DRM 的 EPUB'), findsOneWidget);
    expect(find.text('全部 · 1 本'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('不支持「红楼梦.pdf」的格式'), findsNothing);
  });

  testWidgets('a book opens to its contents, and a chapter to its text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, MemoryBookshelf(books: [_aq]));

    await tester.tap(_book('阿Q正传'));
    await tester.pumpAndSettle();
    expect(find.text('第一章　序'), findsOneWidget);
    expect(find.text('第二章　优胜记略'), findsOneWidget);
    // Chapters at rest, voiced or not, carry no mark.
    expect(find.byType(PsStatusMark), findsNothing);

    await tester.tap(find.text('第二章　优胜记略'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('阿Q不独是姓名籍贯有些渺茫。（0）', findRichText: true),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('the reader scrolls on into the next chapter and names it', (
    tester,
  ) async {
    await _pump(tester, MemoryBookshelf(books: [_aq]));
    await tester.tap(_book('阿Q正传'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第一章　序'));
    await tester.pumpAndSettle();

    final bar = find.byType(PsNavBar);
    expect(
      find.descendant(of: bar, matching: find.text('第一章　序')),
      findsOneWidget,
    );
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: bar, matching: find.text('第二章　优胜记略')),
      findsOneWidget,
    );
  });

  testWidgets('reading settings restyle the text in place', (tester) async {
    final settings = MemoryReadingSettings();
    await _pump(tester, MemoryBookshelf(books: [_aq]), settings: settings);
    await tester.tap(_book('阿Q正传'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('第一章　序'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('阅读设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('宽松'));
    await tester.tap(find.text('开'));
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pumpAndSettle();

    final passage = tester.widget<PsPassage>(find.byType(PsPassage).first);
    expect(passage.lineSpacing, PsLineSpacing.loose);
    expect(passage.fontSize, ReadingPreferences.maxFontSize);
    expect(settings.value.themeMode, ThemeMode.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('the interface follows the language it is given', (tester) async {
    await _pump(tester, MemoryBookshelf(), locale: const Locale('en'));
    expect(find.text('Your bookshelf is empty'), findsOneWidget);
    expect(find.text('Import a book'), findsOneWidget);
  });

  test('any Chinese gets the Chinese interface, anything else English', () {
    Locale resolve(List<Locale> preferred) =>
        PagestageApp.resolveLocale(preferred, PagestageApp.locales);
    expect(
      resolve(const [
        Locale('fr'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ]),
      const Locale('zh', 'CN'),
    );
    expect(
      resolve(const [Locale('en', 'GB'), Locale('zh')]),
      const Locale('en'),
    );
    expect(resolve(const [Locale('fr')]), const Locale('en'));
  });

  test('every string has both a Chinese and an English text', () {
    Set<String> keys(String locale) =>
        (jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
                as Map<String, Object?>)
            .keys
            .where((k) => !k.startsWith('@'))
            .toSet();
    expect(keys('en'), keys('zh'));
  });
}
