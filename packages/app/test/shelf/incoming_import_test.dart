import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/incoming_files.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/l10n/app_localizations.dart';
import 'package:pagestage_app/shelf/bookshelf.dart';
import 'package:pagestage_app/shelf/incoming_import.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

const _channel = MethodChannel('pagestage/incoming');

const _aq = MemoryBook(
  title: '阿Q正传',
  chapters: [
    MemoryChapter('第一章　序', ['我要给阿Q做正传。']),
  ],
);

const _aqOnShelf = ShelfBook(
  id: 'memory-1',
  title: '阿Q正传',
  language: BookLanguage.chinese,
  chapterCount: 1,
);

/// The platform side of the channel, as iOS and Android keep it.
class _Platform {
  /// The methods Dart called.
  final calls = <String>[];

  /// Copies kept until Dart is ready for them.
  final waiting = <String>[];
}

_Platform _platform(WidgetTester tester, {List<String> waiting = const []}) {
  final platform = _Platform()..waiting.addAll(waiting);
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_channel, (call) async {
    platform.calls.add(call.method);
    if (call.method != 'ready') return null;
    final handed = [...platform.waiting];
    platform.waiting.clear();
    return handed;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
  return platform;
}

/// Another app opens a file while pagestage runs.
void _open(WidgetTester tester, String path) => unawaited(
  tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _channel.name,
    _channel.codec.encodeMethodCall(MethodCall('open', path)),
    null,
  ),
);

/// A private folder like the app's caches.
Directory _caches() {
  final caches = Directory.systemTemp.createTempSync('incoming-');
  addTearDown(() => caches.deleteSync(recursive: true));
  return caches;
}

/// A copy in the inbox, where the platform leaves it.
String _copy(Directory caches, String id, String name) =>
    (File('${caches.path}/incoming/$id/$name')
          ..createSync(recursive: true)
          ..writeAsStringSync('第一章\n我要给阿Q做正传。'))
        .path;

Future<void> _pump(
  WidgetTester tester,
  Bookshelf shelf, {
  bool enabled = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: PsTheme.light,
      locale: const Locale('zh', 'CN'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: IncomingImport(
        bookshelf: shelf,
        enabled: enabled,
        child: const Scaffold(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inDialog(String text) =>
    find.descendant(of: find.byType(PsDialog), matching: find.text(text));

/// Lets a toast time out so no timer is left pending.
Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a file that launched the app comes in once Dart is ready', (
    tester,
  ) async {
    final caches = _caches();
    final path = _copy(caches, 'a', '阿Q正传.txt');
    final platform = _platform(tester, waiting: [path]);
    final shelf = MemoryBookshelf(
      onImport: (shelf) => BookImported(shelf.add(_aq)),
    );
    await _pump(tester, shelf);

    expect(platform.calls, ['ready']);
    expect(shelf.importedPaths, [path]);
    expect(find.text('已导入《阿Q正传》'), findsOneWidget);
    // The library keeps the text itself; the inbox copy is gone.
    expect(File(path).existsSync(), isFalse);
    expect(Directory('${caches.path}/incoming/a').existsSync(), isFalse);
    await _settleToast(tester);
  });

  testWidgets('files that arrive later wait for the one before and its '
      'question', (tester) async {
    final caches = _caches();
    _platform(tester);
    final shelf = MemoryBookshelf(
      books: [_aq],
      onReplace: (confirm) async => await confirm('阿Q正传')
          ? const PackageImported(
              _aqOnShelf,
              scriptChapters: 2,
              audioChapters: 0,
              replaced: true,
            )
          : const ImportCancelled(),
    );
    await _pump(tester, shelf);
    final first = '${caches.path}/incoming/1/阿Q正传.script.pagestage';
    final second = '${caches.path}/incoming/2/阿Q正传.script.pagestage';

    _open(tester, first);
    await tester.pumpAndSettle();
    expect(find.text('替换《阿Q正传》？'), findsOneWidget);
    _open(tester, second);
    await tester.pumpAndSettle();
    expect(shelf.importedPaths, [first]);

    await tester.tap(_inDialog('取消'));
    await tester.pumpAndSettle();
    expect(shelf.importedPaths, [first, second]);
    expect(find.text('替换《阿Q正传》？'), findsOneWidget);

    await tester.tap(_inDialog('替换'));
    await tester.pumpAndSettle();
    expect(find.text('已导入《阿Q正传》：2 章剧本'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('a file that cannot come in is explained before the next one', (
    tester,
  ) async {
    final caches = _caches();
    final pdf = _copy(caches, 'a', '红楼梦.pdf');
    final txt = _copy(caches, 'b', '阿Q正传.txt');
    _platform(tester, waiting: [pdf, txt]);
    var imports = 0;
    final shelf = MemoryBookshelf(
      onImport: (shelf) => imports++ == 0
          ? const ImportFailed('红楼梦.pdf', ImportFailure.unsupportedFormat)
          : BookImported(shelf.add(_aq)),
    );
    await _pump(tester, shelf);

    expect(_inDialog('不支持「红楼梦.pdf」的格式'), findsOneWidget);
    expect(find.textContaining('TXT、没有 DRM 的 EPUB'), findsOneWidget);
    expect(shelf.importedPaths, [pdf]);
    expect(File(pdf).existsSync(), isFalse);

    await tester.tap(_inDialog('知道了'));
    await tester.pumpAndSettle();
    expect(find.byType(PsDialog), findsNothing);
    expect(shelf.importedPaths, [pdf, txt]);
    expect(find.text('已导入《阿Q正传》'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('what could not be handed over is asked for again when the '
      'app comes back', (tester) async {
    final caches = _caches();
    final platform = _platform(tester);
    final shelf = MemoryBookshelf(
      onImport: (shelf) => BookImported(shelf.add(_aq)),
    );
    await _pump(tester, shelf);
    final path = _copy(caches, 'a', '阿Q正传.txt');
    platform.waiting.add(path);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(platform.calls, ['ready', 'ready']);
    expect(shelf.importedPaths, [path]);
    expect(find.text('已导入《阿Q正传》'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('turned off, it leaves files with the platform', (tester) async {
    final platform = _platform(tester, waiting: ['/elsewhere/阿Q正传.txt']);
    final shelf = MemoryBookshelf(
      onImport: (shelf) => BookImported(shelf.add(_aq)),
    );
    await _pump(tester, shelf, enabled: false);
    expect(platform.calls, isEmpty);
    expect(platform.waiting, ['/elsewhere/阿Q正传.txt']);
    expect(shelf.importedPaths, isEmpty);
  });

  test('only copies in an inbox are removed', () {
    final caches = _caches();
    final copy = _copy(caches, 'a', '阿Q正传.txt');
    final own = File('${caches.path}/books/阿Q正传.txt')
      ..createSync(recursive: true);
    final files = IncomingFiles();
    files.discard(copy);
    files.discard(own.path);
    expect(File(copy).existsSync(), isFalse);
    expect(Directory('${caches.path}/incoming/a').existsSync(), isFalse);
    expect(Directory('${caches.path}/incoming').existsSync(), isTrue);
    expect(own.existsSync(), isTrue);
  });
}
