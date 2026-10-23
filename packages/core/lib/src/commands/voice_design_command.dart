import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli.dart';
import '../models/cast.dart';
import '../provider_configuration.dart';
import '../providers/tts_settings.dart';
import '../voice_design.dart';

class VoiceDesignCommand extends Command<void> {
  VoiceDesignCommand(CliContext context) {
    addSubcommand(_Generate(context));
    addSubcommand(_List(context));
    addSubcommand(_Select(context));
  }
  @override
  String get name => 'voice-design';
  @override
  String get description =>
      'Generate, listen to and select designed voice candidates.';
}

class _Generate extends Command<void> {
  _Generate(this.context) {
    argParser
      ..addOption(
        'provider',
        allowed: ['minimax', 'bailian'],
        defaultsTo: 'minimax',
      )
      ..addOption('model', help: 'TTS target model; saved with each binding.')
      ..addOption(
        'description',
        help: 'Voice description; defaults to the speaker profile.',
      )
      ..addOption('preview-text', help: 'Words spoken by every candidate.')
      ..addOption('count', defaultsTo: '3', help: 'At least three candidates.')
      ..addOption('output-dir', help: 'Directory for candidate previews.')
      ..addOption('config', help: 'Local provider configuration JSON.');
  }
  final CliContext context;
  @override
  String get name => 'generate';
  @override
  String get description => 'Generate candidates: <book-id> <speaker-id>.';
  @override
  Future<void> run() async {
    if (argResults!.rest.length != 2) {
      usageException('Provide book and speaker IDs.');
    }
    final count = int.tryParse(argResults!['count'] as String);
    if (count == null || count < 3) {
      usageException('Generate at least three candidates.');
    }
    final book = await context.library.getBook(argResults!.rest[0]);
    final speakerId = argResults!.rest[1];
    final speaker = (await CastRepository(
      context.store,
    ).get(book.id)).speaker(speakerId);
    final description =
        argResults!['description'] as String? ?? speaker.voiceDescription;
    if (description.trim().isEmpty) {
      usageException('Provide a voice description.');
    }
    final provider = argResults!['provider'] as String;
    final config = await ProviderConfiguration.load(
      argResults!['config'] as String?,
      environment: context.environment,
    );
    final model =
        argResults!['model'] as String? ??
        config.value(
          provider,
          'model',
          environmentVariable: '${provider.toUpperCase()}_MODEL',
        ) ??
        (provider == 'minimax' ? 'speech-2.8-hd' : 'qwen-audio-3.1-tts-flash');
    final preview =
        argResults!['preview-text'] as String? ??
        (book.language == 'zh'
            ? '你好，故事即将开始。请跟随我的声音，一起走进书中的世界。'
            : 'Hello. Our story is about to begin. Follow my voice into the world of this book.');
    final session = TtsProviderSession.open(
      config,
      providers: [provider],
      overrides: context.ttsAdapters,
      usageLedger: context.usageLedger,
    );
    try {
      final candidates =
          await VoiceDesign(context.store, adapters: session.adapters).generate(
            book,
            speakerId,
            provider: provider,
            model: model,
            description: description,
            previewText: preview,
            count: count,
            outputDirectory:
                argResults!['output-dir'] as String? ??
                p.join(context.dataDirectory.path, 'voice-candidates', book.id),
          );
      context.writeJson(candidates.map((c) => c.toJson()).toList());
    } finally {
      session.close();
    }
  }
}

class _List extends Command<void> {
  _List(this.context) {
    argParser.addOption('speaker');
  }
  final CliContext context;
  @override
  String get name => 'list';
  @override
  String get description =>
      'List saved candidates and preview paths: <book-id>.';
  @override
  Future<void> run() async {
    if (argResults!.rest.length != 1) usageException('Provide one book ID.');
    final book = await context.library.getBook(argResults!.rest.single);
    final candidates = await VoiceDesign(
      context.store,
      adapters: {},
    ).list(book.id, speakerId: argResults!['speaker'] as String?);
    context.writeJson(candidates.map((c) => c.toJson()).toList());
  }
}

class _Select extends Command<void> {
  _Select(this.context) {
    argParser.addOption('config', help: 'Local provider configuration JSON.');
  }
  final CliContext context;
  @override
  String get name => 'select';
  @override
  String get description =>
      'Select a candidate: <book-id> <speaker-id> <candidate-id>.';
  @override
  Future<void> run() async {
    if (argResults!.rest.length != 3) {
      usageException('Provide book, speaker and candidate IDs.');
    }
    final book = await context.library.getBook(argResults!.rest[0]);
    final candidate = await VoiceDesign(
      context.store,
      adapters: {},
    ).get(argResults!.rest[2]);
    final provider = candidate.voice.binding.provider;
    final config = await ProviderConfiguration.load(
      argResults!['config'] as String?,
      environment: context.environment,
    );
    final session = TtsProviderSession.open(
      config,
      providers: provider == 'minimax' ? [provider] : [],
      overrides: context.ttsAdapters,
      usageLedger: context.usageLedger,
    );
    try {
      final selected = await VoiceDesign(
        context.store,
        adapters: session.adapters,
      ).select(book, argResults!.rest[1], candidate.id);
      context.writeJson(selected.toJson());
    } finally {
      session.close();
    }
  }
}
