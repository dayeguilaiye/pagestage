import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'gallery_page.dart';

/// The design system sheet: `flutter run -t lib/gallery/main.dart`.
void main() => runApp(const GalleryApp());

class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  var _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pagestage gallery',
      debugShowCheckedModeBanner: false,
      theme: PsTheme.light,
      darkTheme: PsTheme.dark,
      themeMode: _themeMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: GalleryPage(
        themeMode: _themeMode,
        onThemeMode: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}
