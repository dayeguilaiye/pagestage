import 'package:flutter/painting.dart';

abstract final class PsFonts {
  /// 思源宋体: Chinese reading text, titles, seals.
  static const serif = 'NotoSerifSC';

  /// Newsreader: English reading text and Latin titles, the wordmark.
  static const serifEn = 'Newsreader';

  /// Instrument Sans; Chinese falls back to 苹方 / 思源黑体.
  static const sans = 'InstrumentSans';

  /// DM Mono: timecodes, speeds, chapter numbers.
  static const mono = 'DMMono';

  static const sansFallback = ['PingFang SC', 'Noto Sans CJK SC'];
  static const serifEnFallback = [serif];
}

/// Text styles without colour; colour comes from the theme or the caller.
/// Line heights follow tokens.json in px and are distributed evenly, as CSS does.
abstract final class PsType {
  static final display = _serif(34, 42, FontWeight.w600);
  static final title1 = _serif(28, 36, FontWeight.w600);
  static final title2 = _serif(22, 30, FontWeight.w600);
  static final title3 = _serif(18, 26, FontWeight.w600);

  static final readingSm = _serif(16, 29, FontWeight.w400);
  static final reading = _serif(18, 32, FontWeight.w400);
  static final readingLg = _serif(21, 37, FontWeight.w400);

  static final readingEn = _serifEn(18, 29, FontWeight.w400);
  static final displayEn = _serifEn(34, 38, FontWeight.w500, -0.34);

  static final headline = _sans(17, 24, FontWeight.w600);
  static final body = _sans(15, 22, FontWeight.w400);
  static final label = _sans(15, 20, FontWeight.w600, 0.15);
  static final subhead = _sans(13, 18, FontWeight.w400);
  static final caption = _sans(12, 16, FontWeight.w500);
  static final tag = _sans(11, 14, FontWeight.w600, 0.22);

  static final numeral = _mono(13, 18, FontWeight.w400);
  static final numeralLg = _mono(15, 20, FontWeight.w500);

  /// Not a token: list row titles and chapter titles in the component specs.
  static final rowTitle = _sans(16, 22, FontWeight.w400);
  static final chapterTitle = _serif(16, 22, FontWeight.w400);

  /// Not a token: the one large figure a page or sheet is about, such as
  /// the space in use. Newsreader's lining figures read as print; mono's
  /// slashed zero would read as code.
  static final figure = _serifEn(40, 48, FontWeight.w500).copyWith(
    fontFeatures: const [
      FontFeature.liningFigures(),
      FontFeature.tabularFigures(),
    ],
  );

  /// [serif] set for an English interface: Newsreader at 500, with Noto
  /// Serif SC only for Han characters, so quotes and question marks around a
  /// Chinese book title keep their Latin forms.
  static TextStyle latinHeading(TextStyle serif) => style(
    PsFonts.serifEn,
    serif.fontSize!,
    serif.fontSize! * serif.height!,
    FontWeight.w500,
  ).copyWith(color: serif.color);

  static TextStyle style(
    String family,
    double size,
    double lineHeight,
    FontWeight weight, {
    double? letterSpacing,
    FontStyle? fontStyle,
  }) {
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: switch (family) {
        PsFonts.sans || PsFonts.mono => PsFonts.sansFallback,
        PsFonts.serifEn => PsFonts.serifEnFallback,
        _ => null,
      },
      fontSize: size,
      height: lineHeight / size,
      leadingDistribution: TextLeadingDistribution.even,
      fontWeight: weight,
      fontStyle: fontStyle,
      // The bundled faces are variable; weight alone does not move the wght axis.
      fontVariations: [
        FontVariation.weight(weight.value.toDouble()),
        if (family == PsFonts.serifEn) FontVariation.opticalSize(size),
      ],
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle _serif(double s, double lh, FontWeight w) =>
      style(PsFonts.serif, s, lh, w);
  static TextStyle _serifEn(double s, double lh, FontWeight w, [double? ls]) =>
      style(PsFonts.serifEn, s, lh, w, letterSpacing: ls);
  static TextStyle _sans(double s, double lh, FontWeight w, [double? ls]) =>
      style(PsFonts.sans, s, lh, w, letterSpacing: ls);
  static TextStyle _mono(double s, double lh, FontWeight w) =>
      style(PsFonts.mono, s, lh, w);
}
