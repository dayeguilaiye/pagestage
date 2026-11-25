import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late LocalStore store;
  late Library library;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pagestage-chapters-');
    store = LocalStore('${directory.path}/library.sqlite');
    library = Library(store);
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });

  Future<String> write(String name, String text) async =>
      (await File('${directory.path}/$name.txt').writeAsString(text)).path;
  Future<LibraryImport> importText(String name, String text) async =>
      library.importFile(await write(name, text));
  Future<List<Chapter>> chapters(String text) async =>
      (await importText('book', text)).book.chapters;

  const synopsis = '内容简介：\n少年在边陲小镇长大，一次意外让他踏上了寻找失落王国的旅途。\n';

  group('front matter', () {
    test('text before the first heading becomes the opening chapter', () async {
      const front = '《远行》\n作者：某人\n\n$synopsis\n';
      final zh = await chapters('$front第一章 出发\n天亮了。\n第二章 归来\n天黑了。\n');
      expect(zh.map((c) => c.title), ['开篇', '第一章 出发', '第二章 归来']);
      expect(zh.map((c) => c.number), [1, 2, 3]);
      expect(zh.first.text, front);
      expect(zh[1].text, '天亮了。\n');
      final en = await chapters(
        'A Long Way Home\n\nTwo brothers cross a frozen country to find '
        'their father.\n\nChapter 1\nSnow.\nChapter 2\nThaw.\n',
      );
      expect(en.map((c) => c.title), ['Opening', 'Chapter 1', 'Chapter 2']);
      expect(en.first.text, startsWith('A Long Way Home'));
    });

    test('a bare title and author line is still dropped', () async {
      expect(
        (await chapters(
          '斗破苍穹\n作者：天蚕土豆\n\n第一章 陨落的天才\n正文。\n',
        )).map((c) => c.title),
        ['第一章 陨落的天才'],
      );
      // Twenty characters, not counting whitespace, make an opening.
      for (final (front, kept) in [
        ('一二三四五 六七八九十\n一二三四五　六七八九\n', false),
        ('一二三四五 六七八九十\n一二三四五　六七八九十\n', true),
      ]) {
        final titles = (await chapters(
          '$front第一章 起\n正文。\n',
        )).map((c) => c.title);
        expect(titles, [if (kept) '开篇', '第一章 起'], reason: front);
      }
    });

    test('ends before a volume heading and belongs to no volume', () async {
      final result = await chapters('$synopsis第一卷 起\n第一章 风\n正文。\n');
      expect(result.map((c) => c.title), ['开篇', '第一章 风']);
      expect(result.first.text, synopsis);
      expect(result.first.volume, isNull);
      expect(result.last.volume, '第一卷 起');
    });
  });

  group('named headings', () {
    test('front and back matter lines start their own chapters', () async {
      final result = await chapters(
        [
          '楔子\n很久以前。\n',
          '第一章 出发\n天亮了。\n',
          '第二章 归来\n天黑了。\n',
          '尾声\n他们回家了。\n',
          '番外一 重逢\n多年以后。\n',
          '番外：后日谈\n又过了一年。\n',
          '后记\n谢谢阅读。\n',
        ].join(),
      );
      expect(result.map((c) => c.title), [
        '楔子',
        '第一章 出发',
        '第二章 归来',
        '尾声',
        '番外一 重逢',
        '番外：后日谈',
        '后记',
      ]);
      expect(result.map((c) => c.text), [
        '很久以前。\n',
        '天亮了。\n',
        '天黑了。\n',
        '他们回家了。\n',
        '多年以后。\n',
        '又过了一年。\n',
        '谢谢阅读。\n',
      ]);
      expect(result.map((c) => c.number), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('every listed word, numbered or titled, is a heading', () async {
      for (final heading in [
        '序章',
        '序章 黎明',
        '序言',
        '序',
        '序一',
        '引子',
        '前言：写在前面',
        '终章 归途',
        '最终章',
        '番外篇',
        '番外2',
        '番外·雪夜',
        '　　尾声',
        'Prologue',
        'PROLOGUE: The Storm',
        'Interlude II — Rain',
        'Epilogue: Ten Years Later',
      ]) {
        final result = await chapters('$heading\n正文。\n第一章 起\n正文。\n');
        expect(result.map((c) => c.title), [
          heading.trim(),
          '第一章 起',
        ], reason: heading);
      }
    });

    test(
      'sentences and long lines that start with those words stay text',
      () async {
        const lines = [
          '序言写得很长，长到占了这本书前面的好几页，读者往往直接跳过它。',
          '序言：作者在这一段里絮絮叨叨地讲了自己写这本书的前因后果和许多感谢。',
          '前言不搭后语',
          '序幕',
          '尾声。',
          'Prologues are often skipped.',
        ];
        expect(lines[1].runes.length, greaterThan(30));
        final result = await chapters('第一章 起\n${lines.join('\n')}\n');
        expect(result.map((c) => c.title), ['第一章 起']);
        expect(result.single.text, '${lines.join('\n')}\n');
      },
    );

    test('a heading line may be up to 30 characters long', () async {
      final short = '番外：${'雪' * 27}';
      final long = '番外：${'雪' * 28}';
      expect(
        (await chapters(
          '第一章 起\n正文。\n$short\n正文。\n$long\n正文。\n',
        )).map((c) => c.title),
        ['第一章 起', short],
      );
    });

    test('without numbered chapters, named lines do not split', () async {
      // "Chapter One" is not a recognised heading, so this text has none.
      final story = 'Chapter One\n${'It was a long night. ' * 50}\n' * 12;
      final text = 'Prologue\nThe storm.\n${story}Epilogue\nDawn.\n';
      final result = await chapters(text);
      expect(result.length, greaterThan(2));
      expect(result.first.title, 'Chapter 1');
      expect(result.first.text, startsWith('Prologue\n'));
      expect(result.map((c) => c.text).join(), text);
    });

    test('a named line with nothing under it is not a chapter', () async {
      expect((await chapters('序章\n第一章 开始\n正文。\n尾声\n')).map((c) => c.title), [
        '第一章 开始',
      ]);
    });
  });

  group('text without headings', () {
    String paragraphs(int count, int length) => [
      for (var i = 0; i < count; i++)
        '${String.fromCharCode(0x4e00 + i) * (length - 1)}\n',
    ].join();

    test('splits at the line break before the 5000th character', () async {
      final text = paragraphs(15, 1200);
      final result = await chapters(text);
      expect(result.map((c) => c.text.runes.length), [4800, 4800, 4800, 3600]);
      expect(result.map((c) => c.title), ['第1章', '第2章', '第3章', '第4章']);
      expect(result.map((c) => c.text).join(), text);
      for (final chapter in result) {
        expect(chapter.text, endsWith('\n'));
      }
    });

    test('looks ahead for a line break when none is close behind', () async {
      final text = '${'甲' * 5300}\n${paragraphs(5, 1000)}';
      final result = await chapters(text);
      expect(result.first.text, '${'甲' * 5300}\n');
      expect(result.map((c) => c.text).join(), text);
    });

    test('blank lines stay with the chapter before them', () async {
      final text = '${'甲' * 4999}\n\n${'乙' * 3000}';
      final result = await chapters(text);
      expect(result.map((c) => c.text), ['${'甲' * 4999}\n\n', '乙' * 3000]);
    });

    test('without line breaks, splits after a sentence', () async {
      // Eleven characters each, so no sentence ends at the 5000th.
      const sentence = '他又轻声说：“走吧。”';
      expect(sentence.runes.length, 11);
      final text = sentence * 1000;
      final result = await chapters(text);
      expect(result.first.text.runes.length, 4994);
      for (final chapter in result) {
        expect(chapter.text, startsWith('他'));
        expect(chapter.text, endsWith('。”'));
      }
      expect(result.map((c) => c.text).join(), text);
      const english = 'It rained all day. ';
      final rain = (await chapters(english * 400)).map((c) => c.text).toList();
      expect(rain, hasLength(2));
      expect(rain.first, endsWith('day. '));
      expect(rain.last, startsWith('It rained'));
    });

    test('cuts exactly at 5000 when nothing else is near', () async {
      // A decimal point is not a sentence end.
      final text = '${'x' * 4990} pi 3.14 ${'y' * 6000}';
      final result = await chapters(text);
      expect(result.first.text.runes.length, 5000);
      expect(result.first.title, 'Chapter 1');
      final wide = '𠀀' * 12000;
      final pieces = await chapters(wide);
      expect(pieces.map((c) => c.text.runes.length), [5000, 5000, 2000]);
      expect(pieces.map((c) => c.text).join(), wide);
      for (final piece in pieces) {
        expect(piece.text.runes.every((rune) => rune == 0x20000), isTrue);
      }
    });

    test('trailing blank space is not a chapter of its own', () async {
      final result = await chapters('${'甲' * 5000}\n   ');
      expect(result.single.text, '${'甲' * 5000}\n   ');
    });
  });

  group('updates', () {
    const body = '第一章 起\n一。\n第二章 承\n二。\n第三章 转\n三。\n';
    const next = '第四章 合\n四。\n';
    const blurb = '内容简介：少年离开小镇，去寻找传说中的失落王国。\n';
    const newer = '内容简介：少年离开小镇，去寻找传说中的失落王国。已更新至第四章。\n';

    test('a changed opening is updated in place', () async {
      final first = await importText('v1', '$blurb$body');
      final second = await importText('v2', '$newer$body$next');
      expect(second.updated, isTrue);
      expect(second.book.id, first.book.id);
      expect(second.changedChapters, [1]);
      expect(second.addedChapters, 1);
      expect(second.book.chapters.first.text, newer);
      expect(await library.books(), hasLength(1));
    });

    test('an opening only one edition has never moves chapters', () async {
      final plain = await importText('plain', '远行\n$body');
      final added = await importText('added', '$blurb$body$next');
      expect(added.updated, isTrue);
      expect(added.book.id, plain.book.id);
      expect(added.changedChapters, isEmpty);
      expect(added.addedChapters, 1);
      expect(added.book.chapters.map((c) => c.title), [
        '第一章 起',
        '第二章 承',
        '第三章 转',
        '第四章 合',
      ]);
      await library.deleteBook(plain.book.id);
      final opened = await importText('opened', '$blurb$body');
      final dropped = await importText('dropped', '$body$next');
      expect(dropped.updated, isTrue);
      expect(dropped.book.id, opened.book.id);
      expect(dropped.changedChapters, isEmpty);
      expect(dropped.addedChapters, 1);
      expect(dropped.book.chapters.map((c) => c.title), [
        '开篇',
        '第一章 起',
        '第二章 承',
        '第三章 转',
        '第四章 合',
      ]);
    });

    test("the same file again keeps an earlier version's chapters", () async {
      String id(String text) =>
          sha256.convert(utf8.encode(text)).toString().substring(0, 24);
      Future<void> stored(String text, List<Chapter> chapters) async {
        final book = Book(
          id: id(text),
          title: 'legacy',
          language: 'zh',
          sourcePath: await write('legacy', text),
          chapters: chapters,
        );
        await store.put('books', book.id, book.toJson());
      }

      // Front matter used to be dropped.
      const opened = '$blurb$body';
      await stored(opened, const [
        Chapter(number: 1, title: '第一章 起', text: '一。\n'),
        Chapter(number: 2, title: '第二章 承', text: '二。\n'),
        Chapter(number: 3, title: '第三章 转', text: '三。\n'),
      ]);
      // Untitled text used to be cut every 5000 characters.
      final untitled = '${'段' * 1199}\n' * 10;
      await stored(untitled, [
        for (var n = 1; n <= 3; n++)
          Chapter(
            number: n,
            title: '第$n章',
            text: untitled.substring(
              (n - 1) * 5000,
              min(n * 5000, untitled.length),
            ),
          ),
      ]);
      for (final text in [opened, untitled]) {
        final before = (await library.getBook(id(text))).toJson();
        final again = await library.importFile(await write('legacy', text));
        expect(again.updated, isTrue);
        expect(again.book.id, id(text));
        expect(again.changedChapters, isEmpty);
        expect(again.addedChapters, 0);
        expect(again.book.toJson()['chapters'], before['chapters']);
      }
    });
  });
}
