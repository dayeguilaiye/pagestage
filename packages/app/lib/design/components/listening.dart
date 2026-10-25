import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../icons.dart';
import '../theme.dart';
import '../tokens.dart';
import '../type.dart';
import 'controls.dart';
import 'identity.dart';
import 'status.dart' show PsTag, PsTagTone;

/// One line of a script, as the director split it.
@immutable
class PsLine {
  const PsLine(
    this.text, {
    this.speaker,
    this.current = false,
    this.skip = false,
    this.selected = false,
  });

  final String text;
  final String? speaker;

  /// Being read now: lit by the spotlight.
  final bool current;

  /// Non-story content: shown in ink-2 and skipped when reading aloud.
  final bool skip;

  /// Tapped, with its menu open.
  final bool selected;
}

@immutable
class PsPassageHeading {
  const PsPassageHeading({required this.title, this.number});
  final String title;
  final String? number;
}

/// Leading relative to the reading tokens, as the reading settings offer it.
enum PsLineSpacing {
  compact(0.9),
  comfortable(1),
  loose(1.125);

  const PsLineSpacing(this.factor);
  final double factor;
}

typedef PsLineTap =
    void Function(int paragraph, int line, Offset globalPosition);

/// Book text with the spotlight on the line being read. A tap on a line only
/// reports it; open the line menu from [onLineTap], never jump playback.
class PsPassage extends StatefulWidget {
  const PsPassage({
    super.key,
    required this.paragraphs,
    this.heading,
    this.fontSize = 18,
    this.lineSpacing = PsLineSpacing.comfortable,
    this.english = false,
    this.cue = true,
    this.onLineTap,
    this.paragraphKeys,
  });

  final List<List<PsLine>> paragraphs;
  final PsPassageHeading? heading;

  /// 14–26 in the reading settings; 18 is the `reading` token.
  final double fontSize;
  final PsLineSpacing lineSpacing;
  final bool english;

  /// Hangs the speaker's name before the current line.
  final bool cue;
  final PsLineTap? onLineTap;

  /// One key per paragraph, so a reader can scroll a line into view.
  final List<Key>? paragraphKeys;

  @override
  State<PsPassage> createState() => _PsPassageState();
}

