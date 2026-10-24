import 'dart:async';

import 'package:flutter/foundation.dart';

import 'bookshelf.dart';

part 'demo_books.dart';

/// A book held by [MemoryBookshelf].
@immutable
class MemoryBook {
  const MemoryBook({
    required this.title,
    required this.chapters,
    this.language = BookLanguage.chinese,
  });

  final String title;
  final BookLanguage language;
  final List<MemoryChapter> chapters;
}

@immutable
class MemoryChapter {
  const MemoryChapter(
    this.title,
    this.paragraphs, {
    this.state = ChapterState.unprofiled,
    this.volume,
  });

  final String title;
  final List<String> paragraphs;
  final ChapterState state;
  final String? volume;
}

/// Stands in for the file picker and the library: imports into [shelf] with
/// [MemoryBookshelf.add], or reports what went wrong.
typedef MemoryImport = FutureOr<ImportOutcome> Function(MemoryBookshelf shelf);

/// A [Bookshelf] in memory for previews and widget tests.
class MemoryBookshelf extends ChangeNotifier implements Bookshelf {
  /// [books] are in shelf order, most recently imported first.
  MemoryBookshelf({
    Iterable<MemoryBook> books = const [],
    MemoryImport? onImport,
    this.latency = Duration.zero,
  }) : _onImport = onImport {
    for (final book in books) {
      _books.add((id: _nextId(), book: book));
    }
  }

  /// 阿Q正传 on the shelf. Importing brings in Pride and Prejudice, or 阿Q正传
  /// again after it was deleted; with both on the shelf, an import fails.
  factory MemoryBookshelf.demo() {
    final demo = [
      _demoBook(_aq, BookLanguage.chinese),
      _demoBook(_pride, BookLanguage.english),
    ];
    return MemoryBookshelf(
      books: [demo.first],
      latency: const Duration(milliseconds: 400),
      onImport: (shelf) {
        for (final book in demo) {
          if (!shelf._books.any((b) => b.book.title == book.title)) {
            return BookImported(shelf.add(book));
          }
        }
        return const ImportFailed('红楼梦.epub', ImportFailure.unsupportedFormat);
      },
    );
  }

  static MemoryBook _demoBook(
    List<(String, List<String>)> chapters,
    BookLanguage language,
  ) {
    // 阿Q正传 shows every chapter state; Pride and Prejudice is not profiled.
    const states = [
      ChapterState.synthesized,
      ChapterState.synthesized,
      ChapterState.directed,
      ChapterState.profiled,
    ];
    final chinese = language == BookLanguage.chinese;
    return MemoryBook(
      title: chinese ? '阿Q正传' : 'Pride and Prejudice',
      language: language,
      chapters: [
        for (final (i, (title, paragraphs)) in chapters.indexed)
          MemoryChapter(
            title,
            paragraphs,
            state: chinese && i < states.length
                ? states[i]
                : ChapterState.unprofiled,
          ),
      ],
    );
  }

  final MemoryImport? _onImport;

  /// Added before every answer, to show loading states.
  final Duration latency;

  final _books = <({String id, MemoryBook book})>[];
  var _ids = 0;

  String _nextId() => 'memory-${++_ids}';

  /// Puts [book] at the front of the shelf.
  ShelfBook add(MemoryBook book) {
    final entry = (id: _nextId(), book: book);
    _books.insert(0, entry);
    notifyListeners();
    return _shelfBook(entry);
  }

  ShelfBook _shelfBook(({String id, MemoryBook book}) e) => ShelfBook(
    id: e.id,
    title: e.book.title,
    language: e.book.language,
    chapterCount: e.book.chapters.length,
  );

  MemoryBook _book(String id) => _books
      .firstWhere(
        (e) => e.id == id,
        orElse: () => throw StateError('No book $id'),
      )
      .book;

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  @override
  Future<List<ShelfBook>> books() async {
    await _wait();
    return [for (final e in _books) _shelfBook(e)];
  }

  @override
  Future<ImportOutcome> importBook() async {
    await _wait();
    return await _onImport?.call(this) ?? const ImportCancelled();
  }

  @override
  Future<void> deleteBook(String bookId) async {
    await _wait();
    _books.removeWhere((e) => e.id == bookId);
    notifyListeners();
  }

  @override
  Future<List<ChapterEntry>> chapters(String bookId) async {
    await _wait();
    return [
      for (final (i, c) in _book(bookId).chapters.indexed)
        ChapterEntry(
          number: i + 1,
          title: c.title,
          state: c.state,
          volume: c.volume,
        ),
    ];
  }

  @override
  Future<List<String>> paragraphs(String bookId, int chapter) async {
    await _wait();
    return _book(bookId).chapters[chapter - 1].paragraphs;
  }
}
