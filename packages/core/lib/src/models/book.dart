import 'dart:convert';

import 'package:crypto/crypto.dart';

/// An imported novel. Chapter numbers are one-based.
class Book {
  Book({
    required this.id,
    required this.title,
    required this.language,
    required this.sourcePath,
    required List<Chapter> chapters,
  }) : chapters = List.unmodifiable(chapters);

  final String id;
  final String title;
  final String language;
  final String sourcePath;
  final List<Chapter> chapters;

  Chapter chapter(int number) {
    if (number < 1 || number > chapters.length) {
      throw RangeError.range(number, 1, chapters.length, 'chapter');
    }
    return chapters[number - 1];
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'language': language,
    'sourcePath': sourcePath,
    'chapters': chapters.map((chapter) => chapter.toJson()).toList(),
  };

  factory Book.fromJson(Map<String, Object?> json) => Book(
    id: json['id'] as String,
    title: json['title'] as String,
    language: json['language'] as String,
    sourcePath: json['sourcePath'] as String,
    chapters: (json['chapters'] as List)
        .map((item) => Chapter.fromJson(Map<String, Object?>.from(item as Map)))
        .toList(),
  );
}

/// Text is the exact decoded body, excluding the heading line.
/// All source ranges in downstream scripts use UTF-16 offsets into [text].
class Chapter {
  const Chapter({
    required this.number,
    required this.title,
    required this.text,
    this.volume,
  });

  final int number;
  final String title;
  final String text;
  final String? volume;
  String get textHash => sha256.convert(utf8.encode(text)).toString();

  Map<String, Object?> toJson() => {
    'number': number,
    'title': title,
    'text': text,
    'textHash': textHash,
    if (volume != null) 'volume': volume,
  };

  factory Chapter.fromJson(Map<String, Object?> json) => Chapter(
    number: json['number'] as int,
    title: json['title'] as String,
    text: json['text'] as String,
    volume: json['volume'] as String?,
  );
}
