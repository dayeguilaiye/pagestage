import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(_fontLicenses);
  final storage = await AppStorage.open();
  runApp(
    PagestageApp(
      bookshelf: storage.library,
      readingSettings: storage.readingSettings,
    ),
  );
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
