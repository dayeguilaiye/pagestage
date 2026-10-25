import 'package:flutter/material.dart';

import '../shelf/reader_page.dart';
import 'app_scope.dart';

/// Opens the reader on [bookId] at chapter number [chapter], for reading
/// along from the player, in place of the current route when [replace].
/// Does nothing if the book has gone.
Future<void> openReaderAt(
  BuildContext context,
  String bookId,
  int chapter, {
  bool replace = false,
}) async {
  final scope = AppScope.of(context);
  final navigator = Navigator.of(context);
  try {
    final books = await scope.bookshelf.books();
    final book = books.where((b) => b.id == bookId).firstOrNull;
    if (book == null) return;
    final chapters = await scope.bookshelf.chapters(bookId);
    if (chapters.isEmpty || !navigator.mounted) return;
    final index = chapters.indexWhere((c) => c.number == chapter);
    final route = MaterialPageRoute<void>(
      builder: (_) => ReaderPage(
        bookshelf: scope.bookshelf,
        readingSettings: scope.readingSettings,
        book: book,
        chapters: chapters,
        start: index < 0 ? 0 : index,
      ),
    );
    replace ? navigator.pushReplacement(route) : navigator.push(route);
  } catch (_) {
    // The shelf shows the book's absence on its own.
  }
}
