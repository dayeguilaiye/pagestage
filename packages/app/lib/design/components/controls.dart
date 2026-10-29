import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';
import '../type.dart';

/// Shrinks its child slightly while pressed; buttons use it instead of ripples.
class PsPressScale extends StatefulWidget {
  const PsPressScale({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PsPressScale> createState() => _PsPressScaleState();
}

class _PsPressScaleState extends State<PsPressScale> {
  var _down = false;

  void _set(bool down) {
    if (widget.enabled && down != _down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: PsMotion.fast,
        curve: PsMotion.standard,
        child: widget.child,
      ),
    );
  }
}

enum PsButtonVariant { primary, secondary, ghost, danger }

/// Pill button with a verb-phrase label. One [PsButtonVariant.primary] per
/// screen at most.
class PsButton extends StatelessWidget {
  const PsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = PsButtonVariant.secondary,
    this.small = false,
    this.icon,
    this.trailingIcon,
    this.loading = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final PsButtonVariant variant;
  final bool small;
  final PsIcons? icon;
  final PsIcons? trailingIcon;

  /// Shows a spinner and ignores taps, without greying the button out.
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final enabled = onPressed != null;
    final fg = !enabled
        ? p.inkFaint
        : switch (variant) {
            PsButtonVariant.primary => p.onVermilion,
            PsButtonVariant.danger => p.danger,
            _ => p.ink,
          };
    final iconSize = small ? 16.0 : 20.0;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(small ? 48 : 64, small ? PsSize.controlSm : PsSize.control),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: small ? 14 : PsSpace.s5),
      ),
      textStyle: WidgetStatePropertyAll(
        small
            ? PsType.style(PsFonts.sans, 13, 18, FontWeight.w600)
            : PsType.label,
      ),
      backgroundColor: variant == PsButtonVariant.danger && enabled
          ? WidgetStatePropertyAll(p.dangerSoft)
          : null,
      foregroundColor: variant == PsButtonVariant.danger
          ? WidgetStatePropertyAll(fg)
          : null,
    );
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: small ? 6 : PsSpace.s2,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
              backgroundColor: Colors.transparent,
            ),
          )
        else if (icon != null)
          PsIcon(icon!, size: iconSize, color: fg),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingIcon != null)
          PsIcon(trailingIcon!, size: iconSize, color: fg),
      ],
    );
    final tap = loading ? () {} : onPressed;
    final Widget button = switch (variant) {
      PsButtonVariant.primary || PsButtonVariant.danger => FilledButton(
        onPressed: tap,
        style: style,
        child: child,
      ),
      PsButtonVariant.secondary => OutlinedButton(
        onPressed: tap,
        style: style,
        child: child,
      ),
      PsButtonVariant.ghost => TextButton(
        onPressed: tap,
        style: style,
        child: child,
      ),
    };
    return PsPressScale(
      enabled: enabled && !loading,
      child: expand ? SizedBox(width: double.infinity, child: button) : button,
    );
  }
}

enum PsIconButtonVariant { ghost, tonal, outline }

enum PsControlSize {
  sm(PsSize.controlSm, 18),
  md(PsSize.touch, 22),
  lg(52, 28);

  const PsControlSize(this.side, this.iconSize);
  final double side;
  final double iconSize;
}

class PsIconButton extends StatelessWidget {
  const PsIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.variant = PsIconButtonVariant.ghost,
    this.size = PsControlSize.md,
    this.muted = false,
    this.active = false,
    this.iconSize,
  });

  final PsIcons icon;

  /// Read by screen readers and shown on long press.
  final String label;
  final VoidCallback? onPressed;
  final PsIconButtonVariant variant;
  final PsControlSize size;

  /// Lowers the icon to ink-2.
  final bool muted;

  /// A toggle that is on, such as a running sleep timer.
  final bool active;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final enabled = onPressed != null;
    final fg = !enabled
        ? p.inkFaint
        : active
        ? p.vermilion
        : muted
        ? p.ink2
        : p.ink;
    return PsPressScale(
      scale: 0.94,
      enabled: enabled,
      child: IconButton(
        onPressed: onPressed,
        tooltip: label,
        icon: PsIcon(icon, size: iconSize ?? size.iconSize, color: fg),
        style: IconButton.styleFrom(
          fixedSize: Size.square(size.side),
          minimumSize: Size.square(size.side),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: variant == PsIconButtonVariant.tonal
              ? p.paperSunken
              : null,
          side: variant == PsIconButtonVariant.outline
              ? BorderSide(color: enabled ? p.ruleStrong : p.rule)
              : null,
        ),
      ),
    );
  }
}

