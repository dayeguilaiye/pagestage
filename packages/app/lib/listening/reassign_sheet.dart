import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';

/// Lets the reader say who really speaks a line the director gave to the
/// wrong speaker. Returns the chosen cast member once the script is
/// changed, or null when the sheet is closed without a change.
Future<CastMember?> showReassignSheet(
  BuildContext context, {
  required AppServices services,
  required String bookId,
  required int chapter,
  required int line,
  required String speakerId,
}) => showPsSheet<CastMember>(
  context,
  scrollControlled: true,
  builder: (_) => _ReassignSheet(
    services: services,
    bookId: bookId,
    chapter: chapter,
    line: line,
    speakerId: speakerId,
  ),
);

class _ReassignSheet extends StatefulWidget {
  const _ReassignSheet({
    required this.services,
    required this.bookId,
    required this.chapter,
    required this.line,
    required this.speakerId,
  });

  final AppServices services;
  final String bookId;

  /// The chapter number and script line index being corrected.
  final int chapter;
  final int line;

  /// Who the director gave the line to.
  final String speakerId;

  @override
  State<_ReassignSheet> createState() => _ReassignSheetState();
}

class _ReassignSheetState extends State<_ReassignSheet> {
  List<CastMember>? _members;
  var _imported = false;
  var _loadFailed = false;

  /// The member being applied.
  String? _busy;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cast = await widget.services.casts.load(widget.bookId);
      final imported = await widget.services.scripts!.hasImportedAudio(
        widget.bookId,
        widget.chapter,
      );
      if (!mounted) return;
      setState(() {
        _members = cast.members;
        _imported = imported;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _choose(CastMember member) async {
    if (_busy != null) return;
    setState(() {
      _busy = member.id;
      _failed = false;
    });
    try {
      await widget.services.scripts!.reassign(
        widget.bookId,
        widget.chapter,
        widget.line,
        member.id,
      );
      if (mounted) Navigator.pop(context, member);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = null;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final members = _members;
    final note = PsType.caption.copyWith(
      color: p.ink2,
      fontWeight: FontWeight.w400,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: PsSheet(
        title: l.reassignTitle,
        subtitle: _failed
            ? l.reassignFailed
            : _imported
            ? l.reassignImportedNote
            : l.reassignNote,
        onClose: () => Navigator.pop(context),
        fill: true,
        child: members == null
            ? Padding(
                padding: const EdgeInsets.all(PsSpace.s6),
                child: _loadFailed
                    ? Text(
                        l.speakersLoadFailed,
                        style: note.copyWith(color: p.danger),
                      )
                    : const Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              )
            : ListView(
                shrinkWrap: true,
                padding: EdgeInsets.only(
                  bottom: PsSpace.s4 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  for (final (index, member) in members.indexed)
                    _MemberRow(
                      key: ValueKey('speaker-${member.id}'),
                      member: member,
                      tone: index % 8 + 1,
                      current: member.id == widget.speakerId,
                      busy: _busy == member.id,
                      onTap: _busy != null || member.id == widget.speakerId
                          ? null
                          : () => _choose(member),
                    ),
                ],
              ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    super.key,
    required this.member,
    required this.tone,
    required this.current,
    required this.busy,
    required this.onTap,
  });

  final CastMember member;
  final int tone;

  /// Who the line belongs to now.
  final bool current;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final narrator = member.kind == CastMemberKind.narrator;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PsSpace.s5,
          vertical: PsSpace.s2,
        ),
        child: Row(
          spacing: PsSpace.s3,
          children: [
            PsSeal(
              name: member.name,
              tone: narrator ? null : tone,
              narrator: narrator,
              size: PsSealSize.sm,
            ),
            Expanded(
              child: Text(
                narrator ? l.narrator : member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PsType.rowTitle.copyWith(
                  color: current ? p.ink2 : p.ink,
                ),
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (current)
              PsIcon(PsIcons.check, size: 20, color: p.ink2),
          ],
        ),
      ),
    );
  }
}