class _PsPassageState extends State<PsPassage> {
  final _recognizers = <TapGestureRecognizer>[];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  TextStyle _base() {
    // Scales the leading of `reading` (18/32) and `reading-en` (18/29).
    final ratio =
        (widget.english ? 29 / 18 : 32 / 18) * widget.lineSpacing.factor;
    return PsType.style(
      widget.english ? PsFonts.serifEn : PsFonts.serif,
      widget.fontSize,
      (widget.fontSize * ratio).roundToDouble(),
      FontWeight.w400,
    );
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final p = context.ps;
    final base = _base().copyWith(color: p.ink);
    final fs = base.fontSize!;
    final heading = widget.heading;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: PsSize.measureEm * fs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heading != null)
            Padding(
              padding: const EdgeInsets.only(bottom: PsSpace.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: PsSpace.s2,
                children: [
                  if (heading.number != null)
                    Text(
                      heading.number!,
                      style: PsType.caption.copyWith(
                        color: p.ink2,
                        letterSpacing: 3.6,
                      ),
                    ),
                  Text(
                    heading.title,
                    style:
                        (widget.english
                                ? PsType.style(
                                    PsFonts.serifEn,
                                    22,
                                    30,
                                    FontWeight.w600,
                                  )
                                : PsType.title2)
                            .copyWith(color: p.ink),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < widget.paragraphs.length; i++)
            Padding(
              key: widget.paragraphKeys?[i],
              padding: EdgeInsets.only(
                bottom: fs * (widget.english ? 0.75 : 0.5),
              ),
              child: _paragraph(i, base, p),
            ),
        ],
      ),
    );
  }

  Widget _paragraph(int pi, TextStyle base, PsPalette p) {
    final fs = base.fontSize!;
    final spans = <InlineSpan>[];
    final placeholders = <PlaceholderDimensions>[];
    var offset = 0;
    TextRange? spot;
    int? spotLine;

    final indent = widget.english ? (pi == 0 ? 0.0 : fs * 1.4) : fs * 2;
    if (indent > 0) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: SizedBox(width: indent, height: 0),
        ),
      );
      placeholders.add(
        PlaceholderDimensions(
          size: Size(indent, 0),
          alignment: PlaceholderAlignment.bottom,
        ),
      );
      offset += 1;
    }

    final lines = widget.paragraphs[pi];
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      final start = offset;
      if (line.current && line.speaker != null && widget.cue) {
        final cue = _Cue(line.speaker!, p);
        spans.add(
          WidgetSpan(alignment: PlaceholderAlignment.middle, child: cue),
        );
        placeholders.add(
          PlaceholderDimensions(
            size: cue.size,
            alignment: PlaceholderAlignment.middle,
          ),
        );
        offset += 1;
      }
      TapGestureRecognizer? tap;
      final onLineTap = widget.onLineTap;
      if (onLineTap != null) {
        tap = TapGestureRecognizer()
          ..onTapUp = (d) => onLineTap(pi, li, d.globalPosition);
        _recognizers.add(tap);
      }
      spans.add(
        TextSpan(
          text: line.text,
          recognizer: tap,
          style: line.skip
              ? TextStyle(color: p.ink2)
              : line.selected
              ? TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: p.vermilion,
                  decorationThickness: 1.5,
                )
              : null,
        ),
      );
      offset += line.text.length;
      if (line.current) {
        spot = TextRange(start: start, end: offset);
        spotLine = li;
      }
    }

    return _SpotlitText(
      span: TextSpan(style: base, children: spans),
      placeholders: placeholders,
      spot: spot,
      spotKey: spotLine == null ? null : '$pi:$spotLine',
      color: p.spotlight,
      // The book's language, not the interface's, picks the glyph forms.
      locale: widget.english ? const Locale('en') : const Locale('zh', 'CN'),
      // Flutter justifies CJK by stretching the gaps of short lines, so keep
      // Chinese text start-aligned; full-width characters leave little rag.
      align: TextAlign.start,
      inflate: Size(fs * 0.08, fs * 0.1),
    );
  }
}

class _Cue extends StatelessWidget {
  _Cue(this.speaker, this.p) : size = _measure(speaker);

  final String speaker;
  final PsPalette p;
  final Size size;

  static final _style = PsType.style(
    PsFonts.sans,
    11,
    17,
    FontWeight.w600,
    letterSpacing: 0.22,
  );
  static const _gap = 7.0;

  static Size _measure(String speaker) {
    final tp = TextPainter(
      text: TextSpan(text: speaker, style: _style),
      textDirection: TextDirection.ltr,
    )..layout();
    final size = Size(tp.width + 10 + _gap, 17);
    tp.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: Padding(
        padding: const EdgeInsets.only(right: _gap),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.vermilionSoft,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            child: Text(
              speaker,
              textScaler: TextScaler.noScaling,
              style: _style.copyWith(color: p.vermilion),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints rounded spotlight rectangles behind [spot], one per visual line,
/// measured with a [TextPainter] laid out exactly like the [RichText].
class _SpotlitText extends StatelessWidget {
  const _SpotlitText({
    required this.span,
    required this.placeholders,
    required this.spot,
    required this.spotKey,
    required this.color,
    required this.locale,
    required this.align,
    required this.inflate,
  });

  final TextSpan span;
  final List<PlaceholderDimensions> placeholders;
  final TextRange? spot;
  final String? spotKey;
  final Color color;
  final Locale locale;
  final TextAlign align;
  final Size inflate;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final text = RichText(
      text: span,
      textAlign: align,
      textScaler: scaler,
      locale: locale,
    );
    final range = spot;
    if (range == null) return text;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: span,
          textAlign: align,
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          locale: locale,
        )..setPlaceholderDimensions(placeholders);
        tp.layout(maxWidth: constraints.maxWidth);
        final rects = _byLine(
          tp.getBoxesForSelection(
            TextSelection(baseOffset: range.start, extentOffset: range.end),
          ),
        );
        tp.dispose();
        return TweenAnimationBuilder<double>(
          key: ValueKey(spotKey),
          tween: Tween(begin: 0, end: 1),
          duration: PsMotion.base,
          curve: PsMotion.standard,
          builder: (context, t, child) => CustomPaint(
            painter: _SpotPainter(
              rects,
              color.withValues(alpha: color.a * t),
              inflate,
            ),
            child: child,
          ),
          child: text,
        );
      },
    );
  }

