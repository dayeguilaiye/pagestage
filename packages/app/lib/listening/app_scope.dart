import 'package:flutter/widgets.dart';

import '../application/app_services.dart';
import '../shelf/bookshelf.dart';
import '../shelf/reading_settings.dart';

/// What every page may need without threading it through each route: the
/// books, the reading preferences and, when the app runs for real, the
/// listening, provider, consent and cast services.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.bookshelf,
    required this.readingSettings,
    required this.services,
    required super.child,
  });

  final Bookshelf bookshelf;
  final ReadingSettings readingSettings;

  /// Null in the gallery and in tests that only exercise reading.
  final AppServices? services;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  static AppServices? servicesOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()?.services;

  @override
  bool updateShouldNotify(AppScope old) =>
      old.bookshelf != bookshelf ||
      old.readingSettings != readingSettings ||
      old.services != services;
}
