import 'dart:io';

import 'package:pagestage_core/src/cli.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runCli(arguments);
}
