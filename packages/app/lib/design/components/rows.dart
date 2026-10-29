import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
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
    this.badge,
    this.subtitle,
    this.subtitleMaxLines,
    this.detail,
    this.icon,
    this.trailing,
    this.chevron = false,
    this.external = false,
    this.destructive = false,
    this.onTap,
  });

  final String title;

  /// A [PsTag] of state beside the title.
  final Widget? badge;
  final String? subtitle;

  /// Ends a longer subtitle with an ellipsis, for a summary of values.
  final int? subtitleMaxLines;

  /// The current value, in grey on the right.
  final String? detail;
  final PsIcons? icon;

  /// A [Switch], a [PsStepper] or a [PsTag].
  final Widget? trailing;
  final bool chevron;

  /// Tapping leaves the app, such as for a web page.
  final bool external;
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
                    Row(
                      spacing: PsSpace.s2,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: PsType.rowTitle.copyWith(
                              color: destructive ? p.danger : p.ink,
                            ),
                          ),
                        ),
                        ?badge,
                      ],
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: subtitleMaxLines,
                        overflow: subtitleMaxLines == null
                            ? null
                            : TextOverflow.ellipsis,
                        style: PsType.subhead.copyWith(color: p.ink2),
                      ),
                  ],
                ),
              ),
              if (detail != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PsType.body.copyWith(color: p.ink2, height: 20 / 15),
                  ),
                ),
              ?trailing,
              if (chevron || external)
                Transform.translate(
                  offset: const Offset(6, 0),
                  child: PsIcon(
                    external ? PsIcons.external : PsIcons.chevronRight,
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

/// A bordered row that opens a picker: its label, then the chosen value.
class PsPickerRow extends StatelessWidget {
  const PsPickerRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PsRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: PsSize.touch),
          padding: const EdgeInsets.symmetric(horizontal: PsSpace.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PsRadius.sm),
            border: Border.all(color: p.ruleStrong),
          ),
          child: Row(
            spacing: PsSpace.s2,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: PsType.rowTitle.copyWith(color: p.ink),
                ),
              ),
              Text(value, style: PsType.body.copyWith(color: p.ink2)),
              PsIcon(PsIcons.chevronDown, size: 18, color: p.ruleStrong),
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
    this.status,
    this.statusLabel,
    this.duration,
    this.current = false,
    this.playing = false,
    this.onTap,
  });

  final int index;
  final String title;

  /// Null for a chapter at rest, which carries no mark.
  final PsChapterStatus? status;

  /// Replaces the status's generic word, e.g. 配音中 18/40.
  final String? statusLabel;

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
                        psHasCjk(title) ? PsFonts.serif : PsFonts.serifEn,
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
                  if (status != null) PsStatusMark(status!, label: statusLabel),
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
/// Personas look exactly like characters here, and nothing on screen links a
/// persona to the character behind it.
class PsCastRow extends StatelessWidget {
  const PsCastRow({
    super.key,
    required this.name,
    this.subtitle,
    this.tone,
    this.narrator = false,
    this.extra = false,
    this.auditioning = false,
    this.tag,
    this.onAudition,
    this.onMore,
    this.onTap,
    this.details,
  });

  final String name;

  /// Line count · voice description · provider.
  final String? subtitle;
  final int? tone;
  final bool narrator;

  /// Shares a voice from the extras pool; tagged 群演.
  final bool extra;
  final bool auditioning;

  /// One word of state beside the name. Never for a persona.
  final String? tag;
  final VoidCallback? onAudition;
  final VoidCallback? onMore;

  /// Toggles [details], such as the collapsed profile.
  final VoidCallback? onTap;

  /// Shown under the row, indented to the name; null keeps it collapsed.
  final Widget? details;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final l = AppLocalizations.of(context);
    final sub = PsType.subhead.copyWith(color: p.ink2);
    final row = Container(
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
                    if (extra) PsTag(l.extra),
                    if (tag != null) PsTag(tag!),
                  ],
                ),
                if (auditioning)
                  Row(
                    spacing: 6,
                    children: [
                      const PsEq(),
                      Text(
                        l.auditioning,
                        style: sub.copyWith(color: p.vermilion),
                      ),
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
                label: auditioning ? l.stopAudition : l.audition,
                onPressed: onAudition,
                variant: PsIconButtonVariant.outline,
                size: PsControlSize.sm,
                iconSize: 16,
              ),
              if (onMore != null)
                PsIconButton(
                  icon: PsIcons.more,
                  label: l.more,
                  onPressed: onMore,
                  size: PsControlSize.sm,
                  muted: true,
                ),
            ],
          ),
        ],
      ),
    );
    return Stack(
      children: [
        Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                row,
                AnimatedSize(
                  duration: PsMotion.base,
                  curve: PsMotion.standard,
                  alignment: Alignment.topCenter,
                  child: details == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(
                            PsSpace.s5 + PsSize.seal + PsSpace.s3,
                            0,
                            PsSpace.s5,
                            PsSpace.s4,
                          ),
                          child: details,
                        ),
                ),
              ],
            ),
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

/// A book on the shelf: cover, title, listening progress and one line of
/// state, such as 听到第 2 章 or 建档中 12 / 40.
class PsShelfItem extends StatelessWidget {
  const PsShelfItem({
    super.key,
    required this.title,
    this.author,
    this.tone,
    this.width = 104,
    this.progress,
    this.meta,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final String? author;
  final int? tone;

  /// 104 fits three columns on a phone.
  final double width;

  /// 0–1; null until the book has been listened to.
  final double? progress;
  final String? meta;
  final VoidCallback? onTap;

  /// Opens the book's menu.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final latin = !psHasCjk(title);
    return Semantics(
      button: onTap != null,
      child: PsPressScale(
        enabled: onTap != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: PsBookCover(
                    title: title,
                    author: author,
                    tone: tone,
                    width: width,
                  ),
                ),
                const SizedBox(height: PsSpace.s3),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (latin
                              ? PsType.style(
                                  PsFonts.serifEn,
                                  16,
                                  20,
                                  FontWeight.w500,
                                )
                              : PsType.style(
                                  PsFonts.serif,
                                  15,
                                  20,
                                  FontWeight.w600,
                                ))
                          .copyWith(color: p.ink),
                ),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: PsSpace.s2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(PsRadius.full),
                      child: SizedBox(
                        height: 2,
                        child: ColoredBox(
                          color: p.rule,
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress!.clamp(0, 1),
                            child: ColoredBox(color: p.ink),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (meta != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PsType.caption.copyWith(color: p.ink2),
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
