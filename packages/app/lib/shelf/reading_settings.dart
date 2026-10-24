import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pagestage_core/pagestage_core.dart';

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

/// In-memory preferences for previews and widget tests.
class MemoryReadingSettings extends ValueNotifier<ReadingPreferences>
    implements ReadingSettings {
  MemoryReadingSettings([super.value = const ReadingPreferences()]);

  @override
  void update(ReadingPreferences preferences) => value = preferences;
}

/// Applies edits immediately and serializes writes so rapid slider changes
/// survive restart in the same order they appeared on screen.
class SavedReadingSettings extends ValueNotifier<ReadingPreferences>
    implements ReadingSettings {
  SavedReadingSettings._(this._store, super.value);
  final LocalStore _store;
  Future<void> _saved = Future.value();
  Future<void> get saved => _saved;

  static Future<SavedReadingSettings> open(LocalStore store) async {
    final json = await store.get('settings', 'reading');
    final preferences = json == null
        ? const ReadingPreferences()
        : ReadingPreferences(
            fontSize: (json['fontSize'] as num).toDouble(),
            lineSpacing: PsLineSpacing.values.byName(
              json['lineSpacing'] as String,
            ),
            themeMode: ThemeMode.values.byName(json['themeMode'] as String),
          );
    return SavedReadingSettings._(store, preferences);
  }

  @override
  void update(ReadingPreferences preferences) {
    if (!preferences.fontSize.isFinite ||
        preferences.fontSize < ReadingPreferences.minFontSize ||
        preferences.fontSize > ReadingPreferences.maxFontSize) {
      throw ArgumentError.value(preferences.fontSize, 'fontSize');
    }
    value = preferences;
    _saved = _saved.then(
      (_) => _store.put('settings', 'reading', {
        'fontSize': preferences.fontSize,
        'lineSpacing': preferences.lineSpacing.name,
        'themeMode': preferences.themeMode.name,
      }),
    );
    _saved.catchError((Object error, StackTrace stack) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack),
      );
    });
  }
}
