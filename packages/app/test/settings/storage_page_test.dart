import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/settings/storage_page.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _mb = 1024 * 1024;

Future<Fakes> _openStorage(WidgetTester tester) async {
  final fakes = Fakes(
    audioStorage: FakeAudioStorage(const [
      BookStorageUsage(
        bookId: 'a',
        title: '阿Q正传',
        totalBytes: 120 * _mb,
        audioBytes: 100 * _mb,
      ),
      BookStorageUsage(
        bookId: 'b',
        title: '呐喊',
        totalBytes: 2 * _mb,
        audioBytes: 0,
      ),
    ]),
  );
  await pumpApp(tester, MemoryBookshelf(), fakes);
  await tester.tap(find.byTooltip('设置'));
  await tester.pumpAndSettle();
  final row = find.text('存储空间');
  await tester.scrollUntilVisible(
    row,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  return fakes;
}

Finder _clearButton(String title) => find.descendant(
  of: find.ancestor(of: find.text(title), matching: find.byType(PsListRow)),
  matching: find.widgetWithText(PsButton, '清理音频'),
);

void main() {
  test('sizes read naturally', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(120 * _mb), '120 MB');
  });

  testWidgets('each book shows what it uses and what can be cleared', (
    tester,
  ) async {
    await _openStorage(tester);
    expect(find.text('122 MB'), findsOneWidget); // total
    expect(find.text('100 MB'), findsOneWidget); // clearable
    expect(find.text('共 120 MB · 音频 100 MB'), findsOneWidget);
    expect(find.text('共 2.0 MB · 音频 0 B'), findsOneWidget);
    // Nothing to clear for a book without audio.
    expect(tester.widget<PsButton>(_clearButton('呐喊')).onPressed, isNull);
    expect(find.textContaining('正文、剧本和演员表都会保留'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation clears nothing', (tester) async {
    final fakes = await _openStorage(tester);
    await tester.tap(_clearButton('阿Q正传'));
    await tester.pumpAndSettle();
    expect(find.text('清理《阿Q正传》的音频？'), findsOneWidget);
    expect(find.textContaining('将释放 100 MB'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(fakes.audioStorage.cleared, isEmpty);
    expect(find.text('共 120 MB · 音频 100 MB'), findsOneWidget);
  });

  testWidgets('confirming clears the audio and refreshes', (tester) async {
    final fakes = await _openStorage(tester);
    await tester.tap(_clearButton('阿Q正传'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(PsDialog), matching: find.text('清理音频')),
    );
    await tester.pumpAndSettle();

    expect(fakes.audioStorage.cleared, ['a']);
    expect(find.text('共 20.0 MB · 音频 0 B'), findsOneWidget);
    expect(tester.widget<PsButton>(_clearButton('阿Q正传')).onPressed, isNull);
    expect(find.text('已清理《阿Q正传》的音频'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
