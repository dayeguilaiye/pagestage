import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/design.dart';
import '../shelf/bookshelf.dart';
import '../shelf/contents.dart';

/// Picks a chapter from the table of contents; pops with its index into
/// [chapters].
Future<int?> pickChapter(
  BuildContext context, {
  required String title,
  required String subtitle,
  required List<ChapterEntry> chapters,
  int? current,
}) => showPsSheet<int>(
  context,
  scrollControlled: true,
  builder: (_) => _ChapterPicker(
    title: title,
    subtitle: subtitle,
    contents: TableOfContents(chapters),
    current: current,
  ),
);

class _ChapterPicker extends StatefulWidget {
  const _ChapterPicker({
    required this.title,
    required this.subtitle,
    required this.contents,
    required this.current,
  });

  final String title;
  final String subtitle;
  final TableOfContents contents;
  final int? current;

  @override
  State<_ChapterPicker> createState() => _ChapterPickerState();
}

class _ChapterPickerState extends State<_ChapterPicker> {
  late final _scroll = ScrollController(
    initialScrollOffset: widget.current == null
        ? 0
        : math.max(0, widget.contents.offsetOf(widget.current!) - 112),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contents = widget.contents;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: PsSheet(
        title: widget.title,
        subtitle: widget.subtitle,
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
