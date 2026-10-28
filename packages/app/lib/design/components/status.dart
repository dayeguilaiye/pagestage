import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';
import '../type.dart';
import 'controls.dart';

enum PsTagTone { neutral, outline, accent, jade, amber, danger }

/// One or two words of state beside a name. Never tag a persona: that is a
/// spoiler.
class PsTag extends StatelessWidget {
  const PsTag(
    this.label, {
    super.key,
    this.tone = PsTagTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final PsTagTone tone;
  final PsIcons? icon;

  /// 18px tall, for the mini player.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final (bg, fg) = switch (tone) {
      PsTagTone.neutral => (p.paperSunken, p.ink2),
      PsTagTone.outline => (null, p.ink2),
      PsTagTone.accent => (p.vermilionSoft, p.vermilion),
      PsTagTone.jade => (p.jadeSoft, p.jade),
      PsTagTone.amber => (p.amberSoft, p.amber),
      PsTagTone.danger => (p.dangerSoft, p.danger),
    };
    return Container(
      height: dense ? 18 : 20,
      padding: EdgeInsets.symmetric(horizontal: dense ? 5 : 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PsRadius.xs),
        border: tone == PsTagTone.outline
            ? Border.all(color: p.ruleStrong)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          if (icon != null) PsIcon(icon!, size: 12, color: fg),
          Text(
            label,
            style: (dense ? PsType.tag.copyWith(fontSize: 10) : PsType.tag)
                .copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Generation under way for a chapter. Chapters at rest, whether untouched
/// or ready to hear, carry no status at all: only the few in motion or
/// waiting on the reader are marked.
enum PsChapterStatus {
  queued,
  working,
  paused;

  String label(AppLocalizations l) => switch (this) {
    queued => l.chapterQueued,
    working => l.chapterWorking,
    paused => l.chapterPaused,
  };
}

/// A chapter's generation state, told apart by shape: dashed ring, spinner,
/// ▲. [label] replaces the generic word, e.g. with the voiced line count.
class PsStatusMark extends StatefulWidget {
  const PsStatusMark(
    this.status, {
    super.key,
    this.showLabel = false,
    this.label,
  });

  final PsChapterStatus status;
  final bool showLabel;
  final String? label;

  @override
  State<PsStatusMark> createState() => _PsStatusMarkState();
}

class _PsStatusMarkState extends State<PsStatusMark>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  void _sync() {
    final run =
        widget.status == PsChapterStatus.working &&
        !MediaQuery.disableAnimationsOf(context);
    if (run && !_spin.isAnimating) _spin.repeat();
    if (!run) _spin.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PsStatusMark old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final status = widget.status;
    final labelColor = switch (status) {
      PsChapterStatus.paused => p.danger,
      PsChapterStatus.working => p.amber,
      PsChapterStatus.queued => p.ink2,
    };
    final label = widget.label ?? status.label(AppLocalizations.of(context));
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          CustomPaint(
            size: const Size.square(14),
            painter: _StatusPainter(status, p, _spin),
          ),
          if (widget.showLabel || widget.label != null)
            Text(
              label,
              style: PsType.caption.copyWith(
                color: labelColor,
                // Counts and timers tick without the label jittering.
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPainter extends CustomPainter {
  _StatusPainter(this.status, this.p, this.spin) : super(repaint: spin);
  final PsChapterStatus status;
  final PsPalette p;
  final Animation<double> spin;

  @override
  void paint(Canvas canvas, Size size) {
    const c = Offset(7, 7);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fill = Paint();
    switch (status) {
      case PsChapterStatus.queued:
        // A dashed ring: a place held, nothing moving yet.
        for (var i = 0; i < 8; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: 5.25),
            -math.pi / 2 + i * math.pi / 4 + math.pi / 16,
            math.pi / 8,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5
              ..strokeCap = StrokeCap.round
              ..color = p.ruleStrong,
          );
        }
      case PsChapterStatus.working:
        canvas.drawCircle(c, 5.25, stroke..color = p.rule);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: 5.25),
          -math.pi / 2 + spin.value * 2 * math.pi,
          math.pi / 2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.75
            ..strokeCap = StrokeCap.round
            ..color = p.amber,
        );
      case PsChapterStatus.paused:
        final path = Path()
          ..moveTo(7, 1.2)
          ..lineTo(13, 12.4)
          ..lineTo(1, 12.4)
          ..close();
        canvas.drawPath(path, fill..color = p.danger);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..color = p.danger,
        );
    }
  }

  @override
  bool shouldRepaint(_StatusPainter old) => old.status != status || old.p != p;
}

/// Three bouncing bars: something is playing right here.
class PsEq extends StatefulWidget {
  const PsEq({super.key});

  @override
  State<PsEq> createState() => _PsEqState();
}

class _PsEqState extends State<PsEq> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _t.value = 0.25;
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.ps.vermilion;
    return ExcludeSemantics(
      child: SizedBox(
        width: 10,
        height: 12,
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) => Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: 2,
            children: [
              for (final phase in const [0.0, 0.35, 0.7])
                Container(
                  width: 2,
                  height:
                      12 *
                      (0.3 +
                          0.7 *
                              (0.5 -
                                  0.5 *
                                      math.cos(
                                        2 * math.pi * (_t.value + phase),
                                      ))),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum PsBannerTone { neutral, jade, amber, danger }

/// Something the reader should know that stays until it is dealt with: what
/// happened, what stopped and what to do next. Errors use a banner, never a
/// toast.
class PsBanner extends StatelessWidget {
  const PsBanner({
    super.key,
    this.tone = PsBannerTone.neutral,
    this.title,
    this.body,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.onClose,
  });

  final PsBannerTone tone;
  final String? title;
  final String? body;

  /// Defaults to alert for danger and amber, check for jade, book otherwise.
  final PsIcons? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Shows a close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final (bg, fg) = switch (tone) {
      PsBannerTone.neutral => (p.paperSunken, p.ink2),
      PsBannerTone.jade => (p.jadeSoft, p.jade),
      PsBannerTone.amber => (p.amberSoft, p.amber),
      PsBannerTone.danger => (p.dangerSoft, p.danger),
    };
    final glyph =
        icon ??
        switch (tone) {
          PsBannerTone.danger || PsBannerTone.amber => PsIcons.alert,
          PsBannerTone.jade => PsIcons.check,
          PsBannerTone.neutral => PsIcons.book,
        };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          PsSpace.s4,
          14,
          onClose == null ? PsSpace.s4 : PsSpace.s1,
          14,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(PsRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: PsSpace.s3,
          children: [
            PsIcon(
              glyph,
              size: 20,
              color: tone == PsBannerTone.neutral ? p.ink2 : fg,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: PsType.style(
                        PsFonts.sans,
                        15,
                        20,
                        FontWeight.w600,
                      ).copyWith(color: p.ink),
                    ),
                  if (body != null)
                    Text(
                      body!,
                      style: PsType.style(
                        PsFonts.sans,
                        13,
                        19,
                        FontWeight.w400,
                      ).copyWith(color: p.ink2),
                    ),
                  if (actionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(top: PsSpace.s2 - 2),
                      child: _LinkButton(
                        actionLabel!,
                        onAction,
                        tone == PsBannerTone.neutral ? p.ink : fg,
                      ),
                    ),
                ],
              ),
            ),
            if (onClose != null)
              Transform.translate(
                offset: const Offset(0, -6),
                child: PsIconButton(
                  icon: PsIcons.close,
                  label: AppLocalizations.of(context).close,
                  onPressed: onClose,
                  size: PsControlSize.sm,
                  muted: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton(this.label, this.onPressed, this.color);
  final String label;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PsSpace.s1),
          child: Text(
            label,
            style: PsType.style(PsFonts.sans, 14, 20, FontWeight.w600).copyWith(
              color: color,
              decoration: TextDecoration.underline,
              decorationColor: color,
              decorationThickness: 1,
            ),
          ),
        ),
      ),
    );
  }
}
