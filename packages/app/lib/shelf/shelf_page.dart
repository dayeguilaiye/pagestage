import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/app_scope.dart';
import '../listening/player.dart';
import '../settings/settings_page.dart';
import 'book_page.dart';
import 'bookshelf.dart';
import 'delete_book.dart';
import 'reading_settings.dart';

/// The books the reader has imported, in a grid of covers.
class ShelfPage extends StatefulWidget {
  const ShelfPage({
    super.key,
    required this.bookshelf,
    required this.readingSettings,
  });

  final Bookshelf bookshelf;
  final ReadingSettings readingSettings;

  @override
  State<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends State<ShelfPage> {
  final _scroll = ScrollController();
  var _scrolled = false;

  List<ShelfBook>? _books;
  var _loadFailed = false;
  var _loads = 0;

  var _importing = false;
  ImportFailed? _failure;

  Listening? _listening;

  /// Where each book was last listened to, by book id.
  var _bookmarks = <String, ListeningBookmark>{};

  /// The book and chapter last heard, to refresh its bookmark on change.
  (String?, int)? _heard;

  @override
  void initState() {
    super.initState();
    widget.bookshelf.addListener(_load);
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final listening = AppScope.servicesOf(context)?.listening;
    if (listening == _listening && _loads > 0) return;
    _listening?.removeListener(_onListening);
    _listening = listening;
    listening?.addListener(_onListening);
    _load();
  }

  @override
  void dispose() {
    widget.bookshelf.removeListener(_load);
    _listening?.removeListener(_onListening);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final books = await widget.bookshelf.books();
      final bookmarks = await _bookmarksOf(books);
      if (!mounted || load != _loads) return;
      setState(() {
        _books = books;
        _bookmarks = bookmarks;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted || load != _loads) return;
      setState(() => _loadFailed = true);
    }
  }

  Future<Map<String, ListeningBookmark>> _bookmarksOf(
    List<ShelfBook> books,
  ) async {
    final listening = _listening;
    if (listening == null) return const {};
    final out = <String, ListeningBookmark>{};
    for (final book in books) {
      try {
        final bookmark = await listening.bookmark(book.id);
        if (bookmark != null) out[book.id] = bookmark;
      } catch (_) {
        // A missing bookmark only hides the progress bar.
      }
    }
    return out;
  }

  /// Refreshes the progress of the book being heard whenever its chapter
  /// changes or it stops, rather than on every tick.
  Future<void> _onListening() async {
    final state = _listening!.value;
    final heard = (state.bookId, state.playing ? state.chapter : -1);
    if (heard == _heard) return;
    final previous = _heard?.$1;
    _heard = heard;
    for (final id in {?previous, ?state.bookId}) {
      try {
        final bookmark = await _listening!.bookmark(id);
        if (!mounted) return;
        setState(() {
          _bookmarks = {..._bookmarks}..remove(id);
          if (bookmark != null) _bookmarks[id] = bookmark;
        });
      } catch (_) {
        // Keep the last known progress.
      }
    }
  }

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsPage(services: AppScope.servicesOf(context)!),
    ),
  );

  void _onScroll() {
    // Past the large title, the bar shows the small one.
    final scrolled = _scroll.offset > 40;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  Future<void> _import() async {
    if (_importing) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _importing = true;
      _failure = null;
    });
    final ImportOutcome outcome;
    try {
      outcome = await widget.bookshelf.importBook();
    } finally {
      if (mounted) setState(() => _importing = false);
    }
    if (!mounted) return;
    switch (outcome) {
      case BookImported(:final book):
        showPsToast(context, l.bookImported(book.title));
      case BookUpdated(
        :final book,
        :final addedChapters,
        :final changedChapters,
      ):
        showPsToast(
          context,
          addedChapters == 0 && changedChapters.isEmpty
              ? l.bookUnchanged(book.title)
              : l.bookUpdated(
                  book.title,
                  addedChapters,
                  changedChapters.length,
                ),
        );
      case ImportCancelled():
        break;
      case final ImportFailed failure:
        setState(() => _failure = failure);
    }
  }

  void _open(ShelfBook book) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookPage(
          bookshelf: widget.bookshelf,
          readingSettings: widget.readingSettings,
          book: book,
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext item, ShelfBook book) async {
    final l = AppLocalizations.of(context);
    final box = item.findRenderObject()! as RenderBox;
    final cover = box.localToGlobal(Offset.zero) & box.size;
    final choice = await showPsMenu(
      context,
      anchor: Rect.fromLTWH(cover.left, cover.top + 24, cover.width, 0),
      items: [
        PsMenuItem(#delete, l.deleteBook, icon: PsIcons.trash, danger: true),
      ],
    );
    if (choice == #delete && mounted) {
      await deleteBook(context, widget.bookshelf, book);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final books = _books;
    return Scaffold(
      bottomNavigationBar: const ListeningDock(),
      body: Column(
        children: [
          PsNavBar(
            title: l.shelfTitle,
            showTitle: _scrolled,
            divider: _scrolled,
            actions: [
              if (_listening != null)
                PsIconButton(
                  icon: PsIcons.settings,
                  label: l.settings,
                  onPressed: _openSettings,
                ),
              if (_importing)
                SizedBox.square(
                  dimension: PsSize.touch,
                  child: Semantics(
                    label: l.importing,
                    child: const Center(
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                )
              else
                PsIconButton(
                  icon: PsIcons.import,
                  label: l.importBook,
                  onPressed: _import,
                ),
            ],
          ),
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(child: PsLargeTitle(l.shelfTitle)),
                if (_failure case final failure?)
                  SliverToBoxAdapter(child: _failureBanner(failure, l)),
                if (books == null && _loadFailed)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: PsEmptyState(
                        title: l.shelfLoadFailed,
                        actions: [
                          PsButton(
                            label: l.retry,
                            expand: true,
                            onPressed: _load,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (books != null && books.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: PsEmptyState(
                        title: l.shelfEmptyTitle,
                        body: l.shelfEmptyBody,
                        actions: [
                          PsButton(
                            label: l.shelfEmptyAction,
                            variant: PsButtonVariant.primary,
                            expand: true,
                            loading: _importing,
                            onPressed: _import,
                          ),
                        ],
                      ),
                    ),
                  )
                else if (books != null) ...[
                  SliverToBoxAdapter(
                    child: _SectionHeader(l.shelfAll(books.length)),
                  ),
                  _grid(books, l),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: PsSpace.s8 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _failureBanner(ImportFailed failure, AppLocalizations l) {
    final (title, body) = switch (failure.reason) {
      ImportFailure.unsupportedFormat => (
        l.importUnsupportedTitle(failure.fileName),
        l.importUnsupportedBody,
      ),
      ImportFailure.drmProtected => (
        l.importDrmTitle(failure.fileName),
        l.importDrmBody,
      ),
      ImportFailure.empty => (
        l.importEmptyTitle(failure.fileName),
        l.importEmptyBody,
      ),
      ImportFailure.unreadable => (
        l.importUnreadableTitle(failure.fileName),
        l.importUnreadableBody,
      ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.s5, 0, PsSpace.s5, PsSpace.s6),
      child: PsBanner(
        tone: PsBannerTone.danger,
        title: title,
        body: body,
        actionLabel: l.importAnother,
        onAction: _import,
        onClose: () => setState(() => _failure = null),
      ),
    );
  }

  Widget _grid(List<ShelfBook> books, AppLocalizations l) {
    const itemWidth = 104.0;
    const minGap = 12.0;
    final scaler = MediaQuery.textScalerOf(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: PsSpace.s5),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          // Three columns on a phone, more on wider screens; covers shrink
          // rather than drop below three.
          final columns = math.max(
            3,
            ((width + PsSpace.s5) / (itemWidth + PsSpace.s5)).floor(),
          );
          final cover = math.min(
            itemWidth,
            ((width - (columns - 1) * minGap) / columns).floorToDouble(),
          );
          // Cover, title on up to two lines, the listening progress, then
          // one line of state.
          final extent =
              (cover * 1.5).roundToDouble() +
              PsSpace.s3 +
              scaler.scale(20) * 2 +
              PsSpace.s2 +
              2 +
              6 +
              scaler.scale(16);
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: PsSpace.s6,
              crossAxisSpacing: (width - columns * cover) / (columns - 1),
              mainAxisExtent: extent,
            ),
            itemCount: books.length,
            itemBuilder: (context, i) {
              final book = books[i];
              final bookmark = _bookmarks[book.id];
              return Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (item) => PsShelfItem(
                    key: ValueKey(book.id),
                    title: book.title,
                    width: cover,
                    progress: bookmark?.progress,
                    meta: bookmark == null
                        ? l.chapterCount(book.chapterCount)
                        : l.listenedTo(bookmark.chapter),
                    onTap: () => _open(book),
                    onLongPress: () => _menu(item, book),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.s5, 0, PsSpace.s5, PsSpace.s3),
      child: Text(
        label,
        style: PsType.subhead.copyWith(
          color: p.ink2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
