import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'boot.dart';

/// The first frame shows at once; storage, the examples and the services
/// open behind it, and a failure among them shows its own page instead of
/// a blank screen.
Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      LicenseRegistry.addLicense(_fontLicenses);
      runApp(const PagestageBoot());
    },
    (error, stack) {
      unawaited(bootDiagnostics?.record(error, stack, source: 'zone'));
    },
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
