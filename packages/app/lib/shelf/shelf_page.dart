import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';
import '../l10n/app_localizations.dart';
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

  @override
  void initState() {
    super.initState();
    widget.bookshelf.addListener(_load);
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    widget.bookshelf.removeListener(_load);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final books = await widget.bookshelf.books();
      if (!mounted || load != _loads) return;
      setState(() {
        _books = books;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted || load != _loads) return;
      setState(() => _loadFailed = true);
    }
  }

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
      body: Column(
        children: [
          PsNavBar(
            title: l.shelfTitle,
            showTitle: _scrolled,
            divider: _scrolled,
            actions: [
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
          // Cover, title on up to two lines, then one line of state.
          final extent =
              (cover * 1.5).roundToDouble() +
              PsSpace.s3 +
              scaler.scale(20) * 2 +
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
              return Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (item) => PsShelfItem(
                    key: ValueKey(book.id),
                    title: book.title,
                    width: cover,
                    meta: l.chapterCount(book.chapterCount),
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