  static List<Rect> _byLine(List<TextBox> boxes) {
    final out = <Rect>[];
    for (final b in boxes) {
      final r = b.toRect();
      if (r.isEmpty && r.width == 0) continue;
      if (out.isNotEmpty &&
          r.top < out.last.bottom - 1 &&
          r.bottom > out.last.top + 1) {
        out.last = out.last.expandToInclude(r);
      } else {
        out.add(r);
      }
    }
    return out;
  }
}

class _SpotPainter extends CustomPainter {
  _SpotPainter(this.rects, this.color, this.inflate);
  final List<Rect> rects;
  final Color color;
  final Size inflate;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final r in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            r.left - inflate.width,
            r.top - inflate.height,
            r.right + inflate.width,
            r.bottom + inflate.height,
          ),
          const Radius.circular(PsRadius.xs),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotPainter old) =>
      old.color != color || old.rects != rects;
}

/// The player docked above the bottom safe area on the shelf and reader.
/// A tag always says where the voice comes from: 「AI 合成」 for generated
/// audio, 「系统朗读」 for the phone's own voice.
class PsMiniPlayer extends StatelessWidget {
  const PsMiniPlayer({
    super.key,
    required this.book,
    required this.title,
    this.subtitle,
    this.speaker,
    this.speakerTone,
    this.narratorSpeaking = false,
    this.bookTone,
    this.playing = false,
    this.buffering = false,
    this.progress = 0,
    this.synthesized = true,
    this.onToggle,
    this.onNext,
    this.onTap,
  });

  final String book;

  /// The current chapter.
  final String title;
  final String? subtitle;
  final String? speaker;
  final int? speakerTone;
  final bool narratorSpeaking;
  final int? bookTone;
  final bool playing;
  final bool buffering;

  /// Progress through the chapter, 0–1.
  final double progress;

  /// Generated audio rather than the system voice.
  final bool synthesized;
  final VoidCallback? onToggle;
  final VoidCallback? onNext;

  /// Opens the full player.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final l = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label: l.player,
      child: Container(
        height: PsSize.miniPlayer,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.paperRaised,
          borderRadius: BorderRadius.circular(PsRadius.lg),
          border: Border.all(color: p.rule),
          boxShadow: p.shadowFloat,
        ),
        child: Stack(
          children: [
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: PsSpace.s3,
                    right: PsSpace.s1,
                  ),
                  child: Row(
                    spacing: PsSpace.s3,
                    children: [
                      PsBookCover(title: book, tone: bookTone, width: 32),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 3,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PsType.style(
                                PsFonts.sans,
                                15,
                                20,
                                FontWeight.w600,
                              ).copyWith(color: p.ink),
                            ),
                            Row(
                              spacing: 6,
                              children: [
                                if (speaker != null || narratorSpeaking)
                                  PsSeal(
                                    name: speaker,
                                    tone: speakerTone,
                                    narrator: narratorSpeaking,
                                    size: PsSealSize.sm,
                                  ),
                                if (subtitle != null)
                                  Flexible(
                                    child: Text(
                                      subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: PsType.caption.copyWith(
                                        color: p.ink2,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                PsTag(
                                  synthesized ? l.aiVoice : l.systemVoice,
                                  tone: PsTagTone.outline,
                                  dense: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PsPlayButton(
                        playing: playing,
                        buffering: buffering,
                        onPressed: onToggle,
                      ),
                      PsIconButton(
                        icon: PsIcons.lineForward,
                        label: l.nextLine,
                        onPressed: onNext,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: PsSpace.s5,
              right: PsSpace.s5,
              bottom: 0,
              height: 2,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(1),
                ),
                child: ColoredBox(
                  color: p.rule,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0, 1),
                    child: ColoredBox(color: p.ink),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
