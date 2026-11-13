import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pagestage_core/pagestage_core.dart';

import 'contracts.dart';

/// Hands a file the app wrote to the system share sheet.
abstract interface class FileSharing {
  Future<void> share(String path);
}

class NativeFileSharing implements FileSharing {
  const NativeFileSharing();
  static const channel = MethodChannel('pagestage/files');
  @override
  Future<void> share(String path) =>
      channel.invokeMethod<void>('share', {'path': path});
}

/// Packs a book into [directory] and shares it. Only the latest export is
/// kept: the share sheet reads the file after this returns, so it is
/// removed when the next one is made.
class PackageController implements Packages {
  PackageController(this.store, {required this.directory, FileSharing? sharing})
    : sharing = sharing ?? const NativeFileSharing();
  final LocalStore store;
  final Directory directory;
  final FileSharing sharing;

  @override
  Future<PackageContents> contents(String bookId) async {
    final book = await Library(store).getBook(bookId);
    final mode = (await PerformanceRepository(store).get(bookId)).mode;
    final audio = AudioRepository(store);
    var scripts = 0, voiced = 0;
    for (final chapter in book.chapters) {
      final script = await ScriptRepository(store).get(bookId, chapter.number);
      if (script == null || script.sourceTextHash != chapter.textHash) continue;
      scripts++;
      final path = (await audio.get(bookId, chapter.number, mode: mode))?.path;
      if (path != null &&
          await audio.isComplete(script, mode: mode) &&
          await File(path).exists()) {
        voiced++;
      }
    }
    return PackageContents(scriptChapters: scripts, audioChapters: voiced);
  }

  /// The package file, for tests and for sharing.
  Future<File> export(String bookId, {required bool audio}) async {
    final book = await Library(store).getBook(bookId);
    if (await directory.exists()) await directory.delete(recursive: true);
    await directory.create(recursive: true);
    final title = book.title
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .trim();
    final file = File(
      '${directory.path}/${title.isEmpty ? book.id : title}'
      '.${audio ? 'audio' : 'script'}${BookPackages.extension}',
    );
    await BookPackages(store).export(
      bookId,
      file.path,
      kind: audio ? BookPackageKind.audio : BookPackageKind.script,
    );
    return file;
  }

  @override
  Future<void> share(String bookId, {required bool audio}) async =>
      sharing.share((await export(bookId, audio: audio)).path);
}

/// Applies the reader's corrections to a directed chapter.
class ScriptController implements Scripts {
  ScriptController(this.store, this.library, {this.revoice});
  final LocalStore store;

  /// Its `editBook` pauses playback and generation around the change.
  final Library library;

  /// Voices a chapter again once its script has changed.
  final Future<void> Function(String bookId, int chapter)? revoice;

  Future<ChapterAudio?> _audio(String bookId, int chapter) async =>
      AudioRepository(store).get(
        bookId,
        chapter,
        mode: (await PerformanceRepository(store).get(bookId)).mode,
      );

  @override
  Future<bool> hasImportedAudio(String bookId, int chapter) async =>
      (await _audio(bookId, chapter))?.imported ?? false;

  @override
  Future<void> reassign(
    String bookId,
    int chapter,
    int line,
    String speakerId,
  ) async {
    final book = await library.getBook(bookId);
    // A chapter the reader had voiced is voiced again right away; the
    // changed line is the only one that needs a new request.
    final voiced = await _audio(bookId, chapter) != null;
    Future<void> change() async {
      await ScriptEditor(
        store,
      ).revise(book, chapter, line, speakerId: speakerId);
    }

    final edit = library.editBook;
    if (edit == null) {
      await change();
    } else {
      await edit(bookId, change);
    }
    if (voiced) await revoice?.call(bookId, chapter);
  }
}
