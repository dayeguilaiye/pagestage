import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../cast/cast_page.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/app_scope.dart';
import '../listening/player.dart';
import 'bookshelf.dart';
import 'contents.dart';
import 'delete_book.dart';
import 'reader_page.dart';
import 'reading_settings.dart';

/// One book: its cover and title over the table of contents.
class BookPage extends StatefulWidget {
  const BookPage({
    super.key,
    required this.bookshelf,
    required this.readingSettings,
    required this.book,
  });

  final Bookshelf bookshelf;
  final ReadingSettings readingSettings;
  final ShelfBook book;

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final _scroll = ScrollController();
  var _scrolled = false;

  TableOfContents? _contents;
  var _loadFailed = false;
  var _loads = 0;

  AppServices? _services;
  ListeningBookmark? _bookmark;
  var _opening = false;

  @override
  void initState() {
    super.initState();
    widget.bookshelf.addListener(_load);
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppScope.servicesOf(context);
    if (services == _services && _loads > 0) return;
    _services?.listening.removeListener(_onListening);
    _services = services;
    services?.listening.addListener(_onListening);
    _load();
  }

  @override
  void dispose() {
    widget.bookshelf.removeListener(_load);
    _services?.listening.removeListener(_onListening);
    _scroll.dispose();
    super.dispose();
  }

  bool _active = false;

  /// Rebuilds when this book starts or stops being the one open for
  /// listening, and refreshes the bookmark then.
  void _onListening() {
    final active = _services!.listening.value.bookId == widget.book.id;
    if (active == _active) return;
    setState(() => _active = active);
    _loadBookmark();
  }

  Future<void> _loadBookmark() async {
    try {
      final bookmark = await _services?.listening.bookmark(widget.book.id);
      if (mounted) setState(() => _bookmark = bookmark);
    } catch (_) {
      // Without a bookmark the button simply starts the book.
    }
  }

  Future<void> _listen() async {
    final listening = _services!.listening;
    if (listening.value.bookId == widget.book.id) {
      await openPlayer(context, readingBookId: null);
      return;
    }
    setState(() => _opening = true);
    try {
      await listening.open(widget.book.id);
    } catch (_) {
      // The player reports why it could not start.
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _openCast() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CastPage(
        services: _services!,
        book: widget.book,
        chapters: _contents?.chapters ?? const [],
      ),
    ),
  );

  Future<void> _load() async {
    final load = ++_loads;
    if (_services != null) {
      _active = _services!.listening.value.bookId == widget.book.id;
      _loadBookmark();
    }
    try {
      final chapters = await widget.bookshelf.chapters(widget.book.id);
      if (!mounted || load != _loads) return;
      setState(() {
        _contents = TableOfContents(chapters);
        _loadFailed = false;
      });
    } catch (_) {
      // Deleted from under the page: the shelf takes over once we pop.
      if (!mounted || load != _loads) return;
      setState(() => _loadFailed = true);
    }
  }

  void _onScroll() {
    final scrolled = _scroll.offset > 80;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  void _read(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReaderPage(
          bookshelf: widget.bookshelf,
          readingSettings: widget.readingSettings,
          book: widget.book,
          chapters: _contents!.chapters,
          start: index,
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext button) async {
    final l = AppLocalizations.of(context);
    final box = button.findRenderObject()! as RenderBox;
    final choice = await showPsMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      items: [
        PsMenuItem(#delete, l.deleteBook, icon: PsIcons.trash, danger: true),
      ],
    );
    if (choice != #delete || !mounted) return;
    if (await deleteBook(context, widget.bookshelf, widget.book) && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final book = widget.book;
    final contents = _contents;
    final latin = book.language == BookLanguage.english;
    return Scaffold(
      bottomNavigationBar: const ListeningDock(),
      body: Column(
        children: [
          PsNavBar(
            back: true,
            backLabel: l.shelfTitle,
            title: book.title,
            showTitle: _scrolled,
            divider: _scrolled,
            actions: [
              Builder(
                builder: (button) => PsIconButton(
                  icon: PsIcons.more,
                  label: l.more,
                  onPressed: () => _menu(button),
                ),
              ),
            ],
          ),
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      PsSpace.s5,
                      PsSpace.s2,
                      PsSpace.s5,
                      _services == null ? PsSpace.s8 : PsSpace.s6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: PsSpace.s4,
                      children: [
                        ExcludeSemantics(
                          child: PsBookCover(
                            title: book.title,
                            width: 88,
                            chinese: !latin,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: PsSpace.s1,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  book.title,
                                  style:
                                      (latin
                                              ? PsType.style(
                                                  PsFonts.serifEn,
                                                  24,
                                                  30,
                                                  FontWeight.w500,
                                                )
                                              : PsType.title2)
                                          .copyWith(color: p.ink),
                                ),
                              ),
                              Text(
                                l.chapterCount(book.chapterCount),
                                style: PsType.subhead.copyWith(color: p.ink2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_services != null)
                  SliverToBoxAdapter(child: _actions(l, p)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PsSpace.s5,
                      0,
                      PsSpace.s5,
                      PsSpace.s1,
                    ),
                    child: Text(
                      l.contents,
                      style: PsType.subhead.copyWith(
                        color: p.ink2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (contents != null)
                  SliverList.builder(
                    itemCount: contents.length,
                    itemBuilder: (context, i) =>
                        contents.build(context, i, onChapter: _read),
                  )
                else if (_loadFailed)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(PsSpace.s5),
                      child: PsBanner(
                        tone: PsBannerTone.danger,
                        title: l.contentsLoadFailed,
                        actionLabel: l.retry,
                        onAction: _load,
                      ),
                    ),
                  ),
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

  /// Listening and the cast, under the title.
  Widget _actions(AppLocalizations l, PsPalette p) {
    final bookmark = _bookmark;
    final listenLabel = _active
        ? l.openPlayer
        : bookmark == null
        ? l.startListening
        : l.resumeListening(bookmark.chapter);
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.s5, 0, PsSpace.s5, PsSpace.s8),
      child: Row(
        spacing: PsSpace.s3,
        children: [
          Expanded(
            child: PsButton(
              label: listenLabel,
              icon: PsIcons.play,
              variant: PsButtonVariant.primary,
              expand: true,
              loading: _opening,
              onPressed: _listen,
            ),
          ),
          PsButton(
            label: l.cast,
            onPressed: _contents == null ? null : _openCast,
          ),
        ],
      ),
    );
  }
}
