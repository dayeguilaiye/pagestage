import 'dart:io';

import 'package:path/path.dart' as p;

import 'audio_repository.dart';
import 'library.dart';
import 'local_store.dart';

class BookStorageSize {
  const BookStorageSize({
    required this.bookId,
    required this.title,
    required this.recordBytes,
    required this.audioBytes,
  });
  final String bookId;
  final String title;

  /// Exact UTF-8 payload size of book-owned SQLite documents. Shared database
  /// page/index/WAL overhead cannot be attributed to an individual book.
  final int recordBytes;
  final int audioBytes;
  int get totalBytes => recordBytes + audioBytes;
}

/// Accounts for owned files and document payloads without claiming ownership of
/// the original imported TXT or externally exported CLI artifacts.
class BookStorage {
  BookStorage(this.store);
  final LocalStore store;
  Future<List<BookStorageSize>> usage() async => [
    for (final book in await Library(store).listBooks())
      BookStorageSize(
        bookId: book.id,
        title: book.title,
        recordBytes: await store.bookDataBytes(book.id),
        audioBytes: await _fileBytes(await _files(book.id)),
      ),
  ];

  Future<int> _fileBytes(Set<String> files) async {
    var bytes = 0;
    for (final path in files) {
      final stat = await FileStat.stat(path);
      if (stat.type == FileSystemEntityType.file) bytes += stat.size;
    }
    return bytes;
  }

  Future<Set<String>> _files(String bookId) async {
    final root = p.normalize(p.absolute(AudioRepository(store).directory.path));
    final directory = AudioRepository(store).bookDirectory(bookId);
    final paths = <String>{};
    if (await directory.exists()) {
      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) paths.add(p.normalize(p.absolute(entity.path)));
      }
    }
    final referenced = <String>{};
    final shared = <String>{};
    for (final row in await store.list('audio')) {
      final target = row['bookId'] == bookId ? referenced : shared;
      final audio = ChapterAudio.fromJson(row);
      if (audio.path != null) target.add(p.normalize(p.absolute(audio.path!)));
      for (final u in audio.utterances) {
        target.addAll([
          p.normalize(p.absolute(u.audioPath)),
          p.normalize(p.absolute(u.rawAudioPath)),
        ]);
      }
    }
    for (final collection in ['voices', 'voiceCandidates']) {
      for (final row in await store.list(collection)) {
        final voice = collection == 'voices' ? row : row['voice'] as Map;
        if (voice['samplePath'] case final String sample) {
          (voice['bookId'] == bookId ? referenced : shared).add(
            p.normalize(p.absolute(sample)),
          );
        }
      }
    }
    for (final path in referenced.difference(shared)) {
      if (p.isWithin(root, path) &&
          await FileSystemEntity.type(path, followLinks: false) ==
              FileSystemEntityType.file) {
        paths.add(path);
      }
    }
    return paths.difference(shared);
  }

  /// Caller must stop this book's writers and native playback first.
  Future<void> clearAudio(String bookId) async {
    await Library(store).getBook(bookId);
    for (final path in await _files(bookId)) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await store.transaction(() async {
      for (final row in await store.list('audio')) {
        if (row['bookId'] == bookId) {
          await store.delete(
            'audio',
            '$bookId:${row['chapter']}:${row['mode']}',
          );
        }
      }
      for (final row in await store.list('voices')) {
        if (row['bookId'] == bookId) {
          row.remove('samplePath');
          await store.put('voices', row['id'] as String, row);
        }
      }
      for (final row in await store.list('voiceCandidates')) {
        if ((row['voice'] as Map)['bookId'] == bookId) {
          await store.delete('voiceCandidates', row['id'] as String);
        }
      }
    });
  }
}
