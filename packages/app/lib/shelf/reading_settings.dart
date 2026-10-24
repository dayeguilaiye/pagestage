import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design/design.dart';

@immutable
class ReadingPreferences {
  const ReadingPreferences({
    this.fontSize = 18,
    this.lineSpacing = PsLineSpacing.comfortable,
    this.themeMode = ThemeMode.system,
  });

  static const minFontSize = 14.0;
  static const maxFontSize = 26.0;

  final double fontSize;
  final PsLineSpacing lineSpacing;

  /// Night mode: [ThemeMode.dark] is on, [ThemeMode.light] off.
  final ThemeMode themeMode;

  ReadingPreferences copyWith({
    double? fontSize,
    PsLineSpacing? lineSpacing,
    ThemeMode? themeMode,
  }) => ReadingPreferences(
    fontSize: fontSize ?? this.fontSize,
    lineSpacing: lineSpacing ?? this.lineSpacing,
    themeMode: themeMode ?? this.themeMode,
  );

  @override
  bool operator ==(Object other) =>
      other is ReadingPreferences &&
      other.fontSize == fontSize &&
      other.lineSpacing == lineSpacing &&
      other.themeMode == themeMode;

  @override
  int get hashCode => Object.hash(fontSize, lineSpacing, themeMode);
}

/// Text size, line spacing and night mode, shared by every book.
abstract interface class ReadingSettings
    implements ValueListenable<ReadingPreferences> {
  /// Applies [preferences] at once and keeps them across launches.
  void update(ReadingPreferences preferences);
}

/// Keeps the settings for this run only, until they are saved (#42).
class MemoryReadingSettings extends ValueNotifier<ReadingPreferences>
    implements ReadingSettings {
  MemoryReadingSettings([super.value = const ReadingPreferences()]);

  @override
  void update(ReadingPreferences preferences) => value = preferences;
}
