import 'package:args/command_runner.dart';

import '../cli.dart';
import '../engines/engine.dart';
import '../profiler.dart';
import '../provider_configuration.dart';
import '../engines/llm_engine.dart';
import '../engines/standard_engines.dart';
import '../providers/llm_adapter.dart';

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
    final config = await ProviderConfiguration.load(
      argResults!['config'] as String?,
      environment: context.environment,
    );
    final options = await context.store.get('casting', book.id);
    final previousProviders = (options?['providers'] as List?)?.cast<String>();
    final catalog = standardTtsEngines.catalog(
      config,
      only: [
        for (final engine in standardTtsEngines.all)
          if (engine.readiness(config) == EngineReadiness.ready &&
              (previousProviders == null ||
                  previousProviders.contains(engine.id)))
            engine.id,
      ],
    );
    LlmAdapter? adapter;
    if (injected == null) {
      adapter = standardLlmEngines
          .active(config)
          .open(
            config,
            LlmRole.profile,
            usageLedger: context.usageLedger,
            runtime: context.requestRuntime,
          );
    }
    try {
      final result = await Profiler(
        context.store,
        injected ?? adapter!,
        voiceCatalog: () => catalog,
      ).profile(book, throughChapter: through, batchSize: batchSize);
      context.writeJson(result.toJson());
    } finally {
      if (adapter != null) closeLlm(adapter);
    }
  }
}
