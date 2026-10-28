import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late LocalStore store;
  late Library library;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pagestage-library-');
    store = LocalStore('${directory.path}/library.sqlite');
    library = Library(store);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  test('imports UTF-8 text and persists its chapters across reopen', () async {
    final file = await File(
      '${directory.path}/novel.txt',
    ).writeAsString('第一章 初见\n你好。\n\n第二章 重逢\n又见面了。\n');
    final book = await library.importTxt(file.path);
    expect(book.title, 'novel');
    expect(book.language, 'zh');
    expect(book.chapters.map((chapter) => chapter.title), ['第一章 初见', '第二章 重逢']);
    expect(book.chapters.first.text, '你好。\n\n');
    expect(book.chapters.last.number, 2);
    await store.close();
    store = LocalStore('${directory.path}/library.sqlite');
    library = Library(store);
    expect((await library.getBook(book.id)).chapters.last.text, '又见面了。\n');
    expect(await library.listBooks(), hasLength(1));
  });

  test('existence and chapter count are read without the book text', () async {
    final file = await File(
      '${directory.path}/novel.txt',
    ).writeAsString('第一章 初见\n你好。\n\n第二章 重逢\n又见面了。\n');
    final book = await library.importTxt(file.path);
    expect(await store.exists('books', book.id), isTrue);
    expect(await library.chapterCount(book.id), 2);
    await library.deleteBook(book.id);
    expect(await store.exists('books', book.id), isFalse);
    expect(await store.arrayLength('books', book.id, r'$.chapters'), isNull);
    await expectLater(library.chapterCount(book.id), throwsStateError);
  });

  test('closing lets queries already sent finish', () async {
    final value = {'text': '长' * 200000};
    await store.put('settings', 'probe', value);
    final reads = [
      for (var i = 0; i < 20; i++) store.get('settings', 'probe'),
      store.exists('settings', 'probe'),
    ];
    await store.close();
    final results = await Future.wait(reads);
    expect(results.first, value);
    expect(results.last, isTrue);
  });

  test('GBK and GB18030 decode to the same chapters as UTF-8', () async {
    const text = '第一章 初见\n你好。\n';
    final utf8File = await File(
      '${directory.path}/utf8.txt',
    ).writeAsString(text);
    // Bytes independently encoded with Python gbk, not the production codec.
    final gbkFile = await File('${directory.path}/gbk.txt').writeAsBytes([
      181,
      218,
      210,
      187,
      213,
      194,
      32,
      179,
      245,
      188,
      251,
      10,
      196,
      227,
      186,
      195,
      161,
      163,
      10,
    ]);
    final unicode = await library.importTxt(utf8File.path);
    final legacy = await library.importTxt(gbkFile.path);
    expect(
      legacy.chapters.map((c) => c.toJson()),
      unicode.chapters.map((c) => c.toJson()),
    );
    final rare = await File(
      '${directory.path}/gb18030.txt',
    ).writeAsBytes([181, 218, 210, 187, 213, 194, 10, 149, 50, 130, 54]);
    expect((await library.importTxt(rare.path)).chapters.single.text, '𠀀');
  });

  test('imports the complete five-chapter public domain fixtures', () async {
    final fixtureRoot = Directory.current.path.endsWith('/core')
        ? '../../test/fixtures/books'
        : 'test/fixtures/books';
    final chinese = await library.importTxt('$fixtureRoot/aq-zh.txt');
    final english = await library.importTxt(
      '$fixtureRoot/pride-and-prejudice-en.txt',
    );
    expect(chinese.language, 'zh');
    expect(chinese.chapters.map((c) => c.title), [
      '第一章　序',
      '第二章　优胜记略',
      '第三章　续优胜记略',
      '第四章　恋爱的悲剧',
      '第五章　生计问题',
    ]);
    expect(english.language, 'en');
    expect(english.chapters.map((c) => c.title), [
      'Chapter I.',
      'Chapter II.',
      'Chapter III.',
      'Chapter IV.',
      'Chapter V.',
    ]);
    expect(chinese.chapters.first.text, contains('我要给阿Q做正传'));
    expect(
      english.chapters.first.text,
      contains('It is a truth universally acknowledged'),
    );
  });

  test(
    'volume headings group chapters without becoming body or chapters',
    () async {
      final file = await File(
        '${directory.path}/volumes.txt',
      ).writeAsString('第一卷 起\n第1回 风\n第一回的正文。\n第二卷 承\n第2回 雨\n第二回的正文。');
      final chapters = (await library.importTxt(file.path)).chapters;
      expect(chapters, hasLength(2));
      expect(chapters.first.volume, '第一卷 起');
      expect(chapters.last.volume, '第二卷 承');
      expect(chapters.first.text, '第一回的正文。\n');
    },
  );

  test(
    'untitled text is split near 5000 Unicode characters without loss',
    () async {
      final body = '${'文' * 4999}𠀀${'字' * 7001}';
      final file = await File(
        '${directory.path}/untitled.txt',
      ).writeAsString(body);
      final chapters = (await library.importTxt(file.path)).chapters;
      expect(chapters.map((c) => c.text.runes.length), [5000, 5000, 2001]);
      expect(chapters.map((c) => c.text).join(), body);
      expect(chapters.map((c) => c.title), ['第1章', '第2章', '第3章']);
    },
  );
}
