import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';
import 'support/generation_fakes.dart';

void main() {
  late Directory dir;
  late LocalStore source;
  late LocalStore target;
  late Map<String, Object?> manifest;
  final assets = <String, List<int>>{};
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('example-bundle-');
    source = LocalStore('${dir.path}/source/library.sqlite');
    target = LocalStore('${dir.path}/target/library.sqlite');
    final entries = <Map<String, Object?>>[];
    for (final text in ['Chapter 1\nExample one.', '第一章\n第二本书。']) {
      final f = await File('${dir.path}/book.txt').writeAsString(text);
      final b = await Library(source).importTxt(f.path);
      final llm = GenerationLlm();
      final scheduler = await Scheduler.open(
        store: source,
        profileLlm: llm,
        directorLlm: llm,
        ttsAdapters: {'minimax': GenerationTts()},
      );
      await scheduler.enqueue(b.id, TaskKind.profile, through: 1);
      await scheduler.idle;
      await Casting(source).recommend(b, providers: {'minimax'});
      await scheduler.enqueue(b.id, TaskKind.synthesize, through: 1);
      await scheduler.idle;
      await scheduler.close();
      final audio = (await AudioRepository(source).get(b.id, 1))!;
      final bytes = await File(audio.path!).readAsBytes();
      final asset = 'assets/examples/${b.id}.wav';
      assets[asset] = bytes;
      final records = <Object?>[];
      for (final c in ['casts', 'voices', 'scripts', 'casting']) {
        if (c == 'casting') {
          records.add({
            'collection': c,
            'key': b.id,
            'value': await source.get(c, b.id),
          });
          continue;
        }
        for (final row in await source.list(c)) {
          if (row['bookId'] != b.id) continue;
          records.add({
            'collection': c,
            'key': c == 'casts'
                ? b.id
                : c == 'voices'
                ? row['id']
                : '${b.id}:${row['chapterNumber']}',
            'value': row,
          });
        }
      }
      entries.add({
        'book': b.toJson(),
        'records': records,
        'audio': [
          {
            'asset': asset,
            'sha256': sha256.convert(bytes).toString(),
            'playlist': audio.toJson(),
          },
        ],
      });
    }
    manifest = {'schema': 1, 'books': entries};
  });
  tearDown(() async {
    await source.close();
    await target.close();
    await dir.delete(recursive: true);
    assets.clear();
  });
  test(
    'new install receives relocated complete books; deletion remains after restart',
    () async {
      await ExampleLibrary(
        target,
      ).install(manifest, (name) async => assets[name]!);
      final books = await Library(target).listBooks();
      expect(books, hasLength(2));
      for (final book in books) {
        expect(
          (await Library(target).chapters(book.id)).single.state,
          ChapterState.synthesized,
        );
        expect(
          (await AudioRepository(target).get(book.id, 1))!.path,
          contains('/target/audio/'),
        );
        expect(book.sourcePath, startsWith('bundled:'));
      }
      await Library(target).deleteBook(books.first.id);
      await target.close();
      target = LocalStore('${dir.path}/target/library.sqlite');
      await ExampleLibrary(
        target,
      ).install(manifest, (_) async => throw StateError('must not load twice'));
      expect(await Library(target).books(), hasLength(1));
    },
  );
  test(
    'corrupt bundle rolls back books, files and installation marker',
    () async {
      await expectLater(
        ExampleLibrary(
          target,
        ).install(manifest, (_) async => utf8.encode('corrupt')),
        throwsFormatException,
      );
      expect(await Library(target).books(), isEmpty);
      expect(await target.get('settings', 'examplesInstalled'), isNull);
      await ExampleLibrary(
        target,
      ).install(manifest, (name) async => assets[name]!);
      expect(await Library(target).books(), hasLength(2));
    },
  );
  test('existing libraries keep their own books', () async {
    final file = await File(
      '${dir.path}/own.txt',
    ).writeAsString('My own library.');
    final own = await Library(target).importTxt(file.path);
    await ExampleLibrary(
      target,
    ).install(manifest, (_) async => throw StateError('must not load'));
    expect((await Library(target).books()).single.id, own.id);
  });
}
