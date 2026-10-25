import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagestage_app/app.dart';
import 'package:pagestage_app/application/diagnostics.dart';
import 'package:pagestage_app/storage.dart';
import 'package:pagestage_app/playback/just_audio_engine.dart';
import 'support/aac_fixture.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/test/support/epub_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native library imports EPUB updates and exports private diagnostics',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final parent = await Directory(
        '${support.path}/integration-final',
      ).create(recursive: true);
      final directory = await parent.createTemp();
      final epub = File('${directory.path}/book.epub');
      await epub.writeAsBytes(
        epubFixture(
          bodies: {
            '1.xhtml': '<h1>Chapter 1</h1><p>First.</p>',
            '2.xhtml': '<h1>Chapter 2</h1><p>Second.</p>',
            '3.xhtml': '<h1>Chapter 3</h1><p>Third.</p>',
          },
        ),
      );
      final storage = await AppStorage.open(
        directory: directory,
        pickFile: () async => epub.path,
      );
      final first = await storage.library.importBook() as BookImported;
      await epub.writeAsBytes(
        epubFixture(
          bodies: {
            '1.xhtml': '<h1>Chapter 1</h1><p>First.</p>',
            '2.xhtml': '<h1>Chapter 2</h1><p>Second.</p>',
            '3.xhtml': '<h1>Chapter 3</h1><p>Third.</p>',
            '4.xhtml': '<h1>Chapter 4</h1><p>Fourth.</p>',
          },
        ),
      );
      final update = await storage.library.importBook() as BookUpdated;
      expect(update.book.id, first.book.id);
      expect(update.addedChapters, 1);
      await tester.pumpWidget(
        PagestageApp(
          bookshelf: storage.library,
          readingSettings: storage.readingSettings,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(first.book.id)), findsOneWidget);
      expect((await storage.library.chapters(first.book.id)), hasLength(4));
      final compressed = await File(
        '${directory.path}/tone.m4a',
      ).writeAsBytes(base64Decode(aacFixture));
      final engine = JustAudioEngine();
      await engine.load(compressed.path, const Duration(seconds: 1));
      await engine.play();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(engine.state.position, greaterThan(Duration.zero));
      await engine.pause();
      await engine.seek(const Duration(milliseconds: 500));
      expect(engine.state.position.inMilliseconds, closeTo(500, 100));
      await engine.dispose();
      final native = NativeDiagnostics();
      final snapshot = await native.snapshot();
      expect(snapshot['platform'], Platform.isIOS ? 'ios' : 'android');
      expect(snapshot['appVersion'], isNotEmpty);
      expect(snapshot['crashes'], isA<List>());
      const marker = 'sk-native-fixture-key PRIVATE_BOOK_BODY';
      final log = DiagnosticLog(Directory('${support.path}/diagnostics'));
      await log.record(StateError(marker), StackTrace.current);
      final report = await log.report();
      final contents = await report.readAsString();
      expect(contents, isNot(contains(marker)));
      final json = jsonDecode(contents) as Map;
      expect(json['appVersion'], '0.1.0');
      expect(json['platform'], snapshot['platform']);
      await tester.pumpWidget(const SizedBox());
      await storage.close();
      await directory.delete(recursive: true);
      await log.export();
      // Open the real native share sheet, without choosing a destination.
      await Future<void>.delayed(const Duration(seconds: 2));
    },
  );
}
