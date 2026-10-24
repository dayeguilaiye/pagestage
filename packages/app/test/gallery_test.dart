import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/gallery/main.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('the gallery lays out on a phone in ${brightness.name} mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const GalleryApp());
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('图标'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
