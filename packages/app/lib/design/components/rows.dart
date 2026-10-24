import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';
import '../type.dart';
import 'controls.dart';
import 'identity.dart';
import 'status.dart';

/// A rounded group of [PsListRow]s with hairline separators, as on the
/// settings page.
class PsListGroup extends StatelessWidget {
  const PsListGroup({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.iconInset = false,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  /// Rows carry leading icons, so separators start after them.
  final bool iconInset;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final note = PsType.subhead.copyWith(color: p.ink2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PsSpace.s4,
              0,
              PsSpace.s4,
              PsSpace.s2,
            ),
            child: Text(
              header!,
              style: note.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: p.paperRaised,
            borderRadius: BorderRadius.circular(PsRadius.md),
            border: Border.all(color: p.rule),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(indent: iconInset ? 52 : PsSpace.s4),
                  children[i],
                ],
              ],
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PsSpace.s4,
              PsSpace.s2,
              PsSpace.s4,
              0,
            ),
            child: Text(footer!, style: note),
          ),
      ],
    );
  }
}

class PsListRow extends StatelessWidget {
  const PsListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.detail,
    this.icon,
    this.trailing,
    this.chevron = false,
    this.destructive = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// The current value, in grey on the right.
  final String? detail;
  final PsIcons? icon;

  /// A [Switch], a stepper or a [PsTag].
  final Widget? trailing;
  final bool chevron;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PsSpace.s4,
            vertical: PsSpace.s3,
          ),
          child: Row(
            spacing: PsSpace.s3,
            children: [
              if (icon != null)
                PsIcon(icon!, size: 22, color: destructive ? p.danger : p.ink2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 1,
                  children: [
                    Text(
                      title,
                      style: PsType.rowTitle.copyWith(
                        color: destructive ? p.danger : p.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: PsType.subhead.copyWith(color: p.ink2),
                      ),
                  ],
                ),
              ),
              if (detail != null)
                Text(
                  detail!,
                  style: PsType.body.copyWith(color: p.ink2, height: 20 / 15),
                ),
              ?trailing,
              if (chevron)
                Transform.translate(
                  offset: const Offset(6, 0),
                  child: PsIcon(
                    PsIcons.chevronRight,
                    size: 20,
                    color: p.ruleStrong,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chapter in the table of contents.
class PsChapterRow extends StatelessWidget {
  const PsChapterRow({
    super.key,
    required this.index,
    required this.title,
    this.status = PsChapterStatus.none,
    this.duration,
    this.current = false,
    this.playing = false,
    this.onTap,
  });

  final int index;
  final String title;
  final PsChapterStatus status;

  /// Only known once synthesized, e.g. 18:42.
  final String? duration;
  final bool current;
  final bool playing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: PsSpace.s5),
              alignment: Alignment.centerLeft,
              child: Row(
                spacing: PsSpace.s3,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$index'.padLeft(3, '0'),
                      style: PsType.numeral.copyWith(
                        color: current ? p.vermilion : p.ink2,
                        fontWeight: current ? FontWeight.w500 : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PsType.style(
                        PsFonts.serif,
                        16,
                        22,
                        current ? FontWeight.w600 : FontWeight.w400,
                      ).copyWith(color: p.ink),
                    ),
                  ),
                  if (current && playing) const PsEq(),
                  if (duration != null)
                    Text(
                      duration!,
                      style: PsType.style(
                        PsFonts.mono,
                        12,
                        16,
                        FontWeight.w400,
                      ).copyWith(color: p.ink2),
                    ),
                  PsStatusMark(status),
                ],
              ),
            ),
            Positioned(
              left: PsSpace.s5 + 40,
              right: 0,
              bottom: 0,
              child: const Divider(),
            ),
          ],
        ),
      ),
    );
  }
}

/// A speaker in the cast list: seal, name, voice and an audition button.
/// Personas look exactly like characters here; their link to the real
/// character lives only in the collapsed profile.
class PsCastRow extends StatelessWidget {
  const PsCastRow({
    super.key,
    required this.name,
    this.subtitle,
    this.tone,
    this.narrator = false,
    this.extra = false,
    this.auditioning = false,
    this.onAudition,
    this.onMore,
  });

  final String name;

  /// Line count · voice description · provider.
  final String? subtitle;
  final int? tone;
  final bool narrator;

  /// Shares a voice from the extras pool; tagged 群演.
  final bool extra;
  final bool auditioning;
  final VoidCallback? onAudition;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final sub = PsType.subhead.copyWith(color: p.ink2);
    return Stack(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.fromLTRB(
            PsSpace.s5,
            PsSpace.s3,
            PsSpace.s3,
            PsSpace.s3,
          ),
          child: Row(
            spacing: PsSpace.s3,
            children: [
              PsSeal(name: name, tone: tone, narrator: narrator),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Row(
                      spacing: PsSpace.s2,
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PsType.style(
                              PsFonts.sans,
                              16,
                              22,
                              FontWeight.w600,
                            ).copyWith(color: p.ink),
                          ),
                        ),
                        if (extra) const PsTag('群演'),
                      ],
                    ),
                    if (auditioning)
                      Row(
                        spacing: 6,
                        children: [
                          const PsEq(),
                          Text('试听中', style: sub.copyWith(color: p.vermilion)),
                        ],
                      )
                    else if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sub,
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  PsIconButton(
                    icon: auditioning ? PsIcons.pause : PsIcons.play,
                    label: auditioning ? '停止试听' : '试听',
                    onPressed: onAudition,
                    variant: PsIconButtonVariant.outline,
                    size: PsControlSize.sm,
                    iconSize: 16,
                  ),
                  if (onMore != null)
                    PsIconButton(
                      icon: PsIcons.more,
                      label: '更多',
                      onPressed: onMore,
                      size: PsControlSize.sm,
                      muted: true,
                    ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: PsSpace.s5 + PsSize.seal + PsSpace.s3,
          right: 0,
          bottom: 0,
          child: const Divider(),
        ),
      ],
    );
  }
}
