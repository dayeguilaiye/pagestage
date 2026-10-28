import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/app_scope.dart';
import '../listening/chapter_lines.dart';
import '../listening/labels.dart';
import '../listening/player.dart';
import 'bookshelf.dart';
import 'contents.dart';
import 'reading_settings.dart';
import 'reading_sheet.dart';

/// The book as one scroll from chapter to chapter, opened at [start]. While
/// the book is being listened to, the spoken lines are lit and followed.
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

/// The lines being spoken in this book.
@immutable
class _Spoken {
  const _Spoken(this.chapter, this.lines);

  /// A chapter number.
  final int chapter;
  final Set<int> lines;

  @override
  bool operator ==(Object other) =>
      other is _Spoken &&
      other.chapter == chapter &&
      setEquals(other.lines, lines);

  @override
  int get hashCode => Object.hash(chapter, Object.hashAllUnordered(lines));
}

class _ReaderPageState extends State<ReaderPage> {
  static const _center = ValueKey('center');

  // A restored offset would land a jump in the wrong chapter.
  final _scroll = ScrollController(keepScrollOffset: false);
  final _viewport = GlobalKey();
  final _sections = <int, GlobalKey>{};
  final _paragraphKeys = <int, List<GlobalKey>>{};
  final _texts = <int, Future<List<List<LineSegment>>>>{};
  final _loaded = <int, List<List<LineSegment>>>{};

  /// Bumped per chapter index on each refresh; a fetch from an older
  /// generation is discarded when it finishes.
  final _generations = <int, int>{};

  /// Chapters showing old lines while new ones load.
  final _stale = <int>{};

  /// The chapter, source and line revision the lines were last seen for.
  (int, ListeningSource, int)? _linesOf;

  /// The chapter the scroll view is built around; earlier chapters grow
  /// upwards from it, so loading them never shifts the page.
  late var _anchor = widget.start;

  /// The chapter at the top of the screen, named in the bar once its own
  /// heading has scrolled away.
  late var _current = widget.start;
  var _headingGone = false;
  late var _scrolled = widget.start > 0;

  Listening? _listening;
  final _spoken = ValueNotifier<_Spoken?>(null);

  Generation? _generation;

  /// This book's chapters being generated, by chapter number.
  final _progress = ValueNotifier<Map<int, ChapterProgress>>(const {});

  /// Chapter indices whose loaded lines come from the script, so a line's
  /// index can be matched with the voiced ones.
  final _scripted = <int>{};

  /// Keeps the spoken line on screen until the reader scrolls away.
  var _following = true;
  (int, int)? _followed;
  (int, int)? _pendingReveal;

