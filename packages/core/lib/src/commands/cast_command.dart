import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../casting.dart';
import '../cli.dart';
import '../preset_catalog.dart';
import '../provider_configuration.dart';
import '../providers/tts_settings.dart';

class CastCommand extends Command<void> {
  CastCommand(CliContext context) {
    addSubcommand(_Recommend(context));
    addSubcommand(_ListCast(context));
    addSubcommand(_Catalog(context));
    addSubcommand(_SetPreset(context));
    addSubcommand(_Audition(context));
  }
  @override
  String get name => 'cast';
  @override
  String get description =>
      'Recommend, select and audition voices for the cast.';
}

class _Recommend extends Command<void> {
  _Recommend(this.context) {
    argParser
      ..addOption('exclusive-count', defaultsTo: '20')
      ..addOption(
        'provider',
        allowed: ['all', 'minimax', 'bailian'],
        defaultsTo: 'all',
      )
      ..addOption(
        'region',
        allowed: ['beijing', 'singapore'],
        defaultsTo: 'beijing',
      );
  }
  final CliContext context;
  @override
  String get name => 'recommend';
  @override
  String get description =>
      'Recommend language-appropriate voices for a profiled book.';
  @override
  Future<void> run() async {
    if (argResults!.rest.length != 1) usageException('Provide one book ID.');
    final count = int.tryParse(argResults!['exclusive-count'] as String);
    if (count == null || count < 0) {
      usageException('Exclusive count must be non-negative.');
    }
    final book = await context.library.getBook(argResults!.rest.single);
    final provider = argResults!['provider'] as String;
    final result = await Casting(context.store).recommend(
      book,
      exclusiveCount: count,
      providers: provider == 'all' ? null : {provider},
      bailianRegion: argResults!['region'] as String,
    );
    context.writeJson(_castSummary(result));
  }
}

class _ListCast extends Command<void> {
  _ListCast(this.context);
  final CliContext context;
  @override
  String get name => 'list';
  @override
  String get description =>
      'List speakers and selected voices without profile spoilers.';
  @override
  Future<void> run() async {
    if (argResults!.rest.length != 1) usageException('Provide one book ID.');
    await context.library.getBook(argResults!.rest.single);
    context.writeJson(
      _castSummary(
        await Casting(context.store).getCasting(argResults!.rest.single),
      ),
    );
  }
}

Map<String, Object?> _castSummary(CastingResult result) => {
  'bookId': result.cast.bookId,
  'exclusiveSpeakerIds': result.exclusiveSpeakerIds.toList(),
  'warnings': result.warnings,
  'speakers': result.cast.speakers
      .map(
        (speaker) => {
          'speakerId': speaker.id,
          'name': speaker.name,
          'voiceId': result.voices[speaker.id]?.id,
          'binding': result.voices[speaker.id]?.binding.toJson(),
          'samplePath': result.voices[speaker.id]?.samplePath,
        },
      )
      .toList(),
};

class _Catalog extends Command<void> {
  _Catalog(this.context) {
    argParser.addOption('language', allowed: ['zh', 'en']);
  }
  final CliContext context;
  @override
  String get name => 'catalog';
  @override
  String get description =>
      'Show documented preset IDs and casting-tag provenance.';
  @override
  Future<void> run() async {
    if (argResults!.rest.isNotEmpty) {
      usageException('No positional arguments expected.');
    }
    final language = argResults!['language'] as String?;
    context.writeJson(
      defaultVoiceCatalog
          .where(
            (preset) => language == null || preset.languages.contains(language),
          )
          .map((preset) => preset.toJson())
          .toList(),
    );
  }
}

class _SetPreset extends Command<void> {
  _SetPreset(this.context);
  final CliContext context;
  @override
  String get name => 'set';
  @override
  String get description =>
      'Select a preset: <book-id> <speaker-id> <provider:voice-id>.';
  @override
  Future<void> run() async {
    if (argResults!.rest.length != 3) {
      usageException('Provide book, speaker and catalog preset IDs.');
    }
    final book = await context.library.getBook(argResults!.rest[0]);
    final voice = await Casting(
      context.store,
    ).selectPreset(book, argResults!.rest[1], argResults!.rest[2]);
    context.writeJson(voice.toJson());
  }
}

class _Audition extends Command<void> {
  _Audition(this.context) {
    argParser
      ..addOption(
        'speaker',
        help: 'Audition one speaker; default is every speaker.',
      )
      ..addOption('config', help: 'Local provider configuration JSON.')
      ..addOption('output-dir', help: 'Sample WAV directory.');
  }
  final CliContext context;
  @override
  String get name => 'audition';
  @override
  String get description =>
      'Synthesize and save a sample for each selected voice.';
  @override
  Future<void> run() async {
    if (argResults!.rest.length != 1) usageException('Provide one book ID.');
    final book = await context.library.getBook(argResults!.rest.single);
    final state = await Casting(context.store).getCasting(book.id);
    final speakerId = argResults!['speaker'] as String?;
    final voices = speakerId == null
        ? state.voices.values
        : [state.voices[state.cast.speaker(speakerId).id]].nonNulls;
    final config = await ProviderConfiguration.load(
      argResults!['config'] as String?,
      environment: context.environment,
    );
    final session = TtsProviderSession.open(
      config,
      providers: voices.map((v) => v.binding.provider),
      overrides: context.ttsAdapters,
      usageLedger: context.usageLedger,
      runtime: context.requestRuntime,
      queues: context.requestQueues,
    );
    try {
      final samples = await Casting(context.store, adapters: session.adapters)
          .audition(
            book,
            speakerId: speakerId,
            outputDirectory:
                argResults!['output-dir'] as String? ??
                p.join(context.dataDirectory.path, 'samples', book.id),
          );
      context.writeJson(samples.map((voice) => voice.toJson()).toList());
    } finally {
      session.close();
    }
  }
}
