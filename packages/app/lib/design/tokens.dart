// Values mirror tokens.json in the pagestage design system
// (https://claude.ai/artifact/3tcMfit4fxmas1EeCzsYeY). Change them there first.
import 'package:flutter/material.dart';

@immutable
class PsPalette extends ThemeExtension<PsPalette> {
  const PsPalette({
    required this.paper,
    required this.paperRaised,
    required this.paperSunken,
    required this.rule,
    required this.ruleStrong,
    required this.ink,
    required this.ink2,
    required this.inkFaint,
    required this.inkWaiting,
    required this.vermilion,
    required this.vermilionSoft,
    required this.onVermilion,
    required this.spotlight,
    required this.jade,
    required this.jadeSoft,
    required this.amber,
    required this.amberSoft,
    required this.danger,
    required this.dangerSoft,
    required this.scrim,
    required this.voices,
    required this.onVoice,
    required this.slip,
    required this.onSlip,
    required this.shadowRaise,
    required this.shadowFloat,
  });

  final Color paper;
  final Color paperRaised;
  final Color paperSunken;
  final Color rule;
  final Color ruleStrong;
  final Color ink;
  final Color ink2;
  final Color inkFaint;

  /// Text of a chapter being generated that has no voice yet: lighter than
  /// [ink2], so it reads apart from non-story text, still 4.5:1 on paper.
  final Color inkWaiting;
  final Color vermilion;
  final Color vermilionSoft;
  final Color onVermilion;
  final Color spotlight;
  final Color jade;
  final Color jadeSoft;
  final Color amber;
  final Color amberSoft;
  final Color danger;
  final Color dangerSoft;
  final Color scrim;

  /// voice-1 … voice-8: 黛、石青、石绿、赭石、胭脂、檀、藤紫、苍.
  final List<Color> voices;
  final Color onVoice;
  final Color slip;
  final Color onSlip;
  final List<BoxShadow> shadowRaise;
  final List<BoxShadow> shadowFloat;

  /// [tone] is 1–8, as stored on the cast.
  Color voice(int tone) => voices[(tone - 1) % voices.length];

  /// A 2px page-coloured gap, then 2px of solid vermilion.
  List<BoxShadow> get focusRing => [
    BoxShadow(color: vermilion, spreadRadius: 4),
    BoxShadow(color: paper, spreadRadius: 2),
  ];

  static const light = PsPalette(
    paper: Color(0xFFF4EFE6),
    paperRaised: Color(0xFFFBF8F3),
    paperSunken: Color(0xFFEBE4D7),
    rule: Color(0xFFDCD3C3),
    ruleStrong: Color(0xFF8C806E),
    ink: Color(0xFF1C1814),
    ink2: Color(0xFF5C5246),
    inkFaint: Color(0xFFA89D8D),
    inkWaiting: Color(0xFF73685B),
    vermilion: Color(0xFFB4361C),
    vermilionSoft: Color(0xFFF6DED3),
    onVermilion: Color(0xFFFFF9F4),
    spotlight: Color(0xFFF2E2B3),
    jade: Color(0xFF2B6A5B),
    jadeSoft: Color(0xFFDCEBE4),
    amber: Color(0xFF875800),
    amberSoft: Color(0xFFF5E7C6),
    danger: Color(0xFFA3221D),
    dangerSoft: Color(0xFFF7DCD8),
    scrim: Color(0x591C1814),
    voices: [
      Color(0xFF2E3A4B),
      Color(0xFF2C5A88),
      Color(0xFF3D6A3F),
      Color(0xFF8A5225),
      Color(0xFF9A2C48),
      Color(0xFF6B4A3A),
      Color(0xFF5D4986),
      Color(0xFF566428),
    ],
    onVoice: Color(0xFFFBF8F3),
    slip: Color(0xFFFBF8F3),
    onSlip: Color(0xFF1C1814),
    shadowRaise: [
      BoxShadow(color: Color(0x0F1C1814), offset: Offset(0, 1), blurRadius: 2),
      BoxShadow(color: Color(0x0A1C1814), offset: Offset(0, 1), blurRadius: 1),
    ],
    shadowFloat: [
      BoxShadow(
        color: Color(0x2E1C1814),
        offset: Offset(0, 10),
        blurRadius: 30,
        spreadRadius: -8,
      ),
      BoxShadow(color: Color(0x141C1814), offset: Offset(0, 2), blurRadius: 8),
    ],
  );

