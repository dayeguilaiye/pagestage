import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../application/app_services.dart';
import '../cast/cast_page.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/app_scope.dart';
import '../listening/generation_failures.dart';
import '../listening/chapter_picker.dart';
import '../listening/player.dart';
import 'bookshelf.dart';
import 'contents.dart';
import 'delete_book.dart';
import 'reader_page.dart';
import 'reading_settings.dart';
import 'share_sheet.dart';
import 'voice_sheet.dart';

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

  /// Where the book stands with its AI voices; null until loaded or
  /// without generation.
  BookVoice? _voice;
  Timer? _voiceReload;

  /// Scrolled to the chapter being listened to once, on arrival.
  var _revealed = false;
  final _contentsKey = GlobalKey();

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
    _services?.generation?.removeListener(_onGeneration);
    _services = services;
    services?.listening.addListener(_onListening);
    services?.generation?.addListener(_onGeneration);
    _load();
  }

  @override
  void dispose() {
    widget.bookshelf.removeListener(_load);
    _services?.listening.removeListener(_onListening);
    _services?.generation?.removeListener(_onGeneration);
    _voiceReload?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Generation reports every voiced line; the voice row needs no more
  /// than a refresh every second or two.
  void _onGeneration() {
    _voiceReload ??= Timer(const Duration(milliseconds: 1500), () {
      _voiceReload = null;
      _loadVoice();
    });
  }

  Future<void> _loadVoice() async {
    final generation = _services?.generation;
    if (generation == null) return;
    try {
      final voice = await generation.voice(widget.book.id);
      if (mounted) setState(() => _voice = voice);
    } catch (_) {
      // Without it the row stays as it was.
    }
  }

  bool _active = false;

  /// Rebuilds when this book starts or stops being the one open for
  /// listening, or moves to another chapter, and refreshes the bookmark.
  void _onListening() {
    final state = _services!.listening.value;
    final active = state.bookId == widget.book.id;
    final chapter = active ? state.chapter : null;
    final playing = active && state.playing;
    if (active == _active &&
        chapter == _listeningChapter &&
        playing == _playing) {
      return;
    }
    setState(() {
      _active = active;
      _listeningChapter = chapter;
      _playing = playing;
    });
    _loadBookmark();
  }

  int? _listeningChapter;
  var _playing = false;

  /// The chapter number heard last, or being heard.
  int? get _currentChapter => _listeningChapter ?? _bookmark?.chapter;

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
      final state = _services!.listening.value;
      _active = state.bookId == widget.book.id;
      _listeningChapter = _active ? state.chapter : null;
      _playing = _active && state.playing;
      _loadBookmark();
      _loadVoice();
    }
    try {
      final chapters = await widget.bookshelf.chapters(widget.book.id);
      if (!mounted || load != _loads) return;
      setState(() {
        _contents = TableOfContents(chapters);
        _loadFailed = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
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

  /// Scrolls the contents, once, so the chapter being listened to shows.
  void _reveal({int? chapter, bool force = false}) {
    final contents = _contents;
    final target = chapter ?? _currentChapter;
    if (!mounted || contents == null || target == null) return;
    if (_revealed && !force) return;
    final index = contents.chapters.indexWhere((c) => c.number == target);
    final header = _contentsKey.currentContext?.findRenderObject();
    if (index < 0 || header is! RenderBox || !_scroll.hasClients) return;
    _revealed = true;
    // Near the top already: leave the cover in view.
    if (index < 4 && !force) return;
    final top = RenderAbstractViewport.of(
      header,
    ).getOffsetToReveal(header, 0).offset;
    final offset =
        top +
        header.size.height +
        contents.offsetOf(index) -
        MediaQuery.sizeOf(context).height / 3;
    _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
  }

  Future<void> _jump() async {
    final contents = _contents;
    if (contents == null) return;
    final l = AppLocalizations.of(context);
    final current = contents.chapters.indexWhere(
      (c) => c.number == _currentChapter,
    );
    final index = await pickChapter(
      context,
      title: l.jumpToChapter,
      subtitle: widget.book.title,
      chapters: contents.chapters,
      current: current < 0 ? null : current,
    );
    if (index != null && mounted) {
      _reveal(chapter: contents.chapters[index].number, force: true);
    }
  }

  void _openVoice() => showVoiceSheet(
    context,
    book: widget.book,
    chapters: _contents?.chapters ?? const [],
  ).then((_) => _loadVoice());

  Future<void> _menu(BuildContext button) async {
    final l = AppLocalizations.of(context);
    final box = button.findRenderObject()! as RenderBox;
    final packages = _services?.packages;
    final choice = await showPsMenu(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      items: [
        if (packages != null)
          PsMenuItem(#share, l.shareBook, icon: PsIcons.share),
        PsMenuItem(#delete, l.deleteBook, icon: PsIcons.trash, danger: true),
      ],
    );
    if (!mounted) return;
    if (choice == #share) {
      await showShareSheet(context, book: widget.book, packages: packages!);
      return;
    }
    if (choice != #delete) return;
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
                    key: _contentsKey,
                    padding: const EdgeInsets.fromLTRB(
                      PsSpace.s5,
                      0,
                      PsSpace.s3,
                      PsSpace.s1,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.contents,
                            style: PsType.subhead.copyWith(
                              color: p.ink2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (contents != null && contents.chapters.length > 30)
                          PsButton(
                            label: l.jumpToChapter,
                            icon: PsIcons.list,
                            small: true,
                            variant: PsButtonVariant.ghost,
                            onPressed: _jump,
                          )
                        else
                          // Keeps the heading's height without the button.
                          const SizedBox(height: PsSize.touch),
                      ],
                    ),
                  ),
                ),
                if (contents != null)
                  _ContentsList(
                    contents: contents,
                    bookId: book.id,
                    current: () {
                      final i = contents.chapters.indexWhere(
                        (c) => c.number == _currentChapter,
                      );
                      return i < 0 ? null : i;
                    }(),
                    playing: _playing,
                    progress: _services?.generation?.progress,
                    onChapter: _read,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
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
                label: l.castShort,
                onPressed: _contents == null ? null : _openCast,
              ),
            ],
          ),
          if (_voice case final voice?)
            Padding(
              padding: const EdgeInsets.only(top: PsSpace.s3),
              child: VoiceStatusRow(
                voice: voice,
                chapters: _contents?.chapters ?? const [],
                current: _currentChapter ?? 1,
                onTap: _openVoice,
              ),
            ),
          if (_voice?.profileNeeded case final chapter?)
            Padding(
              padding: const EdgeInsets.only(top: PsSpace.s3),
              child: ProfileNeededBanner(
                bookId: widget.book.id,
                chapter: chapter,
                profiledThrough: _voice!.profiledThrough,
                onDone: _loadVoice,
              ),
            ),
          GenerationFailures(
            bookId: widget.book.id,
            padding: const EdgeInsets.only(top: PsSpace.s4),
          ),
        ],
      ),
    );
  }
}

