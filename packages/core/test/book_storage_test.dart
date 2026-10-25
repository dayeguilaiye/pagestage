import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory root;
  late LocalStore store;
  late Book first;
  late Book second;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('book-storage-');
    store = LocalStore('${root.path}/db.sqlite');
    final a = await File(
      '${root.path}/one.txt',
    ).writeAsString('Chapter 1\nOne.');
    final b = await File(
      '${root.path}/two.txt',
    ).writeAsString('Chapter 1\nTwo.');
    first = await Library(store).importTxt(a.path);
    second = await Library(store).importTxt(b.path);
  });
  tearDown(() async {
    await store.close();
    await root.delete(recursive: true);
  });
  test(
    'usage counts exact owned files and database payloads; clear preserves book and other book audio',
    () async {
      final audio = AudioRepository(store);
      final a = File('${audio.bookDirectory(first.id).path}/cache/one.wav');
      final b = File('${audio.bookDirectory(second.id).path}/two.wav');
      await a.parent.create(recursive: true);
      await a.writeAsBytes(List.filled(123, 1));
      await b.parent.create(recursive: true);
      await b.writeAsBytes(List.filled(456, 2));
      await store.put('casting', first.id, {'exclusiveCount': 20});
      final usage = await BookStorage(store).usage();
      final row = usage.singleWhere((u) => u.bookId == first.id);
      expect(row.audioBytes, 123);
      expect(row.recordBytes, await store.bookDataBytes(first.id));
      expect(row.totalBytes, row.recordBytes + 123);
      await BookStorage(store).clearAudio(first.id);
      expect(await a.exists(), isFalse);
      expect(await b.length(), 456);
      expect(await File(first.sourcePath).readAsString(), 'Chapter 1\nOne.');
      expect(await store.get('casting', first.id), {'exclusiveCount': 20});
      expect(
        (await BookStorage(
          store,
        ).usage()).singleWhere((u) => u.bookId == first.id).audioBytes,
        0,
      );
    },
  );
  test(
    'clear preserves shared legacy samples and external user exports',
    () async {
      final audio = AudioRepository(store);
      final shared = File('${audio.legacyCacheDirectory.path}/shared.wav');
      await shared.parent.create(recursive: true);
      await shared.writeAsBytes(List.filled(88, 3));
      final exported = await File(
        '${root.path}/export.wav',
      ).writeAsBytes(List.filled(99, 4));
      for (final book in [first, second]) {
        await store.put(
          'voices',
          book.id,
          Voice(
            id: book.id,
            bookId: book.id,
            description: 'Shared sample',
            binding: const VoiceBinding(
              provider: 'minimax',
              model: 'speech-2.8-hd',
              voiceId: 'preset',
            ),
            samplePath: shared.path,
          ).toJson(),
        );
      }
      await store.put(
        'voices',
        'exported',
        Voice(
          id: 'exported',
          bookId: first.id,
          description: 'External',
          binding: const VoiceBinding(
            provider: 'minimax',
            model: 'speech-2.8-hd',
            voiceId: 'preset',
          ),
          samplePath: exported.path,
        ).toJson(),
      );
      await BookStorage(store).clearAudio(first.id);
      expect(await shared.exists(), isTrue);
      expect(await exported.exists(), isTrue);
      expect(
        (await store.get('voices', first.id))!.containsKey('samplePath'),
        isFalse,
      );
      expect(
        (await store.get('voices', second.id))!['samplePath'],
        shared.path,
      );
    },
  );
}
