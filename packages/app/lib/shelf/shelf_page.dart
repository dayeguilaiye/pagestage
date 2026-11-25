import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/app_scope.dart';
import '../listening/player.dart';
import '../settings/settings_page.dart';
import 'book_page.dart';
import 'bookshelf.dart';
import 'delete_book.dart';
import 'import_feedback.dart';
import 'reading_settings.dart';
import 'share_sheet.dart';

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

  /// The bundled examples, labelled as such on their covers.
  var _samples = <String>{};

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
    final generation = AppScope.servicesOf(context)?.generation;
    try {
      final books = await widget.bookshelf.books();
      final bookmarks = await _bookmarksOf(books);
      Set<String> samples = const {};
      try {
        samples = await generation?.samples() ?? const {};
      } catch (_) {
        // Unlabelled, an example is still a book.
      }
      if (!mounted || load != _loads) return;
      setState(() {
        _books = books;
        _bookmarks = bookmarks;
        _samples = samples;
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

  void _openSettings(AppServices services) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsPage(
        services: services,
        readingSettings: widget.readingSettings,
      ),
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
      outcome = await widget.bookshelf.importBook(
        confirmReplace: _confirmReplace,
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
    if (!mounted) return;
    if (outcome case final ImportFailed failure) {
      setState(() => _failure = failure);
    } else if (importedMessage(l, outcome) case final message?) {
      showPsToast(context, message);
    }
  }

  /// A package for a book already on the shelf takes its place only once
  /// the reader agrees.
  Future<bool> _confirmReplace(String title) async =>
      mounted && await confirmReplaceBook(context, title);

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
    final services = AppScope.servicesOf(context);
    final packages = services?.packages;
    final choice = await showPsMenu(
      context,
      anchor: Rect.fromLTWH(cover.left, cover.top + 24, cover.width, 0),
      items: [
        if (services != null)
          PsMenuItem(#listen, l.startListening, icon: PsIcons.play),
        if (packages != null)
          PsMenuItem(#share, l.shareBook, icon: PsIcons.share),
        PsMenuItem(#delete, l.deleteBook, icon: PsIcons.trash, danger: true),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case #listen:
        await services!.listening.open(book.id);
      case #share:
        await showShareSheet(context, book: book, packages: packages!);
      case #delete:
        await deleteBook(context, widget.bookshelf, book);
    }
  }

  /// The book heard most recently, unless it is the one already docked in
  /// the player: one tap carries on where the listener stopped.
  Widget? _continue(List<ShelfBook> books, AppLocalizations l) {
    final listening = _listening;
    if (listening == null || listening.value.bookId != null) return null;
    final heard =
        [
          for (final book in books)
            if (_bookmarks[book.id] case final bookmark?) (book, bookmark),
        ]..sort((a, b) {
          final at = DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);
          return (b.$2.listenedAt ?? at).compareTo(a.$2.listenedAt ?? at);
        });
    final (book, bookmark) = heard.firstOrNull ?? (null, null);
    if (book == null || bookmark == null) return null;
    final p = context.ps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.s5, 0, PsSpace.s5, PsSpace.s6),
      child: Material(
        color: p.paperRaised,
        borderRadius: BorderRadius.circular(PsRadius.md),
        child: InkWell(
          key: const ValueKey('continueListening'),
          borderRadius: BorderRadius.circular(PsRadius.md),
          onTap: () => _open(book),
          child: Padding(
            padding: const EdgeInsets.all(PsSpace.s3),
            child: Row(
              spacing: PsSpace.s3,
              children: [
                ExcludeSemantics(
                  child: PsBookCover(
                    title: book.title,
                    width: 40,
                    chinese: book.language != BookLanguage.english,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        l.continueListening,
                        style: PsType.caption.copyWith(color: p.ink2),
                      ),
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PsType.rowTitle.copyWith(color: p.ink),
                      ),
                      Text(
                        l.listenedTo(bookmark.chapter),
                        style: PsType.subhead.copyWith(color: p.ink2),
                      ),
                    ],
                  ),
                ),
                PsPlayButton(
                  playing: false,
                  onPressed: () => listening.open(book.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
              if (AppScope.servicesOf(context) case final services?)
                PsIconButton(
                  icon: PsIcons.settings,
                  label: l.settings,
                  onPressed: () => _openSettings(services),
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
                  icon: PsIcons.plus,
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
                  if (_continue(books, l) case final card?)
                    SliverToBoxAdapter(child: card),
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
    final (title, body) = importFailureText(l, failure);
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
                    meta: _samples.contains(book.id)
                        ? l.sampleBookMeta
                        : bookmark == null
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