  static const dark = PsPalette(
    paper: Color(0xFF161412),
    paperRaised: Color(0xFF211E1B),
    paperSunken: Color(0xFF0E0D0B),
    rule: Color(0xFF302B26),
    ruleStrong: Color(0xFF766C60),
    ink: Color(0xFFEEE7DA),
    ink2: Color(0xFFACA292),
    inkFaint: Color(0xFF5F574D),
    inkWaiting: Color(0xFF898073),
    vermilion: Color(0xFFF07C5E),
    vermilionSoft: Color(0xFF3C2019),
    onVermilion: Color(0xFF1A0E0A),
    spotlight: Color(0xFF3B3122),
    jade: Color(0xFF7FC4AF),
    jadeSoft: Color(0xFF16302A),
    amber: Color(0xFFE6B762),
    amberSoft: Color(0xFF33280F),
    danger: Color(0xFFF28C82),
    dangerSoft: Color(0xFF3E1B17),
    scrim: Color(0xA6000000),
    voices: [
      Color(0xFF45556B),
      Color(0xFF3D6C9B),
      Color(0xFF45724A),
      Color(0xFF925C2C),
      Color(0xFFA63D58),
      Color(0xFF7C5A48),
      Color(0xFF6E5B99),
      Color(0xFF606D31),
    ],
    onVoice: Color(0xFFF2ECE1),
    slip: Color(0xFFECE5D8),
    onSlip: Color(0xFF1C1814),
    shadowRaise: [
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
    ],
    shadowFloat: [
      BoxShadow(
        color: Color(0xB3000000),
        offset: Offset(0, 14),
        blurRadius: 36,
        spreadRadius: -6,
      ),
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 8),
    ],
  );

  @override
  PsPalette copyWith() => this;

  @override
  PsPalette lerp(PsPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return PsPalette(
      paper: c(paper, other.paper),
      paperRaised: c(paperRaised, other.paperRaised),
      paperSunken: c(paperSunken, other.paperSunken),
      rule: c(rule, other.rule),
      ruleStrong: c(ruleStrong, other.ruleStrong),
      ink: c(ink, other.ink),
      ink2: c(ink2, other.ink2),
      inkFaint: c(inkFaint, other.inkFaint),
      inkWaiting: c(inkWaiting, other.inkWaiting),
      vermilion: c(vermilion, other.vermilion),
      vermilionSoft: c(vermilionSoft, other.vermilionSoft),
      onVermilion: c(onVermilion, other.onVermilion),
      spotlight: c(spotlight, other.spotlight),
      jade: c(jade, other.jade),
      jadeSoft: c(jadeSoft, other.jadeSoft),
      amber: c(amber, other.amber),
      amberSoft: c(amberSoft, other.amberSoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      scrim: c(scrim, other.scrim),
      voices: [
        for (var i = 0; i < voices.length; i++) c(voices[i], other.voices[i]),
      ],
      onVoice: c(onVoice, other.onVoice),
      slip: c(slip, other.slip),
      onSlip: c(onSlip, other.onSlip),
      shadowRaise: BoxShadow.lerpList(shadowRaise, other.shadowRaise, t)!,
      shadowFloat: BoxShadow.lerpList(shadowFloat, other.shadowFloat, t)!,
    );
  }
}

abstract final class PsSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;

  /// Screen gutter.
  static const s5 = 20.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
  static const s10 = 40.0;
  static const s12 = 48.0;
  static const s16 = 64.0;
}

abstract final class PsRadius {
  /// Seals, covers, tags, the reading highlight.
  static const xs = 4.0;

  /// Inputs, pressed menu items.
  static const sm = 8.0;

  /// Grouped lists, cards, menus, banners, toasts.
  static const md = 12.0;

  /// Sheet tops, dialogs, the mini player.
  static const lg = 20.0;

  /// Buttons, the play button, chips, switches, segmented controls.
  static const full = 9999.0;
}

abstract final class PsSize {
  static const touch = 44.0;
  static const control = 44.0;
  static const controlSm = 32.0;
  static const seal = 36.0;
  static const sealSm = 24.0;
  static const play = 72.0;
  static const miniPlayer = 64.0;

  /// Maximum reading line length, in ems of the reading size.
  static const measureEm = 36.0;
}

abstract final class PsMotion {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const standard = Cubic(0.2, 0, 0, 1);
  static const exit = Cubic(0.4, 0, 1, 1);
}