  /// The line with its menu open: a chapter index and a line index.
  (int, int)? _selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppScope.servicesOf(context);
    final listening = services?.listening;
    if (listening != _listening) {
      _listening?.removeListener(_onListening);
      _listening = listening;
      listening?.addListener(_onListening);
      _onListening();
    }
    final generation = services?.generation;
    if (generation != _generation) {
      _generation?.progress.removeListener(_onProgress);
      _generation = generation;
      generation?.progress.addListener(_onProgress);
      _onProgress();
    }
  }

  @override
  void dispose() {
    _listening?.removeListener(_onListening);
    _generation?.progress.removeListener(_onProgress);
    _spoken.dispose();
    _progress.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onProgress() {
    final generation = _generation;
    final next = generation == null
        ? const <int, ChapterProgress>{}
        : bookProgress(generation.progress.value, widget.book.id);
    final previous = _progress.value;
    _progress.value = next;
    // A chapter read before its script existed takes on the script's lines
    // once directing is done, or once its generation ends.
    for (final number in previous.keys) {
      final before = previous[number]!;
      final after = next[number];
      if (!before.directed && (after == null || after.directed)) {
        final index = widget.chapters.indexWhere((c) => c.number == number);
        if (index >= 0 && !_scripted.contains(index)) _refresh(number);
      }
    }
  }

  void _onListening() {
    final state = _listening?.value;
    final ours = state != null && state.bookId == widget.book.id;
    // Lines change when the chapter moves from system sentences to a
    // directed script, or the script itself is revised.
    final lines = ours
        ? (state.chapter, state.source, state.lineRevision)
        : null;
    if (lines != _linesOf) {
      final previous = _linesOf?.$1;
      _linesOf = lines;
      for (final number in {?previous, ?lines?.$1}) {
        _refresh(number);
      }
    }
    final spoken = ours ? _Spoken(state.chapter, {...state.activeLines}) : null;
    if (spoken == _spoken.value) return;
    _spoken.value = spoken;
    _follow();
  }

  /// Fetches chapter number [number] again. Its old text stays on screen
  /// until the new lines arrive, without highlights or line taps, which
  /// would point into the old segmentation.
  void _refresh(int number) {
    final index = widget.chapters.indexWhere((c) => c.number == number);
    if (index < 0 || _texts.remove(index) == null) return;
    _generations[index] = (_generations[index] ?? 0) + 1;
    if (_loaded.containsKey(index)) _stale.add(index);
    if (_selected?.$1 == index) _selected = null;
    // The spoken line is looked up again in the new paragraphs.
    if (_followed?.$1 == index) _followed = null;
    if (mounted) setState(() {});
    _follow();
  }

  Future<List<List<LineSegment>>> _text(int index) =>
      _texts.putIfAbsent(index, () => _fetch(index));

  Future<List<List<LineSegment>>> _fetch(int index) async {
    final generation = _generations[index] ?? 0;
    final number = widget.chapters[index].number;
    final listening = _listening;
    List<List<LineSegment>>? segments;
    var scripted = false;
    if (listening != null) {
      try {
        final lines = await listening.lines(widget.book.id, number);
        if (lines.isNotEmpty) {
          segments = layoutLines(lines);
          scripted = lines.first.directed;
        }
      } catch (_) {
        // Read the plain text instead; listening reports its own errors.
      }
    }
    segments ??= plainParagraphs(
      await widget.bookshelf.paragraphs(widget.book.id, number),
    );
    // A newer fetch was started meanwhile; never let this one win.
    if (!mounted || generation != (_generations[index] ?? 0)) return segments;
    _loaded[index] = segments;
    if (scripted) {
      _scripted.add(index);
    } else {
      _scripted.remove(index);
    }
    if (_stale.remove(index)) setState(() {});
    if (_pendingReveal?.$1 == index) _revealLater();
    return segments;
  }

  void _follow() {
    final spoken = _spoken.value;
    if (spoken == null || !_following || spoken.lines.isEmpty) return;
    final index = widget.chapters.indexWhere((c) => c.number == spoken.chapter);
    if (index < 0) return;
    final target = (index, spoken.lines.reduce(math.min));
    if (target == _followed) return;
    _followed = target;
    _pendingReveal = target;
    _revealLater();
  }

  void _revealLater() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());

  /// Brings the pending spoken line into view, jumping to its chapter first
  /// when that chapter is not built.
  void _reveal() {
    final target = _pendingReveal;
    if (target == null || !mounted) return;
    final (index, line) = target;
    if (_sections[index]?.currentContext == null) {
      _jump(index);
      _revealLater();
      return;
    }
    final segments = _loaded[index];
    // Revealed once the (new) text arrives.
    if (segments == null || _stale.contains(index)) return;
    _pendingReveal = null;
    final paragraph = segments.indexWhere((p) => p.any((s) => s.line == line));
    final keys = _paragraphKeys[index];
    if (paragraph < 0 || keys == null || paragraph >= keys.length) return;
    final target0 = keys[paragraph].currentContext;
    final view = _viewport.currentContext?.findRenderObject() as RenderBox?;
    final box = target0?.findRenderObject() as RenderBox?;
    if (target0 == null || view == null || box == null || !box.attached) {
      return;
    }
    // Leave it be while it sits comfortably in the upper part of the screen.
    final top = box.localToGlobal(Offset.zero, ancestor: view).dy;
    final height = view.size.height;
    if (top >= height * 0.08 &&
        top + math.min(box.size.height, 64) <= height * 0.75) {
      return;
    }
    Scrollable.ensureVisible(
      target0,
      alignment: 0.2,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : PsMotion.slow,
      curve: PsMotion.standard,
    );
  }

  void _resumeFollowing() {
    setState(() => _following = true);
    _followed = null;
    _follow();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is UserScrollNotification &&
        notification.direction != ScrollDirection.idle &&
        _spoken.value != null &&
        _following) {
      setState(() => _following = false);
    }
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
        progress: _progress,
      ),
    );
    if (index != null && mounted) {
      // Choosing a chapter is scrolling away from the spoken line.
      if (_spoken.value != null) _following = false;
      _jump(index);
    }
  }

  /// A tap on a line only offers to play from it; playback moves only when
  /// the reader chooses to.
  Future<void> _tapLine(int index, LineSegment segment, Offset at) async {
    final listening = _listening;
    final line = segment.line;
    if (listening == null || line == null || !segment.spoken) return;
    final l = AppLocalizations.of(context);
    final generation = _generations[index] ?? 0;
    setState(() => _selected = (index, line));
    final choice = await showPsMenu(
      context,
      anchor: Rect.fromLTWH(at.dx, at.dy + PsSpace.s3, 0, 0),
      items: [
        PsMenuItem(#playFromHere, l.playFromHere, icon: PsIcons.playFrom),
      ],
    );
    if (!mounted) return;
    setState(() => _selected = null);
    if (choice != #playFromHere) return;
    // The lines were re-segmented while the menu was open: this index
    // belongs to the old text.
    if (generation != (_generations[index] ?? 0) || _stale.contains(index)) {
      return;
    }
    _following = true;
    _followed = null;
    await listening.open(
      widget.book.id,
      chapter: widget.chapters[index].number,
      line: line,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chapters = widget.chapters;
    return Scaffold(
      bottomNavigationBar: ListeningDock(readingBookId: widget.book.id),
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
            child: Stack(
              children: [
                ValueListenableBuilder(
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
                                height:
                                    MediaQuery.paddingOf(context).bottom +
                                    PsSpace.s16,
                              ),
                            ),
                          ],
                        ),
                      ),
                ),
                if (_listening != null)
                  Positioned(
                    left: PsSpace.s5,
                    right: PsSpace.s5,
                    bottom: PsSpace.s4,
                    child: ValueListenableBuilder(
                      valueListenable: _spoken,
                      builder: (context, spoken, _) => _floating(spoken, l),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Back to the spoken line, or a way to start listening here.
  Widget _floating(_Spoken? spoken, AppLocalizations l) {
    final Widget? button;
    if (spoken == null) {
      button = PsButton(
        key: const ValueKey('listen'),
        label: l.listenToChapter,
        icon: PsIcons.play,
        small: true,
        variant: PsButtonVariant.primary,
        onPressed: () {
          _following = true;
          _followed = null;
          _listening!.open(
            widget.book.id,
            chapter: widget.chapters[_current].number,
          );
        },
      );
    } else if (!_following) {
      button = PsButton(
        key: const ValueKey('follow'),
        label: l.backToSpokenLine,
        icon: PsIcons.playFrom,
        small: true,
        onPressed: _resumeFollowing,
      );
    } else {
      button = null;
    }
    final p = context.ps;
    return Align(
      alignment: Alignment.bottomRight,
      child: AnimatedSwitcher(
        duration: PsMotion.base,
        child: button == null
            ? const SizedBox.shrink()
            : DecoratedBox(
                key: button.key,
                decoration: BoxDecoration(
                  color: p.paper,
                  borderRadius: BorderRadius.circular(PsRadius.full),
                  boxShadow: p.shadowFloat,
                ),
                child: button,
              ),
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
            final segments = snapshot.data;
            if (segments == null) {
              // Tall enough that one placeholder fills the screen, so the
              // list does not ask for every chapter at once.
              return SizedBox(height: MediaQuery.sizeOf(context).height);
            }
            var keys = _paragraphKeys[index];
            if (keys == null || keys.length != segments.length) {
              keys = _paragraphKeys[index] = [
                for (var i = 0; i < segments.length; i++) GlobalKey(),
              ];
            }
            final paragraphKeys = keys;
            return ValueListenableBuilder(
              valueListenable: _progress,
              builder: (context, marks, _) => ProgressClock(
                progress: marks[chapter.number],
                pausedReason: _pausedReason(chapter.number),
                builder: (context, status) => ValueListenableBuilder(
                  valueListenable: _spoken,
                  builder: (context, spoken, _) {
                    final stale = _stale.contains(index);
                    final active = !stale && spoken?.chapter == chapter.number
                        ? spoken!.lines
                        : const <int>{};
                    final progress = marks[chapter.number];
                    final scripted =
                        _scripted.contains(index) && progress?.directed == true;
                    // Under way, a line waits for its voice; until the script
                    // exists, the whole chapter does.
                    bool pending(LineSegment s) =>
                        progress != null &&
                        !s.nonStory &&
                        (!scripted || progress.unvoiced.contains(s.line));
                    return PsPassage(
                      heading: PsPassageHeading(
                        title: chapter.title,
                        status: status?.status,
                        statusLabel: status?.label,
                      ),
                      paragraphKeys: paragraphKeys,
                      paragraphs: [
                        for (final paragraph in segments)
                          [
                            for (final s in paragraph)
                              PsLine(
                                s.text,
                                speaker: s.spoken ? s.speaker : null,
                                current: s.spoken && active.contains(s.line),
                                skip: s.nonStory,
                                selected:
                                    s.spoken && _selected == (index, s.line),
                                pending: pending(s),
                              ),
                          ],
                      ],
                      fontSize: preferences.fontSize,
                      lineSpacing: preferences.lineSpacing,
                      english: widget.book.language == BookLanguage.english,
                      onLineTap: _listening == null || stale
                          ? null
                          : (pi, li, at) =>
                                _tapLine(index, segments[pi][li], at),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Why chapter [number] stopped, when its generation is paused.
  String? _pausedReason(int number) {
    final generation = _generation;
    if (generation == null) return null;
    for (final failure in generation.value.failures) {
      if (failure.bookId == widget.book.id && failure.chapter == number) {
        return Labels.pauseReason(AppLocalizations.of(context), failure.reason);
      }
    }
    return null;
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
    required this.progress,
  });

  final ShelfBook book;
  final TableOfContents contents;
  final int current;
  final ValueListenable<Map<int, ChapterProgress>> progress;

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
        child: ValueListenableBuilder(
          valueListenable: widget.progress,
          builder: (context, progress, _) => ListView.builder(
            controller: _scroll,
            padding: EdgeInsets.only(
              bottom: PsSpace.s4 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: contents.length,
            itemBuilder: (context, i) => contents.build(
              context,
              i,
              current: widget.current,
              progress: progress,
              onChapter: (index) => Navigator.pop(context, index),
            ),
          ),
        ),
      ),
    );
  }
}
