import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../book_package.dart';
import '../cli.dart';
import '../synthesizer.dart';

/// Packs a book's text, cast and scripts, optionally with its audio, into
/// one file another device can import.
class ExportCommand extends Command<void> {
  ExportCommand(this.context) {
    argParser
      ..addOption(
        'kind',
        allowed: BookPackageKind.values.map((kind) => kind.name),
        defaultsTo: 'script',
        help: 'script: text, cast and scripts. audio: also the voiced audio.',
      )
      ..addOption(
        'mode',
        allowed: PerformanceMode.values.map((mode) => mode.name),
        help: 'Which audio to pack; defaults to the book\'s saved mode.',
      )
      ..addOption(
        'audio-format',
        allowed: ['wav', 'm4a'],
        defaultsTo: 'wav',
        help: 'm4a encodes 64 kbps AAC with afconvert (macOS) or ffmpeg.',
      );
  }
  final CliContext context;
  @override
  String get name => 'export';
  @override
  String get description =>
      'Export a book as a script package or an audio package.';
  @override
  String get invocation =>
      'pagestage export <book-id> <output${BookPackages.extension}> [options]';

  @override
  Future<void> run() async {
    if (argResults!.rest.length != 2) {
      usageException('Provide a book ID and an output path.');
    }
    final output = argResults!.rest[1];
    if (p.extension(output).toLowerCase() != BookPackages.extension) {
      usageException('The output path must end in ${BookPackages.extension}.');
    }
    final mode = argResults!['mode'] as String?;
    final summary = await BookPackages(context.store).export(
      argResults!.rest[0],
      output,
      kind: BookPackageKind.values.byName(argResults!['kind'] as String),
      mode: mode == null ? null : PerformanceMode.values.byName(mode),
      transcode: argResults!['audio-format'] == 'm4a' ? _toAac : null,
    );
    context.writeJson({
      ...summary.toJson(),
      'path': File(output).absolute.path,
      'bytes': await File(output).length(),
    });
  }
}

Future<File> _toAac(File wav, Directory scratch) async {
  final output = File(
    p.join(scratch.path, '${p.basenameWithoutExtension(wav.path)}.m4a'),
  );
  final result = Platform.isMacOS
      ? await Process.run('/usr/bin/afconvert', [
          wav.path,
          output.path,
          '-f',
          'm4af',
          '-d',
          'aac',
          '-b',
          '64000',
        ])
      : await Process.run('ffmpeg', [
          '-y',
          '-i',
          wav.path,
          '-c:a',
          'aac',
          '-b:a',
          '64k',
          output.path,
        ]);
  if (result.exitCode != 0) throw StateError('The AAC encoder failed.');
  return output;
}
