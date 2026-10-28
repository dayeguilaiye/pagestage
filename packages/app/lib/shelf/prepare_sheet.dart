import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/chapter_picker.dart';
import 'bookshelf.dart';

/// Chooses a range of profiled chapters to direct and voice before
/// listening. Their progress then shows in the contents and the text.
Future<void> showPrepareSheet(
  BuildContext context, {
  required ShelfBook book,
  required List<ChapterEntry> chapters,
  required Generation generation,
}) => showPsSheet<void>(
  context,
  builder: (_) =>
      _PrepareSheet(book: book, chapters: chapters, generation: generation),
);

class _PrepareSheet extends StatefulWidget {
  const _PrepareSheet({
    required this.book,
    required this.chapters,
    required this.generation,
  });

  final ShelfBook book;
  final List<ChapterEntry> chapters;
  final Generation generation;

  @override
  State<_PrepareSheet> createState() => _PrepareSheetState();
}

class _PrepareSheetState extends State<_PrepareSheet> {
  /// Only profiled chapters can be directed.
  late final _profiled = [
    for (final chapter in widget.chapters)
      if (chapter.state != ChapterState.unprofiled) chapter,
  ];

  /// Indices into [_profiled]: from the first chapter not yet voiced, five
  /// chapters on.
  late int _first = math.max(
    0,
    _profiled.indexWhere((c) => c.state != ChapterState.synthesized),
  );
  late int _through = math.min(_first + 4, _profiled.length - 1);
  var _busy = false;
  var _failed = false;

  Future<void> _pick({required bool first}) async {
    final l = AppLocalizations.of(context);
    final index = await pickChapter(
      context,
      title: first ? l.prepareFrom : l.prepareThrough,
      subtitle: widget.book.title,
      chapters: _profiled,
      current: first ? _first : _through,
    );
    if (index == null || !mounted) return;
    setState(() {
      // The other end follows rather than leaving an empty range.
      if (first) {
        _first = index;
        _through = math.max(_through, index);
      } else {
        _through = index;
        _first = math.min(_first, index);
      }
      _failed = false;
    });
  }

  Future<void> _prepare() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.generation.prepare(
        widget.book.id,
        first: _profiled[_first].number,
        through: _profiled[_through].number,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final note = PsType.caption.copyWith(
      color: p.ink2,
      fontWeight: FontWeight.w400,
    );
    return PsSheet(
      title: l.prepareChapters,
      subtitle: widget.book.title,
      onClose: () => Navigator.pop(context),
      child: _profiled.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: PsSpace.s4),
              child: Text(l.prepareNeedsProfile, style: note),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PsPickerRow(
                  label: l.prepareFrom,
                  value: l.chapterNumber(_profiled[_first].number),
                  onTap: _busy ? null : () => _pick(first: true),
                ),
                const SizedBox(height: PsSpace.s3),
                PsPickerRow(
                  label: l.prepareThrough,
                  value: l.chapterNumber(_profiled[_through].number),
                  onTap: _busy ? null : () => _pick(first: false),
                ),
                const SizedBox(height: PsSpace.s4),
                Text(l.prepareNote, style: note),
                const SizedBox(height: PsSpace.s5),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: PsSpace.s3),
                    child: Text(
                      l.prepareFailed,
                      style: note.copyWith(color: p.danger),
                    ),
                  ),
                PsButton(
                  label: _first == _through
                      ? l.prepareOne(_profiled[_first].number)
                      : l.prepareRange(
                          _profiled[_first].number,
                          _profiled[_through].number,
                        ),
                  variant: PsButtonVariant.primary,
                  expand: true,
                  loading: _busy,
                  onPressed: _prepare,
                ),
              ],
            ),
    );
  }
}
