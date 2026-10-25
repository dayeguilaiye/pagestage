import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'application/app_services.dart';
import 'consent/consent_gate.dart';
import 'design/design.dart';
import 'l10n/app_localizations.dart';
import 'listening/app_scope.dart';
import 'listening/generation_gate.dart';
import 'shelf/bookshelf.dart';
import 'shelf/reading_settings.dart';
import 'shelf/shelf_page.dart';

class PagestageApp extends StatefulWidget {
  const PagestageApp({
    super.key,
    required this.bookshelf,
    required this.readingSettings,
    this.services,
    this.locale,
  });

  final Bookshelf bookshelf;
  final ReadingSettings readingSettings;

  /// Listening, providers, consent and casts. Without them the app reads
  /// silently, as the gallery and reading-only tests run it.
  final AppServices? services;

  /// Overrides the system language.
  final Locale? locale;

  static const locales = [Locale('zh', 'CN'), Locale('en')];

  /// Simplified Chinese for any Chinese, English for every other language.
  static Locale resolveLocale(
    List<Locale>? preferred,
    Iterable<Locale> supported,
  ) {
    for (final locale in preferred ?? const <Locale>[]) {
      if (locale.languageCode == 'zh') return locales.first;
      if (locale.languageCode == 'en') return locales.last;
    }
    return locales.last;
  }

  @override
  State<PagestageApp> createState() => _PagestageAppState();
}

class _PagestageAppState extends State<PagestageApp> {
  late var _themeMode = widget.readingSettings.value.themeMode;
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.readingSettings.addListener(_onSettings);
  }

  @override
  void dispose() {
    widget.readingSettings.removeListener(_onSettings);
    super.dispose();
  }

  // Text size changes stay inside the reader; only night mode rebuilds the
  // app.
  void _onSettings() {
    final mode = widget.readingSettings.value.themeMode;
    if (mode != _themeMode) setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    return AppScope(
      bookshelf: widget.bookshelf,
      readingSettings: widget.readingSettings,
      services: services,
      child: MaterialApp(
        navigatorKey: _navigator,
        onGenerateTitle: (_) => 'pagestage',
        debugShowCheckedModeBanner: false,
        theme: PsTheme.light,
        darkTheme: PsTheme.dark,
        themeMode: _themeMode,
        locale: widget.locale,
        supportedLocales: PagestageApp.locales,
        localeListResolutionCallback: PagestageApp.resolveLocale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        builder: services == null
            ? null
            : (context, child) {
                Widget gated = ConsentGate(
                  consents: services.consents,
                  navigatorKey: _navigator,
                  child: child!,
                );
                if (services.generation case final generation?) {
                  gated = GenerationGate(
                    generation: generation,
                    navigatorKey: _navigator,
                    child: gated,
                  );
                }
                return gated;
              },
        home: ShelfPage(
          bookshelf: widget.bookshelf,
          readingSettings: widget.readingSettings,
        ),
      ),
    );
  }
}
