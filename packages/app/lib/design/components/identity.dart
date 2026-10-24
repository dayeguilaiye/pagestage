import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../tokens.dart';
import '../type.dart';

/// The same hash as `Pagestage.voiceTone` in the design system, so a name gets
/// the same pigment on the web and in the app. Use it only when the cast has
/// not stored a tone.
int psVoiceTone(String name) {
  var n = 0;
  for (final unit in name.codeUnits) {
    n = (n * 31 + unit) & 0xFFFFFFFF;
  }
  return n % 8 + 1;
}

/// Whether [s] has Han characters, which decides between the Chinese and
/// the Latin faces.
bool psHasCjk(String s) => RegExp(r'[㐀-鿿]').hasMatch(s);

/// The 「」 mark, optionally followed by the lowercase wordmark.
class PsMark extends StatelessWidget {
  const PsMark({
    super.key,
    this.size = 32,
    this.quiet = false,
    this.wordmark = false,
  });

  final double size;

  /// Lowers 「 to rule-strong, for empty states.
  final bool quiet;
  final bool wordmark;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(quiet ? p.ruleStrong : p.ink, p.vermilion),
    );
    if (!wordmark) {
      return Semantics(label: 'pagestage', image: true, child: mark);
    }
    final fontSize = (size * 0.78).roundToDouble();
    return Semantics(
      label: 'pagestage',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: fontSize * 0.32,
        children: [
          mark,
          Text(
            'pagestage',
            style: PsType.style(
              PsFonts.serifEn,
              fontSize,
              fontSize,
              FontWeight.w500,
              letterSpacing: -0.01 * fontSize,
            ).copyWith(color: p.ink),
          ),
        ],
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.open, this.close);
  final Color open;
  final Color close;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 64);
    Path poly(List<double> xy) {
      final path = Path()..moveTo(xy[0], xy[1]);
      for (var i = 2; i < xy.length; i += 2) {
        path.lineTo(xy[i], xy[i + 1]);
      }
      return path..close();
    }

    canvas.drawPath(
      poly([12, 12, 36, 12, 36, 19, 19, 19, 19, 38, 12, 38]),
      Paint()..color = open,
    );
    canvas.drawPath(
      poly([52, 52, 28, 52, 28, 45, 45, 45, 45, 26, 52, 26]),
      Paint()..color = close,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.open != open || old.close != close;
}

enum PsSealSize {
  sm(PsSize.sealSm, 12, 3),
  md(PsSize.seal, 17, PsRadius.xs),
  lg(56, 26, 6);

  const PsSealSize(this.side, this.fontSize, this.radius);
  final double side;
  final double fontSize;
  final double radius;
}

/// A speaker's seal: the first character of the name, cut out of a pigment.
/// The narrator gets a vermilion outline seal reading 旁.
class PsSeal extends StatelessWidget {
  const PsSeal({
    super.key,
    this.name,
    this.glyph,
    this.tone,
    this.narrator = false,
    this.size = PsSealSize.md,
  });

  final String? name;
  final String? glyph;

  /// 1–8, assigned in cast order and stored with the cast.
  final int? tone;
  final bool narrator;
  final PsSealSize size;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final l = AppLocalizations.of(context);
    final text = glyph ?? (narrator ? l.narratorSeal : _first(name ?? ''));
    return Semantics(
      label: name ?? (narrator ? l.narrator : text),
      excludeSemantics: true,
      child: Container(
        width: size.side,
        height: size.side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: narrator ? null : p.voice(tone ?? psVoiceTone(name ?? '')),
          borderRadius: BorderRadius.circular(size.radius),
          border: narrator
              ? Border.all(
                  color: p.vermilion,
                  width: size == PsSealSize.sm ? 1 : 1.5,
                )
              : null,
        ),
        child: Text(
          text,
          style: PsType.style(
            PsFonts.serif,
            size.fontSize,
            size.fontSize,
            FontWeight.w600,
          ).copyWith(color: narrator ? p.vermilion : p.onVoice),
        ),
      ),
    );
  }

  static String _first(String name) {
    final chars = name.trim().characters;
    if (chars.isEmpty) return '';
    final c = chars.first;
    return RegExp(r'[a-zA-Z]').hasMatch(c) ? c.toUpperCase() : c;
  }
}

/// The generated cover for books without one: a thread-bound book with a
/// vertical title slip for Chinese titles, a labelled cloth cover for Latin
/// ones. Covers stay deep pigment in both themes.
class PsBookCover extends StatelessWidget {
  const PsBookCover({
    super.key,
    required this.title,
    this.author,
    this.tone,
    this.width = 96,
    this.chinese,
  });

