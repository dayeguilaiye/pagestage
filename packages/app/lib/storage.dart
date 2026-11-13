import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:path_provider/path_provider.dart';

import 'shelf/reading_settings.dart';

/// Supplies platform resources to core. Screens use [library] directly.
class AppStorage {
  AppStorage._(this.directory, this.store, this.library, this.readingSettings);

  /// The app's private directory, holding the database and generated files.
  final Directory directory;
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
        root,
        store,
        Library(store, pickFile: pickFile ?? _pickBook),
        await SavedReadingSettings.open(store),
      );
    } catch (_) {
      await store.close();
      rethrow;
    }
  }

  static Future<String?> _pickBook() async => (await openFile(
    acceptedTypeGroups: const [
      // Packages have no registered type of their own, so the picker also
      // offers plain data; the library decides by extension and content.
      XTypeGroup(
        label: 'TXT / EPUB / pagestage',
        extensions: ['txt', 'epub', 'pagestage'],
        uniformTypeIdentifiers: [
          'public.plain-text',
          'org.idpf.epub-container',
          'public.data',
        ],
        mimeTypes: [
          'text/plain',
          'application/epub+zip',
          'application/zip',
          'application/octet-stream',
        ],
      ),
    ],
  ))?.path;

  Future<void> close() async {
    await readingSettings.saved;
    readingSettings.dispose();
    await store.close();
  }
}
