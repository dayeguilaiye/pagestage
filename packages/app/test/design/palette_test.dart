import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/design/tokens.dart';

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, p) in [
    ('light', PsPalette.light),
    ('dark', PsPalette.dark),
  ]) {
    group('$name palette', () {
      final surfaces = {
        'paper': p.paper,
        'paperRaised': p.paperRaised,
        'paperSunken': p.paperSunken,
        'spotlight': p.spotlight,
        'vermilionSoft': p.vermilionSoft,
        'jadeSoft': p.jadeSoft,
        'amberSoft': p.amberSoft,
        'dangerSoft': p.dangerSoft,
      };

      test('body text reads at 4.5:1 on every surface', () {
        for (final (text, color) in [('ink', p.ink), ('ink2', p.ink2)]) {
          for (final MapEntry(key: ground, value: bg) in surfaces.entries) {
            expect(
              contrast(color, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$text on $ground',
            );
          }
        }
      });

      test('text waiting for its voice still reads at 4.5:1 on paper', () {
        expect(contrast(p.inkWaiting, p.paper), greaterThanOrEqualTo(4.5));
        // Apart from both ink and non-story ink-2.
        expect(contrast(p.inkWaiting, p.ink2), greaterThan(1.3));
      });

      test('accents read at 4.5:1 on their grounds', () {
        final pairs = {
          'vermilion on paper': (p.vermilion, p.paper),
          'vermilion on paperRaised': (p.vermilion, p.paperRaised),
          'vermilion on vermilionSoft': (p.vermilion, p.vermilionSoft),
          'onVermilion on vermilion': (p.onVermilion, p.vermilion),
          'jade on jadeSoft': (p.jade, p.jadeSoft),
          'amber on amberSoft': (p.amber, p.amberSoft),
          'danger on dangerSoft': (p.danger, p.dangerSoft),
          'onSlip on slip': (p.onSlip, p.slip),
          for (var i = 0; i < p.voices.length; i++)
            'onVoice on voice-${i + 1}': (p.onVoice, p.voices[i]),
        };
        for (final MapEntry(key: label, value: (fg, bg)) in pairs.entries) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: label);
        }
      });

      test('control borders reach 3:1', () {
        for (final bg in [p.paper, p.paperRaised, p.paperSunken]) {
          expect(contrast(p.ruleStrong, bg), greaterThanOrEqualTo(3));
        }
      });
    });
  }
}
