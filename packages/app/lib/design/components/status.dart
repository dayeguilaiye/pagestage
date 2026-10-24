import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';
import '../type.dart';

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

enum PsChapterStatus {
  none('未导演'),
  directed('已导演'),
  synthesized('已合成'),
  working('生成中'),
  failed('出错');

  const PsChapterStatus(this.label);
  final String label;
}

/// A chapter's generation state, told apart by shape: ○ ◐ ● spinner ▲.
class PsStatusMark extends StatefulWidget {
  const PsStatusMark(this.status, {super.key, this.showLabel = false});

  final PsChapterStatus status;
  final bool showLabel;

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
      PsChapterStatus.failed => p.danger,
      PsChapterStatus.working => p.amber,
      _ => p.ink2,
    };
    return Semantics(
      label: status.label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          CustomPaint(
            size: const Size.square(14),
            painter: _StatusPainter(status, p, _spin),
          ),
          if (widget.showLabel)
            Text(
              status.label,
              style: PsType.caption.copyWith(color: labelColor),
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
      case PsChapterStatus.none:
        canvas.drawCircle(c, 5.25, stroke..color = p.ruleStrong);
      case PsChapterStatus.directed:
        canvas.drawCircle(c, 5.25, stroke..color = p.ink2);
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: 5.25),
          math.pi / 2,
          math.pi,
          true,
          fill..color = p.ink2,
        );
      case PsChapterStatus.synthesized:
        canvas.drawCircle(c, 6, fill..color = p.jade);
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
      case PsChapterStatus.failed:
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
