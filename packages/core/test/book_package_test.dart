import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:pagestage_core/pagestage_core.dart';
import 'package:pagestage_core/src/cli.dart';
import 'package:test/test.dart';

import 'support/generation_fakes.dart';
import 'support/fake_request_clock.dart';

void main() {
  late Directory dir;
  late LocalStore store;
  late _FailingStore other;
  late Book book;
  late GenerationTts tts;

  /// Profiles and casts the book, then directs and voices chapters 1..[n].
  Future<void> produce(int n, {bool voiced = true}) async {
    await Profiler(store, GenerationLlm()).profile(book, throughChapter: 3);
    await Casting(store).recommend(book, providers: {'minimax'});
    final scheduler = await Scheduler.open(
      store: store,
      profileLlm: GenerationLlm(),
      directorLlm: GenerationLlm(),
      ttsAdapters: {'minimax': tts},
    );
    await scheduler.enqueue(
      book.id,
      voiced ? TaskKind.synthesize : TaskKind.direct,
      through: n,
    );
    await scheduler.idle;
    await scheduler.close();
  }

  setUp(() async {
    // Two libraries, as on two devices, share this isolate.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = await Directory.systemTemp.createTemp('package-');
    store = LocalStore('${dir.path}/a/pagestage.sqlite');
    other = _FailingStore('${dir.path}/b/db.sqlite');
    final file = await File('${dir.path}/novel.txt').writeAsString(
      [for (var i = 1; i <= 3; i++) 'Chapter $i\nWind $i.\nHome $i.\n'].join(),
    );
    book = await Library(store).importTxt(file.path, title: 'Winds');
    tts = GenerationTts();
  });
  tearDown(() async {
    await store.close();
    await other.close();
    await dir.delete(recursive: true);
  });

  test('a script package carries the text, cast and scripts, and nothing '
      'is directed again', () async {
    await produce(2, voiced: false);
    final path = '${dir.path}/winds.pagestage';
    final exported = await BookPackages(
      store,
    ).export(book.id, path, kind: BookPackageKind.script);
    expect(exported.scriptChapters, [1, 2]);
    expect(exported.audioChapters, isEmpty);
    final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final exportedBook =
        jsonDecode(
              utf8.decode(archive.findFile('book.json')!.content as List<int>),
            )
            as Map;
    expect(exportedBook['sourcePath'], 'novel.txt');

    final summary = await BookPackages(other).inspect(path);
    expect(summary.title, 'Winds');
    expect(summary.kind, BookPackageKind.script);
    expect(await Library(other).listBooks(), isEmpty);

    final imported = await BookPackages(other).import(path);
    expect(imported.replaced, isFalse);
    expect(imported.summary.scriptChapters, [1, 2]);
    final copy = await Library(other).getBook(book.id);
    expect(copy.chapters.map((c) => c.text), book.chapters.map((c) => c.text));
    expect(
      jsonEncode((await ScriptRepository(other).get(book.id, 2))!.toJson()),
      jsonEncode((await ScriptRepository(store).get(book.id, 2))!.toJson()),
    );
    final cast = await CastRepository(other).get(book.id);
    expect(cast.profiledThrough, 3);
    final states = await Library(other).chapters(book.id);
    expect(states.map((c) => c.state), [
      ChapterState.directed,
      ChapterState.directed,
      ChapterState.profiled,
    ]);

    // Voicing the imported script directs nothing.
    final director = GenerationLlm();
    final scheduler = await Scheduler.open(
      store: other,
      profileLlm: GenerationLlm(),
      directorLlm: director,
      ttsAdapters: {'minimax': tts},
    );
    await scheduler.enqueue(book.id, TaskKind.synthesize, through: 2);
    await scheduler.idle;
    await scheduler.close();
    expect(director.chapters, isEmpty);
    expect(
      (await Library(other).chapters(book.id)).first.state,
      ChapterState.synthesized,
    );
  });

  test('an audio package plays where it lands, whatever voices are cast '
      'there', () async {
    await produce(2);
    final path = '${dir.path}/winds.pagestage';
    final exported = await BookPackages(
      store,
    ).export(book.id, path, kind: BookPackageKind.audio);
    expect(exported.audioChapters, [1, 2]);

    final imported = await Library(other).importPackage(path);
    expect(imported!.summary.audioChapters, [1, 2]);
    final audio = (await AudioRepository(other).get(book.id, 1))!;
    expect(audio.imported, isTrue);
    expect(audio.path, startsWith('${dir.path}/b/audio/${book.id}/'));
    expect(await File(audio.path!).exists(), isTrue);
    expect(
      await File(audio.path!).readAsBytes(),
      await File(
        (await AudioRepository(store).get(book.id, 1))!.path!,
      ).readAsBytes(),
    );
    expect(audio.utterances.every((u) => u.audioPath == audio.path), isTrue);
    final script = (await ScriptRepository(other).get(book.id, 1))!;
    expect(await AudioRepository(other).isComplete(script), isTrue);

    // Recasting on this device leaves the imported audio valid.
    final narrator = (await Casting(
      other,
    ).getCasting(book.id)).voices.values.first;
    await other.put(
      'voices',
      narrator.id,
      narrator
          .copyWith(
            binding: const VoiceBinding(
              provider: 'edge',
              model: 'edge-read-aloud',
              voiceId: 'zh-CN-XiaoxiaoNeural',
            ),
          )
          .toJson(),
    );
    expect(await AudioRepository(other).isComplete(script), isTrue);

    // Correcting a line makes that chapter this device's own again.
    await ScriptEditor(
      other,
    ).revise(await Library(other).getBook(book.id), 1, 0, emotion: Emotion.sad);
    expect(
      await AudioRepository(
        other,
      ).isComplete((await ScriptRepository(other).get(book.id, 1))!),
      isFalse,
    );
  });

  test('a package for a book on the shelf replaces it only when asked, '
      'keeping the place', () async {
    await produce(1);
    final path = '${dir.path}/winds.pagestage';
    await BookPackages(
      store,
    ).export(book.id, path, kind: BookPackageKind.audio);
    await store.put('listening', book.id, {'bookId': book.id, 'chapter': 2});
    await expectLater(
      BookPackages(store).import(path),
      throwsA(isA<BookPackageConflict>()),
    );
    expect(
      await Library(
        store,
      ).importPackage(path, confirmReplace: (_) async => false),
      isNull,
    );
    final edited = <String>[];
    final library = Library(store)
      ..editBook = (id, action) async {
        edited.add(id);
        await action();
      };
    final replaced = await library.importPackage(
      path,
      confirmReplace: (title) async => title == 'Winds',
    );
    expect(replaced!.replaced, isTrue);
    expect(edited, [book.id]);
    expect((await store.get('listening', book.id))!['chapter'], 2);
    expect((await AudioRepository(store).get(book.id, 1))!.imported, isTrue);
    expect(await store.list('tasks'), isEmpty);
  });

  test('a damaged or foreign file is refused and leaves nothing '
      'behind', () async {
    await produce(1);
    final path = '${dir.path}/winds.pagestage';
    await BookPackages(
      store,
    ).export(book.id, path, kind: BookPackageKind.audio);

    final junk = await File('${dir.path}/junk.pagestage').writeAsString('x');
    await expectLater(
      BookPackages(other).import(junk.path),
      throwsFormatException,
    );

    // Audio that does not match its recorded digest.
    final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final tampered = Archive();
    for (final file in archive) {
      final bytes = file.name.endsWith('.wav')
          ? (List<int>.of(file.content as List<int>)..[50] ^= 0xff)
          : file.content as List<int>;
      tampered.addFile(ArchiveFile(file.name, bytes.length, bytes));
    }
    final bad = File('${dir.path}/bad.pagestage');
    await bad.writeAsBytes(ZipEncoder().encode(tampered)!);
    await expectLater(
      BookPackages(other).import(bad.path),
      throwsFormatException,
    );
    expect(await Library(other).listBooks(), isEmpty);
    final leftovers = Directory('${dir.path}/b/audio/${book.id}');
    expect(!await leftovers.exists() || await leftovers.list().isEmpty, isTrue);

    // A package from a later format version.
    final newer = Archive();
    for (final file in archive) {
      var bytes = file.content as List<int>;
      if (file.name == 'manifest.json') {
        final manifest = jsonDecode(utf8.decode(bytes)) as Map;
        bytes = utf8.encode(jsonEncode({...manifest, 'version': 99}));
      }
      newer.addFile(ArchiveFile(file.name, bytes.length, bytes));
    }
    final future = File('${dir.path}/future.pagestage');
    await future.writeAsBytes(ZipEncoder().encode(newer)!);
    await expectLater(
      BookPackages(other).inspect(future.path),
      throwsFormatException,
    );
  });

  test('the bookshelf imports a package like any other file', () async {
    await produce(2);
    final path = '${dir.path}/winds.pagestage';
    await BookPackages(
      store,
    ).export(book.id, path, kind: BookPackageKind.audio);
    final outcome = await Library(
      other,
      pickFile: () async => path,
    ).importBook();
    expect(
      outcome,
      isA<PackageImported>()
          .having((o) => o.book.title, 'title', 'Winds')
          .having((o) => o.scriptChapters, 'scripts', 2)
          .having((o) => o.audioChapters, 'audio', 2)
          .having((o) => o.replaced, 'replaced', isFalse),
    );
    final junk = await File('${dir.path}/junk.pagestage').writeAsString('x');
    final failed = await Library(
      other,
      pickFile: () async => junk.path,
    ).importBook();
    expect(
      failed,
      isA<ImportFailed>().having(
        (o) => o.reason,
        'reason',
        ImportFailure.invalidPackage,
      ),
    );
  });

  for (final damage in ['audio', 'performance', 'storage']) {
    test(
      'a replacement with invalid $damage preserves the existing book',
      () async {
        await produce(2);
        final path = '${dir.path}/replacement.pagestage';
        await BookPackages(
          store,
        ).export(book.id, path, kind: BookPackageKind.audio);
        await BookPackages(other).import(path);
        await other.put('listening', book.id, {
          'bookId': book.id,
          'chapter': 2,
        });
        const collections = [
          'books',
          'casts',
          'scripts',
          'voices',
          'casting',
          'audio',
          'performance',
          'listening',
        ];
        final before = {
          for (final collection in collections)
            collection: await other.list(collection),
        };
        final audio = (await AudioRepository(other).get(book.id, 1))!;
        final bytesBefore = await File(audio.path!).readAsBytes();
        final archive = ZipDecoder().decodeBytes(
          await File(path).readAsBytes(),
        );
        final tampered = Archive();
        for (final entry in archive) {
          var bytes = List<int>.of(entry.content as List<int>);
          if (damage == 'audio' && entry.name.endsWith('.wav')) {
            bytes[50] ^= 0xff;
          } else if (damage == 'performance' && entry.name == 'manifest.json') {
            final manifest = jsonDecode(utf8.decode(bytes)) as Map;
            bytes = utf8.encode(
              jsonEncode({
                ...manifest,
                'performance': {'mode': 'unknown'},
              }),
            );
          }
          tampered.addFile(ArchiveFile(entry.name, bytes.length, bytes));
        }
        final damaged = await File(
          '${dir.path}/damaged.pagestage',
        ).writeAsBytes(ZipEncoder().encode(tampered)!);
        if (damage == 'storage') other.failCollection = 'casts';
        var edits = 0;

        await expectLater(
          BookPackages(other).import(
            damaged.path,
            replace: true,
            edit: (_, action) async {
              edits++;
              await action();
            },
          ),
          damage == 'storage' ? throwsStateError : throwsFormatException,
        );
        other.failCollection = null;
        expect(edits, damage == 'storage' ? 1 : 0);

        for (final collection in collections) {
          expect(
            await other.list(collection),
            before[collection],
            reason: '$collection survives a failed replacement',
          );
        }
        expect(await File(audio.path!).readAsBytes(), bytesBefore);
        final script = (await ScriptRepository(other).get(book.id, 1))!;
        expect(await AudioRepository(other).isComplete(script), isTrue);
        expect(
          await Directory(
            '${dir.path}/b/audio',
          ).list().map((f) => f.path).toList(),
          ['${dir.path}/b/audio/${book.id}'],
        );
      },
    );
  }

  test('CLI synthesis and export share the saved performance mode', () async {
    await produce(1, voiced: false);
    await store.close();
    final out = StringBuffer();
    final errors = StringBuffer();
    Future<int> synthesize(List<String> options) => runCli(
      ['--data-dir', '${dir.path}/a', 'synthesize', book.id, '1', ...options],
      output: out,
      errorOutput: errors,
      environment: const {},
      ttsAdapters: {'minimax': tts},
      requestRuntime: FakeRequestClock().runtime,
    );
    expect(await synthesize(['--mode', 'drama']), 0, reason: '$errors');
    out.clear();
    expect(await synthesize([]), 0, reason: '$errors');
    expect((jsonDecode(out.toString()) as Map)['mode'], 'drama');
    out.clear();
    final path = '${dir.path}/drama.pagestage';
    expect(
      await runCli(
        [
          '--data-dir',
          '${dir.path}/a',
          'export',
          book.id,
          path,
          '--kind',
          'audio',
        ],
        output: out,
        errorOutput: errors,
        environment: const {},
      ),
      0,
      reason: '$errors',
    );
    final imported = await BookPackages(other).import(path);
    expect(imported.summary.audioChapters, [1]);
    expect(
      (await PerformanceRepository(other).get(book.id)).mode,
      PerformanceMode.drama,
    );
    expect(
      await AudioRepository(other).isComplete(
        (await ScriptRepository(other).get(book.id, 1))!,
        mode: PerformanceMode.drama,
      ),
      isTrue,
    );
    store = LocalStore('${dir.path}/a/pagestage.sqlite');
  });

  test(
    'the CLI exports a package and imports it into another library',
    () async {
      await produce(1);
      await store.close();
      final out = StringBuffer();
      final path = '${dir.path}/cli.pagestage';
      expect(
        await runCli(
          [
            '--data-dir',
            '${dir.path}/a',
            'export',
            book.id,
            path,
            '--kind',
            'audio',
          ],
          output: out,
          errorOutput: StringBuffer(),
          environment: const {},
        ),
        0,
      );
      final exported = jsonDecode(out.toString()) as Map;
      expect(exported['audioChapters'], [1]);
      out.clear();
      Future<int> import([List<String> extra = const []]) => runCli(
        ['--data-dir', '${dir.path}/c', 'import', path, ...extra],
        output: out,
        errorOutput: StringBuffer(),
        environment: const {},
      );
      expect(await import(), 0);
      expect((jsonDecode(out.toString()) as Map)['replaced'], isFalse);
      out.clear();
      expect(await import(), 65);
      expect(await import(['--replace']), 0);
      expect((jsonDecode(out.toString()) as Map)['replaced'], isTrue);
      // Reopened for tearDown.
      store = LocalStore('${dir.path}/a/pagestage.sqlite');
    },
  );
}

class _FailingStore extends LocalStore {
  _FailingStore(super.path);
  String? failCollection;

  @override
  Future<void> put(String collection, String key, Map<String, Object?> value) {
    if (collection == failCollection) {
      throw StateError('Simulated write failure');
    }
    return super.put(collection, key, value);
  }
}