  final String title;
  final String? author;
  final int? tone;
  final double width;

  /// Defaults to whether the title contains Han characters.
  final bool? chinese;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final w = width;
    final h = (w * 1.5).roundToDouble();
    final zh = chinese ?? psHasCjk(title);
    final showText = w >= 56;
    final stamp = math.max(4.0, (w * 0.08).roundToDouble());
    return Semantics(
      label: title,
      image: true,
      excludeSemantics: true,
      child: Container(
        width: w,
        height: h,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.voice(tone ?? psVoiceTone(title)),
          borderRadius: BorderRadius.circular(PsRadius.xs),
          boxShadow: p.shadowRaise,
        ),
        child: Stack(
          children: zh
              ? _threadBound(p, w, h, showText, stamp)
              : _cloth(p, w, h, showText, stamp),
        ),
      ),
    );
  }

  List<Widget> _threadBound(
    PsPalette p,
    double w,
    double h,
    bool showText,
    double stamp,
  ) {
    final line = p.onVoice.withValues(alpha: 0.32);
    final fs = math.max(9.0, (w * 0.13).roundToDouble());
    final chars = title.characters.toList();
    final slipW = (fs * 1.7).roundToDouble();
    final slipH = showText
        ? math
              .min(chars.length * fs * 1.12 + fs * 1.1, h * 0.62)
              .roundToDouble()
        : (h * 0.42).roundToDouble();
    final fits = ((slipH - fs * 1.1) / (fs * 1.12) + 0.05).floor();
    final shown = chars.take(math.min(chars.length, math.max(fits, 0)));
    final top = h * 0.07;
    final left = w * 0.09;
    return [
      Positioned(
        top: 0,
        bottom: 0,
        right: w * 0.09,
        width: 1,
        child: ColoredBox(color: line),
      ),
      for (final t in const [0.14, 0.38, 0.62, 0.86])
        Positioned(
          top: h * t,
          right: 0,
          width: w * 0.09,
          height: 1,
          child: ColoredBox(color: line),
        ),
      Positioned(
        top: top,
        left: left,
        width: slipW,
        height: slipH,
        child: Container(
          color: p.slip,
          padding: const EdgeInsets.all(3),
          child: DecoratedBox(
            decoration: BoxDecoration(border: Border.all(color: p.ruleStrong)),
            child: showText
                ? ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      maxHeight: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.only(top: fs * 0.55 - 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final c in shown)
                              SizedBox(
                                height: fs * 1.12,
                                child: Center(
                                  child: Text(
                                    c,
                                    style: PsType.style(
                                      PsFonts.serif,
                                      fs,
                                      fs,
                                      FontWeight.w600,
                                    ).copyWith(color: p.onSlip),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
      Positioned(
        top: top + slipH - 3,
        left: left + slipW - 4,
        width: stamp,
        height: stamp,
        child: _stamp(p),
      ),
    ];
  }

  List<Widget> _cloth(
    PsPalette p,
    double w,
    double h,
    bool showText,
    double stamp,
  ) {
    final fs = math.max(8.0, (w * 0.105).roundToDouble());
    return [
      Positioned(
        left: w * 0.06,
        right: w * 0.06,
        top: h * 0.06,
        bottom: h * 0.06,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: p.onVoice.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      Positioned(
        top: h * 0.2,
        left: w * 0.13,
        right: w * 0.13,
        child: Container(
          color: p.slip,
          padding: EdgeInsets.fromLTRB(fs * 0.5, fs * 0.8, fs * 0.5, fs * 0.7),
          child: showText
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: fs * 0.45,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: PsType.style(
                        PsFonts.serifEn,
                        fs,
                        fs * 1.05,
                        FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ).copyWith(color: p.onSlip),
                    ),
                    if (author != null)
                      Text(
                        author!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: PsType.style(
                          PsFonts.sans,
                          fs * 0.5,
                          fs * 0.6,
                          FontWeight.w600,
                          letterSpacing: fs * 0.07,
                        ).copyWith(color: p.onSlip),
                      ),
                  ],
                )
              : SizedBox(height: fs * 2),
        ),
      ),
      Positioned(
        bottom: h * 0.12,
        left: (w - stamp) / 2,
        width: stamp,
        height: stamp,
        child: _stamp(p),
      ),
    ];
  }

  Widget _stamp(PsPalette p) => DecoratedBox(
    decoration: BoxDecoration(
      color: p.vermilion,
      borderRadius: BorderRadius.circular(1),
    ),
  );
}
