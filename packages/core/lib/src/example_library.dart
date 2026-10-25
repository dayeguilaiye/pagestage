import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'audio_repository.dart';
import 'local_store.dart';
import 'models/book.dart';
import 'models/script.dart';
import 'synthesizer.dart';

/// Installs a verified, relocatable bundle once. It never calls a provider.
class ExampleLibrary {
  ExampleLibrary(this.store);
  final LocalStore store;

  Future<void> install(
    Map<String, Object?> manifest,
    Future<List<int>> Function(String asset) load,
  ) async {
    if (manifest['schema'] != 1) {
      throw const FormatException('Unsupported example bundle.');
    }
    if (await store.get('settings', 'examplesInstalled') != null) return;
    final entries = (manifest['books'] as List).cast<Map>();
    if (entries.isEmpty) return;
    // Existing libraries belong to their readers; seeding is for new installs.
    if ((await store.list('books')).isNotEmpty) {
      await store.put('settings', 'examplesInstalled', {'version': 1});
      return;
    }
    final staged = <Directory>[];
    final records =
        <({String collection, String key, Map<String, Object?> value})>[];
    try {
      for (final entry in entries) {
        final bookJson = Map<String, Object?>.from(entry['book'] as Map);
        final book = Book.fromJson(bookJson);
        final directory = AudioRepository(store).bookDirectory(book.id);
        staged.add(directory);
        await directory.create(recursive: true);
        records.add((
          collection: 'books',
          key: book.id,
          value: {
            ...book.toJson(),
            'sourcePath': 'bundled:${book.id}',
            'importedAt': DateTime.now().microsecondsSinceEpoch,
          },
        ));
        final sourceRecords = (entry['records'] as List).cast<Map>();
        for (final row in sourceRecords) {
          final collection = row['collection'] as String;
          if (!{'casts', 'voices', 'casting', 'scripts'}.contains(collection)) {
            throw const FormatException('Invalid bundle collection.');
          }
          final value = Map<String, Object?>.from(row['value'] as Map);
          if (collection != 'casting' && value['bookId'] != book.id) {
            throw const FormatException('Invalid bundle ownership.');
          }
          if (collection == 'voices') value.remove('samplePath');
          records.add((
            collection: collection,
            key: row['key'] as String,
            value: value,
          ));
        }
        final audioChapters = <int>{};
        final scriptChapters = <int>{};
        for (final row in sourceRecords.where(
          (r) => r['collection'] == 'scripts',
        )) {
          final script = Script.fromJson(
            Map<String, Object?>.from(row['value'] as Map),
          );
          book.chapter(script.chapterNumber);
          if (!scriptChapters.add(script.chapterNumber)) {
            throw const FormatException('Duplicate example script.');
          }
        }
        for (final raw in entry['audio'] as List) {
          final row = Map<String, Object?>.from(raw as Map);
          final asset = row['asset'] as String;
          if (!RegExp(
            r'^assets/examples/[a-zA-Z0-9_-]+\.(m4a|wav)$',
          ).hasMatch(asset)) {
            throw const FormatException('Invalid bundle asset.');
          }
          final bytes = await load(asset);
          if (sha256.convert(bytes).toString() != row['sha256']) {
            throw const FormatException('Corrupt example audio.');
          }
          final file = File(p.join(directory.path, p.basename(asset)));
          await file.writeAsBytes(bytes, flush: true);
          final audio = Map<String, Object?>.from(row['playlist'] as Map);
          if (audio['bookId'] != book.id || audio['complete'] != true) {
            throw const FormatException('Incomplete example chapter.');
          }
          audio['path'] = file.path;
          audio['utterances'] = [
            for (final u in audio['utterances'] as List)
              {
                ...Map<String, Object?>.from(u as Map),
                'audioPath': file.path,
                'rawAudioPath': file.path,
              },
          ];
          final parsed = ChapterAudio.fromJson(audio);
          if (parsed.mode != PerformanceMode.audiobook) {
            throw const FormatException('Invalid example mode.');
          }
          book.chapter(parsed.chapter);
          if (!audioChapters.add(parsed.chapter)) {
            throw const FormatException('Duplicate example audio.');
          }
          records.add((
            collection: 'audio',
            key: '${book.id}:${parsed.chapter}:audiobook',
            value: audio,
          ));
        }
        if (audioChapters.length != book.chapters.length ||
            scriptChapters.length != book.chapters.length) {
          throw const FormatException('Missing example chapters.');
        }
      }
      await store.transaction(() async {
        for (final record in records) {
          await store.put(record.collection, record.key, record.value);
        }
        final audio = AudioRepository(store);
        for (final record in records.where((r) => r.collection == 'scripts')) {
          final script = Script.fromJson(record.value);
          final book = records.singleWhere(
            (r) => r.collection == 'books' && r.key == script.bookId,
          );
          if (script.sourceTextHash !=
                  Book.fromJson(
                    book.value,
                  ).chapter(script.chapterNumber).textHash ||
              !await audio.isComplete(script)) {
            throw const FormatException(
              'Example source, script and audio differ.',
            );
          }
        }
        await store.put('settings', 'examplesInstalled', {'version': 1});
      });
    } catch (_) {
      for (final directory in staged) {
        if (await directory.exists()) await directory.delete(recursive: true);
      }
      rethrow;
    }
  }
}
