import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';
import '../type.dart';
import 'controls.dart';

/// Opens [builder]'s [PsSheet] from the bottom of the screen.
Future<T?> showPsSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = false,
}) => showModalBottomSheet<T>(
  context: context,
  builder: builder,
  isScrollControlled: scrollControlled,
  useSafeArea: true,
  // PsSheet draws a tighter grabber than Material's 48px handle area.
  showDragHandle: false,
);

/// A panel rising from the bottom for a group of related settings or a short
/// flow: reading settings, sleep timer, speed, voices.
class PsSheet extends StatelessWidget {
  const PsSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.onClose,
    this.fill = false,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  /// Shows a close button.
  final VoidCallback? onClose;

  /// [child] is a scrolling list that takes the rest of the sheet and brings
  /// its own side padding.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final head = title != null || onClose != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 5,
            margin: const EdgeInsets.only(top: PsSpace.s2),
            decoration: BoxDecoration(
              color: p.ruleStrong,
              borderRadius: BorderRadius.circular(PsRadius.full),
            ),
          ),
        ),
        if (head)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PsSpace.s5,
              PsSpace.s4,
              PsSpace.s5,
              PsSpace.s3,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PsSpace.s3,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      if (title != null)
                        Semantics(
                          header: true,
                          child: Text(
                            title!,
                            style: context.psHeading(
                              PsType.title3.copyWith(color: p.ink),
                            ),
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
                if (onClose != null)
                  PsIconButton(
                    icon: PsIcons.close,
                    label: AppLocalizations.of(context).close,
                    onPressed: onClose,
                    variant: PsIconButtonVariant.tonal,
                    size: PsControlSize.sm,
                  ),
              ],
            ),
          ),
        if (fill)
          Flexible(child: child)
        else
          Padding(
            padding: EdgeInsets.fromLTRB(
              PsSpace.s5,
              0,
              PsSpace.s5,
              PsSpace.s6 + bottom,
            ),
            child: child,
          ),
      ],
    );
  }
}

/// A modal decision the reader must make before going on: consent before
/// sending text, generate-or-system-voice, deleting a book. Actions stack
/// vertically, the first one primary.
class PsDialog extends StatelessWidget {
  const PsDialog({
    super.key,
    required this.title,
    required this.actions,
    this.body,
  });

  /// A question or a conclusion, set in serif.
  final String title;
  final Widget? body;

  /// [PsButton]s with `expand: true`.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = DialogTheme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: Padding(
            padding: const EdgeInsets.all(PsSpace.s6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: context.psHeading(theme.titleTextStyle!)),
                if (body != null)
                  Padding(
                    padding: const EdgeInsets.only(top: PsSpace.s2),
                    child: DefaultTextStyle.merge(
                      style: theme.contentTextStyle,
                      child: body!,
                    ),
                  ),
                const SizedBox(height: PsSpace.s6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: PsSpace.s2,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A one-line confirmation of something done, above the bottom of the
/// screen. Errors use a [PsBanner] instead.
void showPsToast(BuildContext context, String message) {
  final p = context.ps;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          spacing: PsSpace.s3,
          children: [
            PsIcon(PsIcons.check, size: 18, color: p.paper),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

class PsMenuItem<T> {
  const PsMenuItem(this.value, this.label, {this.icon, this.danger = false});
  final T value;
  final String label;
  final PsIcons? icon;

  /// Deleting and the like.
  final bool danger;
}

/// A list of actions anchored beside [anchor], a rect in global coordinates.
/// Opening it never changes what is playing.
Future<T?> showPsMenu<T>(
  BuildContext context, {
  required Rect anchor,
  required List<PsMenuItem<T>> items,
}) {
  final p = context.ps;
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final local = Rect.fromPoints(
    overlay.globalToLocal(anchor.topLeft),
    overlay.globalToLocal(anchor.bottomRight),
  );
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(local, Offset.zero & overlay.size),
    constraints: const BoxConstraints(minWidth: 216),
    items: [
      for (final item in items)
        PopupMenuItem<T>(
          value: item.value,
          height: PsSize.touch,
          child: Row(
            spacing: PsSpace.s3,
            children: [
              if (item.icon != null)
                PsIcon(
                  item.icon!,
                  size: 20,
                  color: item.danger ? p.danger : p.ink2,
                ),
              Text(
                item.label,
                style: PsType.style(
                  PsFonts.sans,
                  15,
                  20,
                  FontWeight.w400,
                ).copyWith(color: item.danger ? p.danger : p.ink),
              ),
            ],
          ),
        ),
    ],
  );
}
