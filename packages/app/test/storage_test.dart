import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/reading_settings.dart';
import 'package:pagestage_app/storage.dart';

void main() {
  test(
    'books and the final reading edit survive closing and reopening the app',
    () async {
      final dir = await Directory.systemTemp.createTemp('app-storage-');
      addTearDown(() => dir.delete(recursive: true));
      final source = await File(
        '${dir.path}/novel.txt',
      ).writeAsString('Chapter 1\nHello.');
      var storage = await AppStorage.open(
        directory: dir,
        pickFile: () async => source.path,
      );
      await storage.library.importBook();
      for (var size = 14.0; size <= 26; size++) {
        storage.readingSettings.update(
          ReadingPreferences(
            fontSize: size,
            themeMode: ThemeMode.dark,
            lineSpacing: PsLineSpacing.loose,
          ),
        );
      }
      await storage.close();
      storage = await AppStorage.open(directory: dir);
      expect((await storage.library.books()).single.title, 'novel');
      expect(
        storage.readingSettings.value,
        const ReadingPreferences(
          fontSize: 26,
          themeMode: ThemeMode.dark,
          lineSpacing: PsLineSpacing.loose,
        ),
      );
      await storage.close();
    },
  );
}