/// The chapters: the one being listened to, those with AI voices ready,
/// and those being prepared.
class _ContentsList extends StatelessWidget {
  const _ContentsList({
    required this.contents,
    required this.bookId,
    required this.progress,
    required this.onChapter,
    this.current,
    this.playing = false,
  });

  final TableOfContents contents;
  final String bookId;
  final int? current;
  final bool playing;

  /// Null without generation, as in the gallery.
  final ValueListenable<GenerationProgress>? progress;
  final ValueChanged<int> onChapter;

  @override
  Widget build(BuildContext context) {
    final progress = this.progress;
    final voiced = {
      for (final chapter in contents.chapters)
        if (chapter.state == ChapterState.synthesized) chapter.number,
    };
    Widget list(Map<int, ChapterProgress> chapters) => SliverList.builder(
      itemCount: contents.length,
      itemBuilder: (context, i) => contents.build(
        context,
        i,
        onChapter: onChapter,
        current: current,
        playing: playing,
        voiced: voiced,
        progress: chapters,
      ),
    );
    if (progress == null) return list(const {});
    return ValueListenableBuilder(
      valueListenable: progress,
      builder: (context, value, _) => list(bookProgress(value, bookId)),
    );
  }
}

/// One line under the listen button: which voice reads this book and how
/// far its AI voices are ready, or what they still need. Opens the book's
/// voice settings.
class VoiceStatusRow extends StatelessWidget {
  const VoiceStatusRow({
    super.key,
    required this.voice,
    required this.chapters,
    required this.current,
    required this.onTap,
  });

  final BookVoice voice;
  final List<ChapterEntry> chapters;

  /// The chapter heard last, from which readiness is counted.
  final int current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final voiced = {
      for (final c in chapters)
        if (c.state == ChapterState.synthesized) c.number,
    };
    var through = current - 1;
    while (voiced.contains(through + 1)) {
      through++;
    }
    final (String title, String detail, bool warn) = switch (voice) {
      BookVoice(sample: true) => (l.aiVoice, l.voiceStatusSample, false),
      BookVoice(ai: false) => (l.systemVoice, l.voiceStatusTurnOn, false),
      BookVoice(enabled: false) => (
        l.systemVoice,
        l.aiVoicesOffEverywhere,
        true,
      ),
      BookVoice(gap: VoiceSetupGap.languageModel) => (
        l.systemVoice,
        l.gapLanguageModelTitle,
        true,
      ),
      BookVoice(gap: VoiceSetupGap.voiceEngine) => (
        l.systemVoice,
        l.gapVoiceTitle,
        true,
      ),
      _ when through >= current => (
        l.aiVoice,
        l.voiceStatusReadyThrough(through),
        false,
      ),
      _ when voiced.isNotEmpty => (
        l.aiVoice,
        l.voiceStatusVoicedCount(voiced.length),
        false,
      ),
      _ => (l.aiVoice, l.voiceStatusAsYouListen, false),
    };
    return Semantics(
      button: true,
      label: '$title, $detail',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PsRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PsSpace.s2),
          child: Row(
            spacing: PsSpace.s2,
            children: [
              PsIcon(
                PsIcons.voice,
                size: 18,
                color: warn ? p.vermilion : p.ink2,
              ),
              Text(
                title,
                style: PsType.subhead.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PsType.subhead.copyWith(
                    color: warn ? p.vermilion : p.ink2,
                  ),
                ),
              ),
              PsIcon(PsIcons.chevronRight, size: 18, color: p.ruleStrong),
            ],
          ),
        ),
      ),
    );
  }
}
