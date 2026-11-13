import 'package:args/command_runner.dart';

import '../cli.dart';
import '../director.dart';
import '../models/cast.dart';
import '../provider_configuration.dart';
import '../engines/llm_engine.dart';
import '../engines/standard_engines.dart';
import '../providers/llm_adapter.dart';

class DirectCommand extends Command<void> {
  DirectCommand(this.context) {
    argParser.addOption(
      'chunk-characters',
      defaultsTo: '6000',
      help: 'Target Unicode characters per paragraph-aligned block.',
    );
    argParser.addOption('config', help: 'Local provider JSON settings.');
  }
  final CliContext context;
  @override
  String get name => 'direct';
  @override
  String get description =>
      'Direct a profiled chapter and print source-aligned script lines.';
  @override
  String get invocation => 'pagestage direct <book-id> <chapter> [options]';
  @override
  Future<void> run() async {
    if (argResults!.rest.length != 2) {
      usageException('Provide a book ID and chapter number.');
    }
    final book = await context.library.getBook(argResults!.rest.first);
    final chapter = int.tryParse(argResults!.rest[1]);
    final limit = int.tryParse(argResults!['chunk-characters'] as String);
    if (chapter == null ||
        chapter < 1 ||
        chapter > book.chapters.length ||
        limit == null ||
        limit < 1) {
      usageException('Provide a valid chapter and positive chunk size.');
    }
    if (chapter >
        (await CastRepository(context.store).get(book.id)).profiledThrough) {
      throw StateError('Profile this chapter before directing it.');
    }
    final injected = context.directorLlm;
    LlmAdapter? adapter;
    if (injected == null) {
      final config = await ProviderConfiguration.load(
        argResults!['config'] as String?,
        environment: context.environment,
      );
      adapter = standardLlmEngines
          .active(config)
          .open(
            config,
            LlmRole.director,
            usageLedger: context.usageLedger,
            runtime: context.requestRuntime,
          );
    }
    try {
      final result = await Director(
        context.store,
        injected ?? adapter!,
        chunkCharacters: limit,
        runtime: context.requestRuntime,
      ).direct(book, chapter);
      final cast = await CastRepository(context.store).get(book.id);
      context.writeJson({
        ...result.toJson(),
        'script': {
          ...result.script.toJson(),
          'lines': [
            for (final line in result.script.lines)
              {
                ...line.toJson(),
                'text': line.textIn(book.chapter(chapter).text),
                'speakerName':
                    cast.findSpeaker(line.direction.speakerId)?.name ??
                    'Narrator',
              },
          ],
        },
      });
    } finally {
      if (adapter != null) closeLlm(adapter);
    }
  }
}
