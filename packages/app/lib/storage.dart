import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:path_provider/path_provider.dart';

import 'shelf/reading_settings.dart';

/// Supplies platform resources to core. Screens use [library] directly.
class AppStorage {
  AppStorage._(this.store, this.library, this.readingSettings);
  final LocalStore store;
  final Library library;
  final SavedReadingSettings readingSettings;

  static Future<AppStorage> open({
    Directory? directory,
    Future<String?> Function()? pickFile,
  }) async {
    final root = directory ?? await getApplicationSupportDirectory();
    final store = LocalStore('${root.path}/pagestage.sqlite');
    try {
      return AppStorage._(
        store,
        Library(store, pickFile: pickFile ?? _pickTxt),
        await SavedReadingSettings.open(store),
      );
    } catch (_) {
      await store.close();
      rethrow;
    }
  }

  static Future<String?> _pickTxt() async => (await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'TXT',
        extensions: ['txt'],
        uniformTypeIdentifiers: ['public.plain-text'],
        mimeTypes: ['text/plain'],
      ),
    ],
  ))?.path;

  Future<void> close() async {
    await readingSettings.saved;
    readingSettings.dispose();
    await store.close();
  }
}
