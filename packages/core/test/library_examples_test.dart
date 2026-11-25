import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

import 'support/generation_fakes.dart';

void main() {
  late Directory dir;
  late LocalStore source;
  late LocalStore target;
  late Library library;
  final assets = <String, List<int>>{};

  setUp(() async {
    // The CLI's library and the app's, as on two machines, share this isolate.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = await Directory.systemTemp.createTemp('library-examples-');
    source = LocalStore('${dir.path}/source/library.sqlite');
    target = LocalStore('${dir.path}/target/library.sqlite');
    library = Library(target);
  });
  tearDown(() async {
    await source.close();
    await target.close();
    await dir.delete(recursive: true);
    assets.clear();
  });

  Future<String> write(String name, String text) async =>
      (await File('${dir.path}/$name.txt').writeAsString(text)).path;

  String edition(int chapters) => [
    for (var n = 1; n <= chapters; n++) 'Chapter $n\nPart $n of the tale.\n',
  ].join();

  /// A bundle as tool/build_examples.dart makes one: the first [packaged]
  /// chapters of a book the CLI imported from [text], voiced in advance.
  Future<Map<String, Object?>> bundle(
    String text, {
    required int packaged,
  }) async {
    final book = await Library(source).importTxt(await write('source', text));
    final llm = GenerationLlm();
    final scheduler = await Scheduler.open(
      store: source,
      profileLlm: llm,
      directorLlm: llm,
      ttsAdapters: {'minimax': GenerationTts()},
    );
    try {
      await scheduler.enqueue(book.id, TaskKind.profile, through: packaged);
      await scheduler.idle;
      await Casting(source).recommend(book, providers: {'minimax'});
      await scheduler.enqueue(book.id, TaskKind.synthesize, through: packaged);
      await scheduler.idle;
    } finally {
      await scheduler.close();
    }
    final records = <Map<String, Object?>>[
      {
        'collection': 'casting',
        'key': book.id,
        'value': await source.get('casting', book.id),
      },
      for (final collection in ['casts', 'voices', 'scripts'])
        for (final row in await source.list(collection))
          if (row['bookId'] == book.id &&
              (collection != 'scripts' ||
                  (row['chapterNumber'] as int) <= packaged))
            {
              'collection': collection,
              'key': switch (collection) {
                'casts' => book.id,
                'voices' => row['id'],
                _ => '${book.id}:${row['chapterNumber']}',
              },
              'value': row,
            },
    ];
    final audio = <Map<String, Object?>>[];
    for (var n = 1; n <= packaged; n++) {
      final playlist = (await AudioRepository(source).get(book.id, n))!;
      final bytes = await File(playlist.path!).readAsBytes();
      final asset = 'assets/examples/${book.id}-$n.wav';
      assets[asset] = bytes;
      audio.add({
        'asset': asset,
        'sha256': sha256.convert(bytes).toString(),
        'playlist': playlist.toJson(),
      });
    }
    final packagedBook = Book(
      id: book.id,
      title: book.title,
      language: book.language,
      sourcePath: 'bundled:${book.id}',
      chapters: book.chapters.take(packaged).toList(),
    );
    return {
      'schema': 1,
      'books': [
        {'book': packagedBook.toJson(), 'records': records, 'audio': audio},
      ],
    };
  }

  Future<void> install(Map<String, Object?> manifest, {bool loads = true}) =>
      ExampleLibrary(target).install(
        manifest,
        (asset) async =>
            loads ? assets[asset]! : throw StateError('must not load again'),
      );

  Future<void> expectSample(String id, {required int chapters}) async {
    final book = await library.getBook(id);
    expect(book.sourcePath, 'bundled:$id');
    expect(book.chapters, hasLength(chapters));
    expect(
      (await library.chapters(id)).map((c) => c.state),
      everyElement(ChapterState.synthesized),
    );
  }

  test('the source of a bundled example imports as a separate book', () async {
    // Like the app's samples: chapter one of a longer book, whose id comes
    // from the whole text.
    final text = edition(3);
    await install(await bundle(text, packaged: 1));
    final sample = (await library.listBooks()).single.id;
    expect(await ExampleLibrary.bookIds(target), {sample});

    final copy = await library.importFile(await write('reader', text));
    expect(copy.updated, isFalse);
    expect(copy.book.id, isNot(sample));
    expect(copy.book.chapters, hasLength(3));
    await expectSample(sample, chapters: 1);

    // The same file again, then a newer edition, update the copy.
    final again = await library.importFile(await write('again', text));
    expect(again.updated, isTrue);
    expect(again.book.id, copy.book.id);
    expect(again.changedChapters, isEmpty);
    final newer = await library.importFile(await write('newer', edition(4)));
    expect(newer.updated, isTrue);
    expect(newer.book.id, copy.book.id);
    expect(newer.addedChapters, 1);
    expect(await library.books(), hasLength(2));
    await expectSample(sample, chapters: 1);
    expect(await ExampleLibrary.bookIds(target), {sample});
  });

  test(
    'an edition matching an example by its first chapters stays apart',
    () async {
      await install(await bundle(edition(3), packaged: 3));
      final sample = (await library.listBooks()).single.id;
      final newer = await library.importFile(await write('newer', edition(4)));
      expect(newer.updated, isFalse);
      expect(newer.book.id, isNot(sample));
      await expectSample(sample, chapters: 3);
      // Editions of the reader's own book still update it.
      final latest = await library.importFile(
        await write('latest', edition(5)),
      );
      expect(latest.updated, isTrue);
      expect(latest.book.id, newer.book.id);
      expect(latest.addedChapters, 1);
      expect(await library.books(), hasLength(2));
      await expectSample(sample, chapters: 3);
    },
  );

  test('examples installed before ids were recorded get them at the next '
      'launch', () async {
    final manifest = await bundle(edition(1), packaged: 1);
    await install(manifest);
    final sample = (await library.listBooks()).single.id;
    // An earlier install recorded only that examples were installed.
    await target.delete('settings', 'exampleBooks');
    await install(manifest, loads: false);
    expect(await target.get('settings', 'exampleBooks'), {
      'ids': [sample],
    });
    // A sample that a reader's import already took over is their book.
    await target.delete('settings', 'exampleBooks');
    final record = (await target.get('books', sample))!;
    await target.put('books', sample, {
      ...record,
      'sourcePath': '${dir.path}/reader.txt',
    });
    await install(manifest, loads: false);
    expect(await ExampleLibrary.bookIds(target), isEmpty);
  });
}
