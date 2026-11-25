import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'paths into an earlier container are read against the current one',
    () async {
      final root = await Directory.systemTemp.createTemp('relocate-');
      addTearDown(() => root.delete(recursive: true));
      final old = Directory('${root.path}/A/Library/Application Support')
        ..createSync(recursive: true);
      final now = Directory('${root.path}/B/Library/Application Support')
        ..createSync(recursive: true);
      final store = LocalStore('${now.path}/pagestage.sqlite');
      addTearDown(store.close);
      expect(
        relocatePath(store, '${old.path}/audio/book/line.wav'),
        '${now.path}/audio/book/line.wav',
      );
      expect(
        relocatePath(store, '${now.path}/audio/book/line.wav'),
        '${now.path}/audio/book/line.wav',
      );
      // Somewhere else entirely is left as it was.
      expect(relocatePath(store, '/elsewhere/line.wav'), '/elsewhere/line.wav');
    },
  );

  test('chapter audio saved before an update still plays after it', () async {
    final root = await Directory.systemTemp.createTemp('relocate-audio-');
    addTearDown(() => root.delete(recursive: true));
    final before = '${root.path}/A/Library/Application Support';
    final after = Directory('${root.path}/B/Library/Application Support')
      ..createSync(recursive: true);
    final store = LocalStore('${after.path}/pagestage.sqlite');
    addTearDown(store.close);
    final file = File('${after.path}/audio/book1/chapter.wav')
      ..createSync(recursive: true)
      ..writeAsBytesSync(List.filled(64, 1));
    await store.put('audio', 'book1:1:audiobook', {
      'bookId': 'book1',
      'chapter': 1,
      'mode': 'audiobook',
      'scriptHash': 'x',
      'complete': true,
      'path': '$before/audio/book1/chapter.wav',
      'utterances': <Object?>[],
    });
    final audio = await AudioRepository(store).get('book1', 1);
    expect(audio!.path, file.path);
  });
}
