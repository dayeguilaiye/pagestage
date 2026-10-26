import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_core/pagestage_core.dart';

import '../../../core/test/support/generation_fakes.dart';

class _LocalTts extends GenerationTts {
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async => TtsAudio(
    audio: PcmAudio(samples: Int16List(24000), sampleRate: 24000),
    characters: request.text.length,
  );
}

void main() {
  test('packages only chapter one from a larger CLI library', () async {
    final root = await Directory.systemTemp.createTemp('example-packaging-');
    final source = LocalStore('${root.path}/source/pagestage.sqlite');
    final target = LocalStore('${root.path}/target/pagestage.sqlite');
    addTearDown(() async {
      await source.close();
      await target.close();
      await root.delete(recursive: true);
    });
    for (final id in ['15bad7444de48233ea12c39c', 'e29cb883376b4e31947bb861']) {
      final book = Book(
        id: id,
        title: 'Offline example',
        language: 'en',
        sourcePath: 'offline',
        chapters: [
          for (var n = 1; n <= 5; n++)
            Chapter(number: n, title: 'Chapter $n', text: 'Chapter $n text.\n'),
        ],
      );
      await source.put('books', id, book.toJson());
      final llm = GenerationLlm();
      final scheduler = await Scheduler.open(
        store: source,
        profileLlm: llm,
        directorLlm: llm,
        ttsAdapters: {'minimax': _LocalTts()},
      );
      try {
        await scheduler.enqueue(id, TaskKind.profile, through: 5);
        await scheduler.idle;
        await Casting(source).recommend(book, providers: {'minimax'});
        await scheduler.enqueue(id, TaskKind.synthesize, through: 1);
        await scheduler.idle;
        // Later scripts must not leak into the one-chapter bundle, and later
        // chapters do not need audio to package the first chapter.
        await Director(source, llm).direct(book, 2);
      } finally {
        await scheduler.close();
      }
    }
    final result = await Process.run('dart', [
      'run',
      'tool/build_examples.dart',
      '--source-dir',
      '${root.path}/source',
      '--output-dir',
      '${root.path}/output',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final manifest = Map<String, Object?>.from(
      jsonDecode(await File('${root.path}/output/manifest.json').readAsString())
          as Map,
    );
    expect(manifest['audioBytes'], greaterThan(0));
    expect(manifest['durationMs'], 2000);
    await ExampleLibrary(target).install(
      manifest,
      (asset) =>
          File('${root.path}/output/${asset.split('/').last}').readAsBytes(),
    );
    final books = await Library(target).listBooks();
    expect(books, hasLength(2));
    expect(await target.list('scripts'), hasLength(2));
    for (final book in books) {
      final chapters = await Library(target).chapters(book.id);
      expect(chapters, hasLength(1));
      expect(chapters.single.state, ChapterState.synthesized);
      expect((await Library(source).getBook(book.id)).chapters, hasLength(5));
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
