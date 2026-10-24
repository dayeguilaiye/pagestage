import 'package:flutter/material.dart';

import '../design/design.dart';
import '../l10n/app_localizations.dart';
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
                    padding: const EdgeInsets.fromLTRB(
                      PsSpace.s5,
                      PsSpace.s2,
                      PsSpace.s5,
                      PsSpace.s8,
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
}
