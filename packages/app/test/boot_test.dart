import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/app.dart';
import 'package:pagestage_app/boot.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';
import 'package:pagestage_app/shelf/reading_settings.dart';

void main() {
  testWidgets('a failure while opening shows what to do, and retry opens', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    var attempts = 0;
    await tester.pumpWidget(
      PagestageBoot(
        open: (_) async {
          attempts++;
          if (attempts == 1) throw StateError('keychain');
          return PagestageApp(
            bookshelf: MemoryBookshelf(),
            readingSettings: MemoryReadingSettings(),
            locale: const Locale('zh', 'CN'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('pagestage 没能打开'), findsOneWidget);
    expect(find.textContaining('书和设置都还在'), findsOneWidget);
    expect(find.textContaining('keychain'), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('pagestage 没能打开'), findsNothing);
    expect(find.byType(PagestageApp), findsOneWidget);
  });

  testWidgets('the first frame shows while opening', (tester) async {
    await tester.pumpWidget(
      PagestageBoot(
        open: (_) => Future.delayed(
          const Duration(seconds: 1),
          () => PagestageApp(
            bookshelf: MemoryBookshelf(),
            readingSettings: MemoryReadingSettings(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(PagestageApp), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(PagestageApp), findsOneWidget);
  });
}
