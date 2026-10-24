import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'bookshelf.dart';
import 'contents.dart';
import 'reading_settings.dart';
import 'reading_sheet.dart';

/// The book as one scroll from chapter to chapter, opened at [start].
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.bookshelf,
    required this.readingSettings,
    required this.book,
    required this.chapters,
    required this.start,
  });

  final Bookshelf bookshelf;
  final ReadingSettings readingSettings;
  final ShelfBook book;
  final List<ChapterEntry> chapters;

  /// An index into [chapters].
  final int start;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  static const _center = ValueKey('center');

  // A restored offset would land a jump in the wrong chapter.
  final _scroll = ScrollController(keepScrollOffset: false);
  final _viewport = GlobalKey();
  final _sections = <int, GlobalKey>{};
  final _texts = <int, Future<List<String>>>{};
  final _loaded = <int, List<String>>{};

  /// The chapter the scroll view is built around; earlier chapters grow
  /// upwards from it, so loading them never shifts the page.
  late var _anchor = widget.start;

  /// The chapter at the top of the screen, named in the bar once its own
  /// heading has scrolled away.
  late var _current = widget.start;
  var _headingGone = false;
  late var _scrolled = widget.start > 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<List<String>> _text(int index) => _texts.putIfAbsent(
    index,
    () => widget.bookshelf
        .paragraphs(widget.book.id, widget.chapters[index].number)
        .then((paragraphs) => _loaded[index] = paragraphs),
  );

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final view = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (view == null) return false;
    // The chapter that crosses a line just below the top of the screen.
    const probe = PsSpace.s8;
    var current = _current;
    var headingGone = _headingGone;
    for (final MapEntry(key: index, value: key) in _sections.entries) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
      if (top <= probe && top + box.size.height > probe) {
        current = index;
        headingGone = top < -PsSpace.s12;
        break;
      }
    }
    final scrolled = notification.metrics.extentBefore > 0;
    if (current != _current ||
        headingGone != _headingGone ||
        scrolled != _scrolled) {
      setState(() {
        _current = current;
        _headingGone = headingGone;
        _scrolled = scrolled;
      });
    }
    return false;
  }

  void _jump(int index) => setState(() {
    _anchor = index;
    _current = index;
    _headingGone = false;
    _scrolled = index > 0;
  });

  void _openSettings() => showPsSheet<void>(
    context,
    builder: (_) => ReadingSettingsSheet(
      settings: widget.readingSettings,
      bookTitle: widget.book.title,
    ),
  );

  Future<void> _openContents() async {
    final index = await showPsSheet<int>(
      context,
      scrollControlled: true,
      builder: (_) => _ContentsSheet(
        book: widget.book,
        contents: TableOfContents(widget.chapters),
        current: _current,
      ),
    );
    if (index != null && mounted) _jump(index);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chapters = widget.chapters;
    return Scaffold(
      body: Column(
        children: [
          PsNavBar(
            back: true,
            title: chapters[_current].title,
            showTitle: _headingGone,
            divider: _scrolled,
            actions: [
              PsIconButton(
                icon: PsIcons.textSize,
                label: l.readingSettings,
                onPressed: _openSettings,
              ),
              PsIconButton(
                icon: PsIcons.list,
                label: l.contents,
                onPressed: _openContents,
              ),
            ],
          ),
          Expanded(
            child: ValueListenableBuilder(
              key: _viewport,
              valueListenable: widget.readingSettings,
              builder: (context, preferences, _) =>
                  NotificationListener<ScrollNotification>(
                    onNotification: _onScroll,
                    child: CustomScrollView(
                      key: ValueKey(_anchor),
                      controller: _scroll,
                      center: _center,
                      slivers: [
                        SliverList.builder(
                          itemCount: _anchor,
                          itemBuilder: (context, i) =>
                              _section(_anchor - 1 - i, preferences),
                        ),
                        SliverList.builder(
                          key: _center,
                          itemCount: chapters.length - _anchor,
                          itemBuilder: (context, i) =>
                              _section(_anchor + i, preferences),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: MediaQuery.paddingOf(context).bottom,
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(int index, ReadingPreferences preferences) {
    final chapter = widget.chapters[index];
    return Padding(
      key: _sections.putIfAbsent(index, GlobalKey.new),
      padding: const EdgeInsets.fromLTRB(
        PsSpace.s6,
        PsSpace.s1,
        PsSpace.s6,
        PsSpace.s16,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: FutureBuilder(
          future: _text(index),
          initialData: _loaded[index],
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ChapterError(
                title: chapter.title,
                onRetry: () => setState(() => _texts.remove(index)),
              );
            }
            final paragraphs = snapshot.data;
            if (paragraphs == null) {
              // Tall enough that one placeholder fills the screen, so the
              // list does not ask for every chapter at once.
              return SizedBox(height: MediaQuery.sizeOf(context).height);
            }
            return PsPassage(
              heading: PsPassageHeading(title: chapter.title),
              paragraphs: [
                for (final text in paragraphs) [PsLine(text)],
              ],
              fontSize: preferences.fontSize,
              lineSpacing: preferences.lineSpacing,
              english: widget.book.language == BookLanguage.english,
            );
          },
        ),
      ),
    );
  }
}

class _ChapterError extends StatelessWidget {
  const _ChapterError({required this.title, required this.onRetry});
  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PsType.title2.copyWith(color: p.ink)),
          const SizedBox(height: PsSpace.s8),
          PsBanner(
            tone: PsBannerTone.danger,
            title: l.chapterLoadFailed,
            actionLabel: l.retry,
            onAction: onRetry,
          ),
        ],
      ),
    );
  }
}

class _ContentsSheet extends StatefulWidget {
  const _ContentsSheet({
    required this.book,
    required this.contents,
    required this.current,
  });

  final ShelfBook book;
  final TableOfContents contents;
  final int current;

  @override
  State<_ContentsSheet> createState() => _ContentsSheetState();
}

class _ContentsSheetState extends State<_ContentsSheet> {
  // Opens with the current chapter a couple of rows down.
  late final _scroll = ScrollController(
    initialScrollOffset: math.max(
      0,
      widget.contents.offsetOf(widget.current) - 112,
    ),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final contents = widget.contents;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: PsSheet(
        title: l.contents,
        subtitle: widget.book.title,
        onClose: () => Navigator.pop(context),
        fill: true,
        child: ListView.builder(
          controller: _scroll,
          padding: EdgeInsets.only(
            bottom: PsSpace.s4 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: contents.length,
          itemBuilder: (context, i) => contents.build(
            context,
            i,
            current: widget.current,
            onChapter: (index) => Navigator.pop(context, index),
          ),
        ),
      ),
    );
  }
}
