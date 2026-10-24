import 'package:flutter/material.dart';

import '../design/design.dart';
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

  Widget build(
    BuildContext context,
    int item, {
    required ValueChanged<int> onChapter,
    int? current,
  }) {
    final (:volume, :chapter) = _items[item];
    if (volume != null) return _VolumeHeader(volume);
    final entry = chapters[chapter!];
    return PsChapterRow(
      index: entry.number,
      title: entry.title,
      status: chapterStatus(entry.state),
      current: chapter == current,
      onTap: () => onChapter(chapter),
    );
  }
}

PsChapterStatus chapterStatus(ChapterState state) => switch (state) {
  ChapterState.unprofiled => PsChapterStatus.unprofiled,
  ChapterState.profiled => PsChapterStatus.none,
  ChapterState.directed => PsChapterStatus.directed,
  ChapterState.synthesized => PsChapterStatus.synthesized,
};

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
