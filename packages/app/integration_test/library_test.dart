import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagestage_app/app.dart';
import 'package:pagestage_app/shelf/reading_settings.dart';
import 'package:pagestage_app/storage.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native private storage imports books and restores reading preferences',
    (tester) async {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/integration-book.txt');
      await file.writeAsBytes([0xb5, 0xda, 0x31, 0xd5, 0xc2, 0x0a, 0xb7, 0xe7]);
      var storage = await AppStorage.open(pickFile: () async => file.path);
      final imported = await storage.library.importBook() as BookImported;
      expect(await storage.library.paragraphs(imported.book.id, 1), ['风']);
      storage.readingSettings.update(
        const ReadingPreferences(fontSize: 23, themeMode: ThemeMode.dark),
      );
      await storage.close();
      storage = await AppStorage.open();
      expect(storage.readingSettings.value.fontSize, 23);
      expect(storage.readingSettings.value.themeMode, ThemeMode.dark);
      await tester.pumpWidget(
        PagestageApp(
          bookshelf: storage.library,
          readingSettings: storage.readingSettings,
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(imported.book.id)), findsOneWidget);
      await storage.library.deleteBook(imported.book.id);
      await tester.pumpAndSettle();
      expect(find.text('integration-book'), findsNothing);
      expect(await file.exists(), isTrue);
      await tester.pumpWidget(const SizedBox());
      await storage.close();
      await file.delete();
    },
  );
}
