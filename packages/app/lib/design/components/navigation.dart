import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';
import '../type.dart';
import 'identity.dart';

/// The bar at the top of a page: back on the left, a small title in the
/// middle, at most two [PsIconButton]s on the right. Pages with a
/// [PsLargeTitle] hide the small title until the large one scrolls away.
class PsNavBar extends StatelessWidget {
  const PsNavBar({
    super.key,
    this.title,
    this.showTitle = true,
    this.back = false,
    this.backLabel,
    this.onBack,
    this.actions = const [],
    this.divider = false,
  });

  final String? title;
  final bool showTitle;
  final bool back;

  /// The previous page's name, beside the arrow.
  final String? backLabel;

  /// Defaults to popping the route.
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// A hairline under the bar, once content scrolls beneath it.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bar = AnimatedContainer(
      duration: PsMotion.base,
      decoration: BoxDecoration(
        color: p.paper,
        border: Border(
          bottom: BorderSide(
            color: divider ? p.rule : p.rule.withValues(alpha: 0),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PsSpace.s2),
            child: NavigationToolbar(
              leading: back ? _BackButton(backLabel, onBack) : null,
              middle: title == null
                  ? null
                  : AnimatedOpacity(
                      opacity: showTitle ? 1 : 0,
                      duration: PsMotion.base,
                      curve: PsMotion.standard,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 210),
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PsType.headline.copyWith(color: p.ink),
                        ),
                      ),
                    ),
              trailing: actions.isEmpty
                  ? null
                  : Row(mainAxisSize: MainAxisSize.min, children: actions),
              middleSpacing: PsSpace.s2,
            ),
          ),
        ),
      ),
    );
    return AnnotatedRegion(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: bar,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton(this.label, this.onBack);
  final String? label;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).back,
      excludeSemantics: true,
      child: InkWell(
        onTap: onBack ?? () => Navigator.maybePop(context),
        customBorder: const StadiumBorder(),
        child: SizedBox(
          height: PsSize.touch,
          child: Padding(
            padding: const EdgeInsets.only(right: PsSpace.s2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PsIcon(PsIcons.chevronLeft, size: 26, color: p.ink),
                if (label != null)
                  Text(
                    label!,
                    style: PsType.style(
                      PsFonts.sans,
                      16,
                      22,
                      FontWeight.w400,
                    ).copyWith(color: p.ink),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The serif page title of top-level pages (shelf, cast, settings), under a
/// [PsNavBar] and scrolling with the content.
class PsLargeTitle extends StatelessWidget {
  const PsLargeTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PsSpace.s5,
        PsSpace.s1,
        PsSpace.s5,
        PsSpace.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: context.psHeading(PsType.title1.copyWith(color: p.ink)),
            ),
          ),
          if (subtitle != null)
            Text(subtitle!, style: PsType.subhead.copyWith(color: p.ink2)),
        ],
      ),
    );
  }
}

/// An empty page: a quiet 「」, one sentence and one or two ways out, the
/// main one first. No illustrations.
class PsEmptyState extends StatelessWidget {
  const PsEmptyState({
    super.key,
    required this.title,
    this.body,
    this.actions = const [],
  });

  final String title;
  final String? body;

  /// [PsButton]s with `expand: true`.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: PsSpace.s10,
        horizontal: PsSpace.s6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PsMark(size: 72, quiet: true),
          const SizedBox(height: PsSpace.s6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.psHeading(PsType.title2.copyWith(color: p.ink)),
          ),
          if (body != null)
            Padding(
              padding: const EdgeInsets.only(top: PsSpace.s2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: PsType.body.copyWith(color: p.ink2, height: 23 / 15),
                ),
              ),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: PsSpace.s6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: PsSpace.s2,
                  children: actions,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
