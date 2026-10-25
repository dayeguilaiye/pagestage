import 'dart:io';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:pagestage_core/src/cli.dart';
import 'package:test/test.dart';
import 'support/epub_fixture.dart';
import 'support/generation_fakes.dart';

void main() {
  late Directory dir;
  late LocalStore store;
  late Library library;
  String? picked;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('library-final-');
    store = LocalStore('${dir.path}/library.sqlite');
    library = Library(store, pickFile: () async => picked);
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });
  Future<File> epub(List<int> bytes) async {
    final f = await File('${dir.path}/book.epub').writeAsBytes(bytes);
    picked = f.path;
    return f;
  }

  Future<File> txt(List<String> bodies, {String name = 'book'}) =>
      File('${dir.path}/$name.txt').writeAsString(
        [
          for (final e in bodies.indexed) 'Chapter ${e.$1 + 1}\n${e.$2}\n',
        ].join(),
      );

  for (final ncx in [false, true]) {
    test(
      'TOC partitions one file into chapters (${ncx ? 'NCX' : 'EPUB 3'})',
      () async {
        final file = await epub(
          epubFixture(
            bodies: {
              'text.xhtml':
                  '<h1 id="one">Chapter 1</h1><p>Hello <em>world</em> &amp; friend.</p><script>bad()</script><h1 id="two">Chapter 2</h1><p>Goodbye.</p>',
            },
            toc: ['text.xhtml#one', 'text.xhtml#two'],
            ncx: ncx,
          ),
        );
        final b = (await library.importFile(file.path)).book;
        expect(b.title, 'Fixture novel');
        expect(b.chapters.map((c) => c.title), ['Chapter 1', 'Chapter 2']);
        expect(b.chapters.map((c) => c.text), [
          'Hello world & friend.\n',
          'Goodbye.\n',
        ]);
      },
    );
  }
  test(
    'TOC merges multiple spine documents, including escaped paths',
    () async {
      final f = await epub(
        epubFixture(
          bodies: {
            'part 1.xhtml': '<h1>Chapter 1</h1><p>First.</p>',
            'part2.xhtml': '<p>Continued.</p>',
            'part3.xhtml': '<h1>Chapter 2</h1><p>最后。</p>',
          },
          toc: ['part%201.xhtml', 'part3.xhtml'],
        ),
      );
      final b = (await library.importFile(f.path)).book;
      expect(b.chapters, hasLength(2));
      expect(b.chapters.first.text, 'First.\nContinued.\n');
      expect(b.language, 'zh');
    },
  );
  test('no TOC imports each spine document in reading order', () async {
    final f = await epub(
      epubFixture(
        bodies: {
          'z.xhtml': '<h1>Beginning</h1><p>One.</p>',
          'a.xhtml': '<h2>End</h2><p>Two.</p>',
        },
      ),
    );
    final b = (await library.importFile(f.path)).book;
    expect(b.chapters.map((c) => c.title), ['Beginning', 'End']);
    expect(b.chapters.map((c) => c.text), ['One.\n', 'Two.\n']);
  });
  test('font obfuscation still permits text import', () async {
    final f = await epub(
      epubFixture(
        bodies: {'a.xhtml': '<p>Readable.</p>'},
        encryption: 'http://www.idpf.org/2008/embedding',
      ),
    );
    expect(
      (await library.importFile(f.path)).book.chapters.single.text,
      'Readable.\n',
    );
  });
  test(
    'DRM and malformed anchors fail atomically with specific picker result',
    () async {
      await epub(
        epubFixture(
          bodies: {'a.xhtml': '<p>Protected.</p>'},
          encryption: 'http://www.w3.org/2001/04/xmlenc#aes128-cbc',
        ),
      );
      expect(
        (await library.importBook() as ImportFailed).reason,
        ImportFailure.drmProtected,
      );
      await epub(
        epubFixture(
          bodies: {'a.xhtml': '<p>Missing anchor.</p>'},
          toc: ['a.xhtml#absent'],
        ),
      );
      expect(
        (await library.importBook() as ImportFailed).reason,
        ImportFailure.unreadable,
      );
      await epub(
        epubFixture(
          bodies: {'a.xhtml': '<p>Text.</p>'},
          extra: {'../escaped.txt': 'Escape'},
        ),
      );
      expect(
        (await library.importBook() as ImportFailed).reason,
        ImportFailure.unreadable,
      );
      expect(await library.books(), isEmpty);
      expect(await File('${dir.parent.path}/escaped.txt').exists(), isFalse);
    },
  );
  test(
    'CLI uses the common EPUB import and reports DRM without a partial book',
    () async {
      final f = await epub(epubFixture(bodies: {'a.xhtml': '<p>Novel.</p>'}));
      final out = StringBuffer();
      final err = StringBuffer();
      expect(
        await runCli(
          ['--data-dir', '${dir.path}/cli', 'import', f.path],
          output: out,
          errorOutput: err,
          environment: {},
        ),
        0,
      );
      expect(out.toString(), contains('Fixture novel'));
      await epub(
        epubFixture(bodies: {'a.xhtml': '<p>Novel.</p>'}, rights: true),
      );
      expect(
        await runCli(
          ['--data-dir', '${dir.path}/cli', 'import', f.path],
          output: out,
          errorOutput: err,
          environment: {},
        ),
        65,
      );
      expect(err.toString(), contains('DRM'));
    },
  );
  test(
    'update preserves unchanged audio/cast, invalidates modified chapter, appends tail',
    () async {
      final initial = await txt(['One.', 'Two.', 'Three.', 'Four.', 'Five.']);
      final b = await library.importTxt(initial.path);
      final llm = GenerationLlm();
      final tts = GenerationTts();
      final scheduler = await Scheduler.open(
        store: store,
        profileLlm: llm,
        directorLlm: llm,
        ttsAdapters: {'minimax': tts},
      );
      await scheduler.enqueue(b.id, TaskKind.profile, through: 5);
      await scheduler.idle;
      await Casting(store).recommend(b, providers: {'minimax'});
      await scheduler.enqueue(b.id, TaskKind.synthesize, through: 5);
      await scheduler.idle;
      await scheduler.close();
      final cast = (await CastRepository(store).get(b.id)).toJson();
      final voices = (await Casting(
        store,
      ).getCasting(b.id)).voices.values.map((v) => v.toJson()).toList();
      final before = (await AudioRepository(store).get(b.id, 1))!.toJson();
      final updated = await txt([
        'One.',
        'Two.',
        'Three.',
        'Four changed.',
        'Five.',
        'Six.',
      ], name: 'updated');
      picked = updated.path;
      final result = await library.importBook() as BookUpdated;
      expect(result.book.id, b.id);
      expect(result.addedChapters, 1);
      expect(result.changedChapters, [4]);
      expect(await library.books(), hasLength(1));
      expect((await library.getBook(b.id)).chapters, hasLength(6));
      expect((await AudioRepository(store).get(b.id, 1))!.toJson(), before);
      expect(await ScriptRepository(store).get(b.id, 4), isNull);
      expect(await AudioRepository(store).get(b.id, 4), isNull);
      expect((await CastRepository(store).get(b.id)).toJson(), cast);
      expect(
        (await Casting(
          store,
        ).getCasting(b.id)).voices.values.map((v) => v.toJson()).toList(),
        voices,
      );
      expect((await library.chapters(b.id))[3].state, ChapterState.profiled);
      final repeat = await library.importFile(updated.path);
      expect(repeat.addedChapters, 0);
      expect(repeat.changedChapters, isEmpty);
      await library.importFile(initial.path);
      expect((await library.getBook(b.id)).chapters, hasLength(6));
    },
  );
  test(
    'changed first three and insufficient matching prefix create distinct books',
    () async {
      final b = await library.importTxt(
        (await txt(['One.', 'Two.', 'Three.', 'Four.'])).path,
      );
      final changed = await library.importFile(
        (await txt([
          'Different.',
          'Two.',
          'Three.',
          'Four.',
        ], name: 'other')).path,
      );
      expect(changed.book.id, isNot(b.id));
      expect(changed.updated, isFalse);
      final short = await library.importFile(
        (await txt(['One.', 'Two.'], name: 'short')).path,
      );
      expect(short.updated, isFalse);
      expect(await library.books(), hasLength(3));
    },
  );
  test(
    'EPUB updates a TXT book by matching chapter bodies across formats',
    () async {
      final b = await library.importTxt(
        (await txt(['One.', 'Two.', 'Three.'])).path,
      );
      final f = await epub(
        epubFixture(
          bodies: {
            for (final e in ['One.', 'Two.', 'Three.', 'Four.'].indexed)
              '${e.$1}.xhtml': '<h1>Chapter ${e.$1 + 1}</h1><p>${e.$2}</p>',
          },
        ),
      );
      final result = await library.importFile(f.path);
      expect(result.updated, isTrue);
      expect(result.book.id, b.id);
      expect(result.addedChapters, 1);
    },
  );
}
