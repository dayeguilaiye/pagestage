import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'encoding/gb18030.dart';
import 'package:path/path.dart' as p;

import 'local_store.dart';
import 'models/book.dart';

/// Imports TXT novels and provides the saved books and chapter bodies.
class Library {
  Library(this.store);
  final LocalStore store;

  Future<Book> importTxt(String path, {String? title}) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      text = decodeGb18030(bytes);
    }
    if (text.startsWith('\ufeff')) text = text.substring(1);
    if (text.trim().isEmpty) throw const FormatException('The book is empty.');
    final book = Book(
      id: sha256.convert(utf8.encode(text)).toString().substring(0, 24),
      title: title ?? p.basenameWithoutExtension(path),
      language: RegExp(r'[\u3400-\u9fff]').hasMatch(text) ? 'zh' : 'en',
      sourcePath: file.absolute.path,
      chapters: _chapters(text),
    );
    await store.put('books', book.id, book.toJson());
    return book;
  }

  Future<Book> getBook(String id) async {
    final data = await store.get('books', id);
    if (data == null) throw StateError('Book not found: $id');
    return Book.fromJson(data);
  }

  Future<List<Book>> listBooks() async =>
      (await store.list('books')).map(Book.fromJson).toList();

  List<Chapter> _chapters(String text) {
    final headings = RegExp(
      r'^[ \t\u3000]*(?:第[〇零一二三四五六七八九十百千万两0-9]+[章回](?:[ \t\u3000:：.、—-]+[^\r\n]*)?|Chapter[ \t]+(?:[0-9]+|[IVXLCDM]+)(?:[. :—-][^\r\n]*)?)[ \t]*(?:\r?\n|$)',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(text).toList();
    final volumes = RegExp(
      r'^[ \t\u3000]*第[〇零一二三四五六七八九十百千万两0-9]+卷(?:[ \t\u3000:：.、—-]+[^\r\n]*)?[ \t]*(?:\r?\n|$)',
      multiLine: true,
    ).allMatches(text).toList();
    final chapters = <Chapter>[];
    for (var i = 0; i < headings.length; i++) {
      final heading = headings[i];
      var end = i + 1 < headings.length ? headings[i + 1].start : text.length;
      String? volume;
      for (final grouping in volumes) {
        if (grouping.start < heading.start) volume = grouping.group(0)!.trim();
        if (grouping.start >= heading.end && grouping.start < end) {
          end = grouping.start;
        }
      }
      chapters.add(
        Chapter(
          number: i + 1,
          title: heading.group(0)!.trim(),
          text: text.substring(heading.end, end),
          volume: volume,
        ),
      );
    }
    if (chapters.isNotEmpty) return chapters;
    final characters = text.runes.toList();
    for (var offset = 0; offset < characters.length; offset += 5000) {
      final end = offset + 5000 < characters.length
          ? offset + 5000
          : characters.length;
      final number = chapters.length + 1;
      chapters.add(
        Chapter(
          number: number,
          title: RegExp(r'[\u3400-\u9fff]').hasMatch(text)
              ? '第$number章'
              : 'Chapter $number',
          text: String.fromCharCodes(characters.sublist(offset, end)),
        ),
      );
    }
    return chapters;
  }
}
