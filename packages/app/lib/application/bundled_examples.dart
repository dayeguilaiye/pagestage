import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pagestage_core/pagestage_core.dart';

Future<void> installBundledExamples(
  LocalStore store, {
  AssetBundle? bundle,
}) async {
  final assets = bundle ?? rootBundle;
  final manifest = Map<String, Object?>.from(
    jsonDecode(await assets.loadString('assets/examples/manifest.json')) as Map,
  );
  await ExampleLibrary(store).install(
    manifest,
    (path) async => (await assets.load(path)).buffer.asUint8List(),
  );
}
