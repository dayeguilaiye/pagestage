import 'package:args/command_runner.dart';

import '../cli.dart';
import '../profiler.dart';
import '../provider_configuration.dart';
import '../providers/llm_settings.dart';

class ProfileCommand extends Command<void> {
  ProfileCommand(this.context) {
    argParser.addOption(
      'through',
      help: 'Last chapter to profile (one-based).',
      mandatory: true,
    );
    argParser.addOption(
      'batch-size',
      defaultsTo: '1',
      help: 'Chapters saved together after each LLM request.',
    );
    argParser.addOption('config', help: 'Local provider JSON settings.');
  }
  final CliContext context;
  @override
  String get name => 'profile';
  @override
  String get description =>
      'Extend a book’s profiled range, preserving completed batches.';
  @override
  Future<void> run() async {
    if (argResults!.rest.length != 1) usageException('Provide one book ID.');
    final through = int.tryParse(argResults!['through'] as String);
    final batchSize = int.tryParse(argResults!['batch-size'] as String);
    final book = await context.library.getBook(argResults!.rest.single);
    if (through == null ||
        through < 1 ||
        through > book.chapters.length ||
        batchSize == null ||
        batchSize < 1) {
      usageException('Provide a valid chapter range and positive batch size.');
    }
    final injected = context.profileLlm;
    final adapter = injected == null
        ? LlmSettings.fromConfiguration(
            await ProviderConfiguration.load(
              argResults!['config'] as String?,
              environment: context.environment,
            ),
          ).createProfileAdapter(
            usageLedger: context.usageLedger,
            runtime: context.requestRuntime,
          )
        : null;
    try {
      final result = await Profiler(
        context.store,
        injected ?? adapter!,
      ).profile(book, throughChapter: through, batchSize: batchSize);
      context.writeJson(result.toJson());
    } finally {
      adapter?.close();
    }
  }
}