/// A small whole number between − and +, such as a lookahead. Each button
/// turns off at its end of the range.
class PsStepper extends StatelessWidget {
  const PsStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.min = 0,
    this.max = 99,
    this.unit,
  });

  final int value;

  /// Null turns both buttons off.
  final ValueChanged<int>? onChanged;

  /// Read by screen readers and shown on long press.
  final String decreaseLabel;
  final String increaseLabel;
  final int min;
  final int max;

  /// Follows the number in smaller type, such as 章.
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final change = onChanged;
    final unit = this.unit;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PsIconButton(
          icon: PsIcons.minus,
          label: decreaseLabel,
          variant: PsIconButtonVariant.outline,
          size: PsControlSize.sm,
          iconSize: 16,
          onPressed: change != null && value > min
              ? () => change(value - 1)
              : null,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: PsSpace.s2),
            child: Text.rich(
              TextSpan(
                text: '$value',
                children: [
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: PsType.subhead.copyWith(color: p.ink2),
                    ),
                ],
              ),
              textAlign: TextAlign.center,
              style: PsType.numeralLg.copyWith(
                color: p.ink,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        PsIconButton(
          icon: PsIcons.plus,
          label: increaseLabel,
          variant: PsIconButtonVariant.outline,
          size: PsControlSize.sm,
          iconSize: 16,
          onPressed: change != null && value < max
              ? () => change(value + 1)
              : null,
        ),
      ],
    );
  }
}

enum PsPlaySize {
  sm(PsSize.controlSm, 16, 5),
  md(PsSize.touch, 20, 5),
  lg(PsSize.play, 32, 7);

  const PsPlaySize(this.side, this.iconSize, this.ringInset);
  final double side;
  final double iconSize;
  final double ringInset;
}

/// The only solid dark circle in the app. While [buffering], a vermilion arc
/// turns around it: the next lines are still being synthesized, playback has
/// not stopped.
class PsPlayButton extends StatelessWidget {
  const PsPlayButton({
    super.key,
    required this.onPressed,
    this.playing = false,
    this.buffering = false,
    this.size = PsPlaySize.md,
    this.label,
  });

  final VoidCallback? onPressed;
  final bool playing;
  final bool buffering;
  final PsPlaySize size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final l = AppLocalizations.of(context);
    final text = label ?? (playing ? l.pause : l.play);
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: Tooltip(
        message: text,
        child: PsPressScale(
          scale: 0.94,
          child: GestureDetector(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size.side,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (buffering)
                    Positioned.fill(
                      left: -size.ringInset,
                      top: -size.ringInset,
                      right: -size.ringInset,
                      bottom: -size.ringInset,
                      child: _BufferingRing(track: p.rule, arc: p.vermilion),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.ink,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: PsIcon(
                        playing ? PsIcons.pause : PsIcons.play,
                        size: size.iconSize,
                        color: p.paper,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BufferingRing extends StatefulWidget {
  const _BufferingRing({required this.track, required this.arc});
  final Color track;
  final Color arc;

  @override
  State<_BufferingRing> createState() => _BufferingRingState();
}

class _BufferingRingState extends State<_BufferingRing>
    with SingleTickerProviderStateMixin {
  late final _turns = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _turns.stop();
    } else if (!_turns.isAnimating) {
      _turns.repeat();
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _turns,
      child: CustomPaint(painter: _ArcPainter(widget.track, widget.arc, 2)),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.track, this.arc, this.stroke);
  final Color track;
  final Color arc;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawOval(rect, paint..color = track);
    canvas.drawArc(rect, -math.pi / 2, math.pi / 2, false, paint..color = arc);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.track != track || old.arc != arc;
}

class PsSegment<T> {
  const PsSegment(this.value, this.label);
  final T value;
  final String label;
}

/// Two to four mutually exclusive options on a sunken track with a raised
/// thumb that slides between them.
class PsSegmentedControl<T> extends StatelessWidget {
  const PsSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.expand = false,
    this.small = false,
  });

  final List<PsSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final n = segments.length;
    final index = math.max(0, segments.indexWhere((s) => s.value == value));
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final s in segments)
          Expanded(
            child: Semantics(
              selected: s.value == value,
              inMutuallyExclusiveGroup: true,
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(s.value),
                child: SizedBox(
                  height: small ? 26 : 32,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: small ? PsSpace.s3 : PsSpace.s4,
                    ),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: PsMotion.fast,
                        style: PsType.style(
                          PsFonts.sans,
                          small ? 13 : 14,
                          18,
                          s.value == value ? FontWeight.w600 : FontWeight.w500,
                        ).copyWith(color: s.value == value ? p.ink : p.ink2),
                        child: Text(s.label, maxLines: 1, softWrap: false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.paperSunken,
        borderRadius: BorderRadius.circular(PsRadius.full),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(n == 1 ? 0 : index / (n - 1) * 2 - 1, 0),
              duration: PsMotion.base,
              curve: PsMotion.standard,
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.paperRaised,
                    borderRadius: BorderRadius.circular(PsRadius.full),
                    boxShadow: p.shadowRaise,
                  ),
                ),
              ),
            ),
          ),
          expand ? row : IntrinsicWidth(child: row),
        ],
      ),
    );
  }
}
