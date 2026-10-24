import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'shelf/memory_bookshelf.dart';
import 'shelf/reading_settings.dart';

void main() {
  LicenseRegistry.addLicense(_fontLicenses);
  runApp(
    PagestageApp(
      // In memory until the library and saved settings are wired in (#28).
      bookshelf: MemoryBookshelf.demo(),
      readingSettings: MemoryReadingSettings(),
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
