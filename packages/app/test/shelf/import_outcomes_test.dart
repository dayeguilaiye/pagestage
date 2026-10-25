import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/bookshelf.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _aq = MemoryBook(
  title: '阿Q正传',
  chapters: [
    MemoryChapter('第一章　序', ['我要给阿Q做正传。']),
  ],
);

ShelfBook _book(MemoryBookshelf shelf) => ShelfBook(
  id: 'memory-1',
  title: '阿Q正传',
  language: BookLanguage.chinese,
  chapterCount: 7,
);

Future<void> _import(
  WidgetTester tester,
  MemoryImport onImport, {
  Locale locale = const Locale('zh', 'CN'),
}) async {
  final shelf = MemoryBookshelf(books: [_aq], onImport: onImport);
  await pumpApp(tester, shelf, Fakes(), locale: locale);
  await tester.tap(
    find.byTooltip(locale.languageCode == 'zh' ? '导入' : 'Import'),
  );
  await tester.pumpAndSettle();
}

Future<void> _dismissToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an updated book reports added and changed chapters', (
    tester,
  ) async {
    await _import(
      tester,
      (shelf) => BookUpdated(
        _book(shelf),
        addedChapters: 3,
        changedChapters: const [4, 5],
      ),
    );
    expect(find.text('《阿Q正传》已更新：新增 3 章，2 章内容有变化'), findsOneWidget);
    // Still one entry: an update is not a second book.
    expect(find.byType(PsShelfItem), findsOneWidget);
    await _dismissToast(tester);
  });

  testWidgets('an update with nothing new says so', (tester) async {
    await _import(
      tester,
      (shelf) => BookUpdated(
        _book(shelf),
        addedChapters: 0,
        changedChapters: const [],
      ),
    );
    expect(find.text('《阿Q正传》已经是最新的，没有变化'), findsOneWidget);
    await _dismissToast(tester);
  });

  testWidgets('updates read in English with plurals', (tester) async {
    await _import(
      tester,
      (shelf) => BookUpdated(
        _book(shelf),
        addedChapters: 1,
        changedChapters: const [2, 3],
      ),
      locale: const Locale('en'),
    );
    expect(
      find.text('Updated “阿Q正传”: 1 chapter added, 2 chapters changed'),
      findsOneWidget,
    );
    await _dismissToast(tester);
  });

  testWidgets('a DRM-protected EPUB gets its own explanation', (tester) async {
    await _import(
      tester,
      (_) => const ImportFailed('红楼梦.epub', ImportFailure.drmProtected),
    );
    expect(find.text('「红楼梦.epub」有 DRM 版权保护'), findsOneWidget);
    expect(find.textContaining('没有 DRM 的 EPUB 或 TXT'), findsOneWidget);
    expect(find.byType(PsShelfItem), findsOneWidget);

    // The banner offers another try.
    expect(find.text('换一个文件'), findsOneWidget);
  });

  testWidgets('the empty shelf names the formats it takes', (tester) async {
    await pumpApp(tester, MemoryBookshelf(), Fakes());
    expect(find.textContaining('TXT 或无 DRM 的 EPUB'), findsOneWidget);
  });
}
