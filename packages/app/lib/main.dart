import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'application/diagnostics.dart';
import 'application/bundled_examples.dart';
import 'application/app_services.dart';
import 'storage.dart';

Future<void> main() async {
  DiagnosticLog? diagnostics;
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final root = await getApplicationSupportDirectory();
      diagnostics = DiagnosticLog(Directory('${root.path}/diagnostics'));
      diagnostics!.install();
      await diagnostics!.collectNative();
      LicenseRegistry.addLicense(_fontLicenses);
      final storage = await AppStorage.open(directory: root);
      await installBundledExamples(storage.store);
      final services = await AppServices.open(
        storage,
        diagnostics: diagnostics,
      );
      runApp(
        PagestageApp(
          bookshelf: storage.library,
          readingSettings: storage.readingSettings,
          services: services,
        ),
      );
    },
    (error, stack) {
      unawaited(diagnostics?.record(error, stack, source: 'zone'));
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
