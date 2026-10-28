import 'dart:async';

import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/labels.dart';
import 'bookshelf.dart';

/// The table of contents as one flat list: a header wherever a new volume
/// starts, then its chapters. Shared by the book page and the reader's
/// contents sheet.
class TableOfContents {
  TableOfContents(this.chapters) {
    String? volume;
    for (final (i, chapter) in chapters.indexed) {
      if (chapter.volume != null && chapter.volume != volume) {
        _items.add((volume: chapter.volume, chapter: null));
      }
      volume = chapter.volume;
      _items.add((volume: null, chapter: i));
    }
  }

  final List<ChapterEntry> chapters;
  final _items = <({String? volume, int? chapter})>[];

  static const _rowHeight = 56.0;
  static const _headerHeight = 46.0;

  int get length => _items.length;

  /// Roughly how far down the list chapter [index] starts.
  double offsetOf(int index) {
    var offset = 0.0;
    for (final item in _items) {
      if (item.chapter == index) break;
      offset += item.volume == null ? _rowHeight : _headerHeight;
    }
    return offset;
  }

  /// [progress] holds this book's chapters under way, by chapter number;
  /// every other chapter is drawn at rest, without a mark.
  Widget build(
    BuildContext context,
    int item, {
    required ValueChanged<int> onChapter,
    int? current,
    Map<int, ChapterProgress> progress = const {},
  }) {
    final (:volume, :chapter) = _items[item];
    if (volume != null) return _VolumeHeader(volume);
    final entry = chapters[chapter!];
    return ProgressClock(
      progress: progress[entry.number],
      builder: (context, status) => PsChapterRow(
        index: entry.number,
        title: entry.title,
        status: status?.status,
        statusLabel: status?.label,
        current: chapter == current,
        onTap: () => onChapter(chapter),
      ),
    );
  }
}

/// This book's chapters under way, by chapter number.
Map<int, ChapterProgress> bookProgress(
  GenerationProgress progress,
  String bookId,
) => {
  for (final chapter in progress.chapters)
    if (chapter.bookId == bookId) chapter.chapter: chapter,
};

typedef ProgressStatus = ({PsChapterStatus status, String label});

/// The mark and words for a chapter under way, or null for one at rest.
/// [pausedReason] says why a paused chapter stopped, where there is room.
ProgressStatus? progressStatus(
  AppLocalizations l,
  ChapterProgress? progress, {
  String? pausedReason,
}) => switch (progress?.stage) {
  null => null,
  ChapterStage.queued => (
    status: PsChapterStatus.queued,
    label: l.chapterQueued,
  ),
  ChapterStage.directing => (
    status: PsChapterStatus.working,
    label: l.chapterDirecting(
      Labels.clock(
        DateTime.now().difference(progress!.since ?? DateTime.now()),
      ),
    ),
  ),
  ChapterStage.voicing => (
    status: PsChapterStatus.working,
    label: l.chapterVoicing(progress!.voiced, progress.total),
  ),
  ChapterStage.paused => (
    status: PsChapterStatus.paused,
    label: pausedReason == null
        ? l.chapterPaused
        : l.chapterPausedBecause(pausedReason),
  ),
};

/// Builds with [progressStatus], once a second while directing so the time
/// taken keeps counting.
class ProgressClock extends StatefulWidget {
  const ProgressClock({
    super.key,
    required this.progress,
    required this.builder,
    this.pausedReason,
  });

  final ChapterProgress? progress;
  final String? pausedReason;
  final Widget Function(BuildContext context, ProgressStatus? status) builder;

  @override
  State<ProgressClock> createState() => _ProgressClockState();
}

class _ProgressClockState extends State<ProgressClock> {
  Timer? _timer;

  void _sync() {
    final ticking = widget.progress?.stage == ChapterStage.directing;
    if (ticking && _timer == null) {
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
    } else if (!ticking) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ProgressClock old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    progressStatus(
      AppLocalizations.of(context),
      widget.progress,
      pausedReason: widget.pausedReason,
    ),
  );
}

class _VolumeHeader extends StatelessWidget {
  const _VolumeHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PsSpace.s5,
        PsSpace.s5,
        PsSpace.s5,
        PsSpace.s2,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: PsType.subhead.copyWith(
            color: p.ink2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
