/// The library interface shared by production screens and in-memory previews.
///
/// Listeners are notified whenever books are added or deleted, or a chapter
/// changes state.
abstract interface class Bookshelf {
  void addListener(void Function() listener);
  void removeListener(void Function() listener);

  /// Most recently imported first.
  Future<List<ShelfBook>> books();

  /// Lets the reader pick a file with the system picker and imports it: a
  /// TXT or EPUB book, or a script or audio package. A package for a book
  /// already on the shelf replaces that book's cast, scripts and audio once
  /// [confirmReplace] agrees, given the book's title.
  Future<ImportOutcome> importBook({
    Future<bool> Function(String title)? confirmReplace,
  });

  /// Imports the file at [path] as [importBook] imports a picked one, for a
  /// file another app opened in pagestage.
  Future<ImportOutcome> importPath(
    String path, {
    Future<bool> Function(String title)? confirmReplace,
  });

  /// Deletes the book with its chapters, cast, scripts and audio.
  Future<void> deleteBook(String bookId);

  Future<List<ChapterEntry>> chapters(String bookId);

  /// A chapter's text, one string per paragraph, without the heading.
  Future<List<String>> paragraphs(String bookId, int chapter);
}

enum BookLanguage { chinese, english }

class ShelfBook {
  const ShelfBook({
    required this.id,
    required this.title,
    required this.language,
    required this.chapterCount,
  });

  final String id;
  final String title;
  final BookLanguage language;
  final int chapterCount;
}

/// How far a chapter has come on its way to being heard.
enum ChapterState {
  /// Outside the profiled range.
  unprofiled,
  profiled,
  directed,
  synthesized,
}

class ChapterEntry {
  const ChapterEntry({
    required this.number,
    required this.title,
    required this.state,
    this.volume,
  });

  /// One-based, as in core.
  final int number;
  final String title;
  final ChapterState state;

  /// The 卷 the chapter belongs to. Volumes only group chapters.
  final String? volume;
}

sealed class ImportOutcome {
  const ImportOutcome();
}

final class BookImported extends ImportOutcome {
  const BookImported(this.book);
  final ShelfBook book;
}

final class BookUpdated extends ImportOutcome {
  const BookUpdated(
    this.book, {
    required this.addedChapters,
    required this.changedChapters,
  });
  final ShelfBook book;
  final int addedChapters;
  final List<int> changedChapters;
}

/// A script or audio package was installed.
final class PackageImported extends ImportOutcome {
  const PackageImported(
    this.book, {
    required this.scriptChapters,
    required this.audioChapters,
    required this.replaced,
  });
  final ShelfBook book;

  /// How many chapters arrived already directed, and already voiced.
  final int scriptChapters;
  final int audioChapters;

  /// Whether it took the place of a book already on the shelf.
  final bool replaced;
}

/// The reader closed the picker without choosing a file.
final class ImportCancelled extends ImportOutcome {
  const ImportCancelled();
}

final class ImportFailed extends ImportOutcome {
  const ImportFailed(this.fileName, this.reason);
  final String fileName;
  final ImportFailure reason;
}

enum ImportFailure {
  unsupportedFormat,
  drmProtected,

  /// Decoded, but there is no text in it.
  empty,

  /// Neither UTF-8 nor GBK, or the file could not be read.
  unreadable,

  /// A package that is damaged, incomplete or made by a newer pagestage.
  invalidPackage,
}
