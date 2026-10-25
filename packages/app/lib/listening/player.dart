import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../shelf/bookshelf.dart';
import 'app_scope.dart';
import 'chapter_picker.dart';
import 'labels.dart';
import 'open_reader.dart';

/// Opens the full player. [readingBookId] is the book the page underneath
/// shows, so reading along goes back to it instead of opening it again.
Future<void> openPlayer(BuildContext context, {String? readingBookId}) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PlayerPage(readingBookId: readingBookId),
      ),
    );

/// The mini player at the foot of the shelf, book and reader pages, while a
/// book is open for listening. Nothing at all otherwise.
class ListeningDock extends StatelessWidget {
  const ListeningDock({super.key, this.readingBookId});

  final String? readingBookId;

  @override
  Widget build(BuildContext context) {
    final listening = AppScope.servicesOf(context)?.listening;
    if (listening == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: listening,
      builder: (context, state, _) {
        if (state.bookId == null) return const SizedBox.shrink();
        final l = AppLocalizations.of(context);
        final error = state.error;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PsSpace.s3,
              PsSpace.s2,
              PsSpace.s3,
              PsSpace.s2,
            ),
            child: PsMiniPlayer(
              book: state.bookTitle,
              title: chapterLabel(l, state),
              subtitle: error == null
                  ? state.bookTitle
                  : Labels.listeningError(l, error),
              synthesized: state.source == ListeningSource.synthesized,
              playing: state.playing,
              buffering: state.buffering,
              progress: state.progress,
              onToggle: () =>
                  state.playing ? listening.pause() : listening.play(),
              onNext: listening.nextLine,
              onTap: () => openPlayer(context, readingBookId: readingBookId),
            ),
          ),
        );
      },
    );
  }
}

String chapterLabel(AppLocalizations l, ListeningState state) =>
    state.chapterTitle.isEmpty
    ? l.chapterNumber(state.chapter)
    : state.chapterTitle;

