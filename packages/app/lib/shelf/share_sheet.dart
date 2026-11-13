import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'bookshelf.dart';

/// Offers the two ways a book travels: its scripts for someone to voice
/// themselves, or its scripts with the audio already voiced. Either becomes
/// one file handed to the system share sheet.
Future<void> showShareSheet(
  BuildContext context, {
  required ShelfBook book,
  required Packages packages,
}) => showPsSheet<void>(
  context,
  scrollControlled: true,
  builder: (_) => _ShareSheet(book: book, packages: packages),
);

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.book, required this.packages});

  final ShelfBook book;
  final Packages packages;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  PackageContents? _contents;
  var _loadFailed = false;

  /// Which package is being packed: true for audio; null while idle.
  bool? _packing;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final contents = await widget.packages.contents(widget.book.id);
      if (mounted) setState(() => _contents = contents);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _share({required bool audio}) async {
    if (_packing != null) return;
    setState(() {
      _packing = audio;
      _failed = false;
    });
    try {
      await widget.packages.share(widget.book.id, audio: audio);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _packing = null;
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
    final contents = _contents;
    final Widget body;
    if (contents == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: PsSpace.s6),
        child: _loadFailed
            ? Text(l.shareLoadFailed, style: note.copyWith(color: p.danger))
            : const Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
      );
    } else if (contents.scriptChapters == 0) {
      body = Padding(
        padding: const EdgeInsets.only(bottom: PsSpace.s4),
        child: Text(l.shareNothing, style: note),
      );
    } else {
      final busy = _packing != null;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Option(
            key: const ValueKey('share-script'),
            icon: PsIcons.pen,
            title: l.shareScript,
            note: l.shareScriptNote(contents.scriptChapters),
            packing: _packing == false,
            onTap: busy ? null : () => _share(audio: false),
          ),
          const SizedBox(height: PsSpace.s3),
          _Option(
            key: const ValueKey('share-audio'),
            icon: PsIcons.voice,
            title: l.shareAudio,
            note: contents.audioChapters == 0
                ? l.shareAudioNone
                : l.shareAudioNote(contents.audioChapters),
            packing: _packing == true,
            onTap: busy || contents.audioChapters == 0
                ? null
                : () => _share(audio: true),
          ),
          const SizedBox(height: PsSpace.s4),
          Text(
            _failed ? l.shareFailed : l.shareNote,
            style: _failed ? note.copyWith(color: p.danger) : note,
          ),
          const SizedBox(height: PsSpace.s2),
        ],
      );
    }
    return PsSheet(
      title: l.shareBookTitle(widget.book.title),
      onClose: () => Navigator.pop(context),
      child: body,
    );
  }
}

/// One kind of package: what it holds, and a tap to pack and share it.
class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.icon,
    required this.title,
    required this.note,
    required this.packing,
    required this.onTap,
  });

  final PsIcons icon;
  final String title;
  final String note;
  final bool packing;

  /// Null while it cannot be chosen.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final enabled = onTap != null || packing;
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        color: p.paperRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PsRadius.md),
          side: BorderSide(color: p.rule),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(PsSpace.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PsSpace.s3,
              children: [
                PsIcon(
                  icon,
                  size: 22,
                  color: enabled ? p.vermilion : p.inkWaiting,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: PsSpace.s1,
                    children: [
                      Text(
                        title,
                        style: PsType.rowTitle.copyWith(
                          color: enabled ? p.ink : p.inkWaiting,
                        ),
                      ),
                      Text(
                        packing ? l.sharePreparing : note,
                        style: PsType.subhead.copyWith(color: p.ink2),
                      ),
                    ],
                  ),
                ),
                if (packing)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (onTap != null)
                  PsIcon(PsIcons.share, size: 20, color: p.ink2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
