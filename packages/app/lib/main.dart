import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design/design.dart';
import 'gallery/gallery_page.dart';

void main() {
  LicenseRegistry.addLicense(_fontLicenses);
  runApp(const PagestageApp());
}

Stream<LicenseEntry> _fontLicenses() async* {
  for (final family in const [
    'NotoSerifSC',
    'Newsreader',
    'InstrumentSans',
    'DMMono',
  ]) {
    final text = await rootBundle.loadString('assets/fonts/$family-OFL.txt');
    yield LicenseEntryWithLineBreaks([family], text);
  }
}

class PagestageApp extends StatefulWidget {
  const PagestageApp({super.key});

  @override
  State<PagestageApp> createState() => _PagestageAppState();
}

class _PagestageAppState extends State<PagestageApp> {
  var _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pagestage',
      debugShowCheckedModeBanner: false,
      theme: PsTheme.light,
      darkTheme: PsTheme.dark,
      themeMode: _themeMode,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: GalleryPage(
        themeMode: _themeMode,
        onThemeMode: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}