/// The whole player: what is being read, where, and every control.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key, this.readingBookId});

  final String? readingBookId;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  (String, int)? _linesOf;
  Future<List<ListeningLine>>? _lines;

  /// Where the thumb is while the reader drags it.
  double? _scrub;

  Future<List<ListeningLine>> _chapterLines(
    Listening listening,
    ListeningState state,
  ) {
    final key = (state.bookId!, state.chapter);
    if (key != _linesOf || _lines == null) {
      _linesOf = key;
      _lines = listening.lines(key.$1, key.$2);
    }
    return _lines!;
  }

  Future<void> _contents(ListeningState state) async {
    final l = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final listening = scope.services!.listening;
    final bookId = state.bookId!;
    final List<ChapterEntry> chapters;
    try {
      chapters = await scope.bookshelf.chapters(bookId);
    } catch (_) {
      return;
    }
    if (!mounted || chapters.isEmpty) return;
    final current = chapters.indexWhere((c) => c.number == state.chapter);
    final index = await pickChapter(
      context,
      title: l.contents,
      subtitle: state.bookTitle,
      chapters: chapters,
      current: current < 0 ? null : current,
    );
    if (index != null) {
      await listening.open(bookId, chapter: chapters[index].number);
    }
  }

  void _readAlong(ListeningState state) {
    if (state.bookId == widget.readingBookId) {
      Navigator.pop(context);
    } else {
      openReaderAt(context, state.bookId!, state.chapter, replace: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final listening = AppScope.servicesOf(context)?.listening;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PsSpace.s2),
              child: Row(
                children: [
                  PsIconButton(
                    icon: PsIcons.chevronDown,
                    label: l.closePlayer,
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l.nowListening,
                      textAlign: TextAlign.center,
                      style: PsType.caption.copyWith(
                        color: p.ink2,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (listening != null)
                    ValueListenableBuilder(
                      valueListenable: listening,
                      builder: (context, state, _) => PsIconButton(
                        icon: PsIcons.list,
                        label: l.contents,
                        onPressed: state.bookId == null
                            ? null
                            : () => _contents(state),
                      ),
                    )
                  else
                    const SizedBox.square(dimension: PsSize.touch),
                ],
              ),
            ),
            Expanded(
              child: listening == null
                  ? _nothing(l)
                  : ValueListenableBuilder(
                      valueListenable: listening,
                      builder: (context, state, _) => state.bookId == null
                          ? _nothing(l)
                          : _player(listening, state, l, p),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nothing(AppLocalizations l) => Center(
    child: PsEmptyState(
      title: l.nothingPlayingTitle,
      body: l.nothingPlayingBody,
      actions: [
        PsButton(
          label: l.backToShelf,
          expand: true,
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    ),
  );

  Widget _player(
    Listening listening,
    ListeningState state,
    AppLocalizations l,
    PsPalette p,
  ) {
    final error = state.error;
    final synthesized = state.source == ListeningSource.synthesized;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PsSpace.s6,
              PsSpace.s4,
              PsSpace.s6,
              PsSpace.s4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ExcludeSemantics(
                    child: PsBookCover(title: state.bookTitle, width: 112),
                  ),
                ),
                const SizedBox(height: PsSpace.s5),
                Text(
                  state.bookTitle,
                  textAlign: TextAlign.center,
                  style: context.psHeading(
                    PsType.title3.copyWith(color: p.ink),
                  ),
                ),
                const SizedBox(height: PsSpace.s1),
                Text(
                  state.chapterCount > 0
                      ? l.chapterOfCount(
                          chapterLabel(l, state),
                          state.chapter,
                          state.chapterCount,
                        )
                      : chapterLabel(l, state),
                  textAlign: TextAlign.center,
                  style: PsType.subhead.copyWith(color: p.ink2),
                ),
                const SizedBox(height: PsSpace.s3),
                Center(
                  child: PsTag(
                    synthesized ? l.aiVoice : l.systemVoice,
                    tone: synthesized ? PsTagTone.accent : PsTagTone.neutral,
                    icon: PsIcons.voice,
                  ),
                ),
                if (!synthesized)
                  Padding(
                    padding: const EdgeInsets.only(top: PsSpace.s2),
                    child: Text(
                      l.systemVoiceNote,
                      textAlign: TextAlign.center,
                      style: PsType.caption.copyWith(
                        color: p.ink2,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                const Spacer(),
                const SizedBox(height: PsSpace.s6),
                _NowLine(
                  lines: _chapterLines(listening, state),
                  line: state.line,
                ),
                const SizedBox(height: PsSpace.s6),
                const Spacer(),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: PsSpace.s4),
                    child: PsBanner(
                      tone: Labels.isEndOfBook(error)
                          ? PsBannerTone.jade
                          : PsBannerTone.danger,
                      title: Labels.listeningError(l, error),
                    ),
                  ),
                _progress(listening, state, l, p),
                const SizedBox(height: PsSpace.s4),
                _transport(listening, state, l),
                const SizedBox(height: PsSpace.s6),
                _extras(listening, state, l),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _progress(
    Listening listening,
    ListeningState state,
    AppLocalizations l,
    PsPalette p,
  ) {
    final mono = PsType.numeral.copyWith(color: p.ink2, fontSize: 12);
    if (state.duration > Duration.zero) {
      final value = (_scrub ?? state.progress).clamp(0.0, 1.0);
      final at = state.duration * value;
      return Column(
        children: [
          Semantics(
            label: l.chapterProgress,
            child: Slider(
              value: value,
              onChanged: (v) => setState(() => _scrub = v),
              onChangeEnd: (v) {
                listening.seek(state.duration * v);
                setState(() => _scrub = null);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(Labels.clock(at), style: mono),
              Text('-${Labels.clock(state.duration - at)}', style: mono),
            ],
          ),
        ],
      );
    }
    return Column(
      spacing: PsSpace.s2,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Semantics(
            label: l.chapterProgress,
            child: LinearProgressIndicator(value: state.progress),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              state.lineCount > 0
                  ? l.lineOfCount(
                      (state.line + 1).clamp(1, state.lineCount),
                      state.lineCount,
                    )
                  : ' ',
              style: mono,
            ),
          ],
        ),
      ],
    );
  }

  Widget _transport(
    Listening listening,
    ListeningState state,
    AppLocalizations l,
  ) {
    final last = state.chapterCount > 0 && state.chapter >= state.chapterCount;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PsIconButton(
          icon: PsIcons.chapterBack,
          label: l.previousChapter,
          onPressed: state.chapter > 1 ? listening.previousChapter : null,
        ),
        PsIconButton(
          icon: PsIcons.lineBack,
          label: l.previousLine,
          size: PsControlSize.lg,
          onPressed: listening.previousLine,
        ),
        PsPlayButton(
          size: PsPlaySize.lg,
          playing: state.playing,
          buffering: state.buffering,
          onPressed: () => state.playing ? listening.pause() : listening.play(),
        ),
        PsIconButton(
          icon: PsIcons.lineForward,
          label: l.nextLine,
          size: PsControlSize.lg,
          onPressed: listening.nextLine,
        ),
        PsIconButton(
          icon: PsIcons.chapterForward,
          label: l.nextChapter,
          onPressed: last ? null : listening.nextChapter,
        ),
      ],
    );
  }

  Widget _extras(
    Listening listening,
    ListeningState state,
    AppLocalizations l,
  ) {
    final p = context.ps;
    final remaining = state.sleepRemaining;
    final sleeping = state.sleepAfterChapter || remaining != null;
    return Row(
      children: [
        Expanded(
          child: _Extra(
            label: l.playbackSpeed,
            caption: l.speedShort,
            onTap: () => showPsSheet<void>(
              context,
              builder: (_) => SpeedSheet(listening: listening),
            ),
            child: Text(
              Labels.speed(state.speed),
              style: PsType.numeralLg.copyWith(color: p.ink),
            ),
          ),
        ),
        Expanded(
          child: _Extra(
            label: l.sleepTimer,
            caption: state.sleepAfterChapter
                ? l.sleepEndOfChapterShort
                : remaining != null
                ? Labels.clock(remaining)
                : l.sleepTimerShort,
            active: sleeping,
            onTap: () => showPsSheet<void>(
              context,
              scrollControlled: true,
              builder: (_) => SleepSheet(listening: listening),
            ),
            child: PsIcon(
              PsIcons.moon,
              size: 22,
              color: sleeping ? p.vermilion : p.ink,
            ),
          ),
        ),
        Expanded(
          child: _Extra(
            label: l.readAlong,
            caption: l.readAlong,
            onTap: () => _readAlong(state),
            child: PsIcon(PsIcons.book, size: 22, color: p.ink),
          ),
        ),
      ],
    );
  }
}

/// The line being read, large, with the speaker's seal when there is one.
class _NowLine extends StatelessWidget {
  const _NowLine({required this.lines, required this.line});

  final Future<List<ListeningLine>> lines;
  final int line;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return FutureBuilder(
      future: lines,
      builder: (context, snapshot) {
        final current = snapshot.data
            ?.where((x) => x.index == line)
            .firstOrNull;
        final text = current?.text.trim() ?? '';
        final speaker = current?.speakerName;
        return AnimatedSwitcher(
          duration: PsMotion.base,
          child: Container(
            key: ValueKey((line, text)),
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.only(left: PsSpace.s4),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: text.isEmpty ? p.rule : p.vermilion,
                  width: 2,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: PsSpace.s2,
              children: [
                if (speaker != null && text.isNotEmpty)
                  Row(
                    spacing: PsSpace.s2,
                    children: [
                      PsSeal(name: speaker, size: PsSealSize.sm),
                      Flexible(
                        child: Text(
                          speaker,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PsType.caption.copyWith(color: p.ink2),
                        ),
                      ),
                    ],
                  ),
                Text(
                  text,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: PsType.style(
                    psHasCjk(text) || text.isEmpty
                        ? PsFonts.serif
                        : PsFonts.serifEn,
                    18,
                    30,
                    FontWeight.w400,
                  ).copyWith(color: p.ink),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Extra extends StatelessWidget {
  const _Extra({
    required this.label,
    required this.caption,
    required this.onTap,
    required this.child,
    this.active = false,
  });

  final String label;
  final String caption;
  final VoidCallback onTap;
  final Widget child;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        value: caption == label ? null : caption,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PsRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: PsSpace.s2),
            child: Column(
              spacing: PsSpace.s1,
              children: [
                SizedBox(height: 24, child: Center(child: child)),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PsType.caption.copyWith(
                    color: active ? p.vermilion : p.ink2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Playback speed from 0.5× to 3×, by slider or by a common preset.
class SpeedSheet extends StatefulWidget {
  const SpeedSheet({super.key, required this.listening});

  final Listening listening;

  static const min = 0.5;
  static const max = 3.0;
  static const presets = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  State<SpeedSheet> createState() => _SpeedSheetState();
}

class _SpeedSheetState extends State<SpeedSheet> {
  late var _speed = widget.listening.value.speed.clamp(
    SpeedSheet.min,
    SpeedSheet.max,
  );

  void _set(double speed) {
    setState(() => _speed = speed);
    widget.listening.setSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final end = PsType.numeral.copyWith(color: p.ink2);
    return PsSheet(
      title: l.playbackSpeed,
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              Labels.speed(_speed),
              style: PsType.style(
                PsFonts.mono,
                34,
                42,
                FontWeight.w500,
              ).copyWith(color: p.ink),
            ),
          ),
          const SizedBox(height: PsSpace.s3),
          Row(
            children: [
              Text(Labels.speed(SpeedSheet.min), style: end),
              Expanded(
                child: Semantics(
                  label: l.playbackSpeed,
                  child: Slider(
                    min: SpeedSheet.min,
                    max: SpeedSheet.max,
                    divisions: 10,
                    value: _speed,
                    semanticFormatterCallback: Labels.speed,
                    onChanged: (v) => setState(() => _speed = v),
                    onChangeEnd: _set,
                  ),
                ),
              ),
              Text(Labels.speed(SpeedSheet.max), style: end),
            ],
          ),
          const SizedBox(height: PsSpace.s4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: PsSpace.s2,
            runSpacing: PsSpace.s2,
            children: [
              for (final preset in SpeedSheet.presets)
                ChoiceChip(
                  label: Text(Labels.speed(preset)),
                  selected: (_speed - preset).abs() < 0.001,
                  onSelected: (_) => _set(preset),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stop after a while, or at the end of the chapter.
class SleepSheet extends StatelessWidget {
  const SleepSheet({super.key, required this.listening});

  final Listening listening;

  static const durations = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(minutes: 60),
    Duration(minutes: 90),
  ];

  void _off() {
    listening.setSleepTimer(null);
    listening.setSleepAfterChapter(false);
  }

  void _after(Duration duration) {
    listening.setSleepAfterChapter(false);
    listening.setSleepTimer(duration);
  }

  void _endOfChapter() {
    listening.setSleepTimer(null);
    listening.setSleepAfterChapter(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    return ValueListenableBuilder(
      valueListenable: listening,
      builder: (context, state, _) {
        final remaining = state.sleepRemaining;
        final off = !state.sleepAfterChapter && remaining == null;
        Widget? check(bool on) =>
            on ? PsIcon(PsIcons.check, size: 20, color: p.vermilion) : null;
        void choose(VoidCallback action) {
          action();
          Navigator.pop(context);
        }

        return PsSheet(
          title: l.sleepTimer,
          subtitle: state.sleepAfterChapter
              ? l.sleepStopsAtChapterEnd
              : remaining != null
              ? l.sleepStopsIn(Labels.clock(remaining))
              : null,
          onClose: () => Navigator.pop(context),
          child: PsListGroup(
            children: [
              PsListRow(
                title: l.sleepOff,
                trailing: check(off),
                onTap: () => choose(_off),
              ),
              for (final d in durations)
                PsListRow(
                  title: l.sleepMinutes(d.inMinutes),
                  onTap: () => choose(() => _after(d)),
                ),
              PsListRow(
                title: l.sleepEndOfChapter,
                trailing: check(state.sleepAfterChapter),
                onTap: () => choose(_endOfChapter),
              ),
            ],
          ),
        );
      },
    );
  }
}
