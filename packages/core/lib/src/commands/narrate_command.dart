import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli.dart';
import '../models/script.dart';
import '../models/cast.dart';
import '../models/voice.dart';
import '../provider_configuration.dart';
import '../providers/tts_settings.dart';
import '../providers/edge_tts_adapter.dart';
import '../synthesizer.dart';

class NarrateCommand extends Command<void> {
  NarrateCommand(this.context) {
    argParser
      ..addOption(
        'provider',
        allowed: ['minimax', 'bailian', 'edge'],
        defaultsTo: 'minimax',
        help: 'TTS provider.',
      )
      ..addOption('config', help: 'Local provider JSON configuration file.')
      ..addOption('model', help: 'Provider speech model.')
      ..addOption('voice', help: 'Provider preset voice parameter.')
      ..addOption('rate', help: 'Edge rate, e.g. +10% (default +0%).')
      ..addOption('volume', help: 'Edge volume, e.g. -10% (default +0%).')
      ..addOption('pitch', help: 'Edge pitch, e.g. +5Hz (default +0Hz).')
      ..addOption('output', help: 'Destination WAV path.');
  }
  final CliContext context;
  @override
  String get name => 'narrate';
  @override
  String get description =>
      'Synthesize an imported chapter as narrator paragraphs.';
  @override
  String get invocation => 'pagestage narrate <book-id> <chapter> [options]';

  @override
  Future<void> run() async {
    if (argResults!.rest.length != 2) {
      usageException('Provide a book ID and chapter number.');
    }
    final book = await context.library.getBook(argResults!.rest[0]);
    final number = int.tryParse(argResults!.rest[1]);
    if (number == null || number < 1 || number > book.chapters.length) {
      usageException('Provide a chapter number within the book.');
    }
    final chapter = book.chapter(number);
    final config = await ProviderConfiguration.load(
      argResults!['config'] as String?,
      environment: context.environment,
    );
    final provider = argResults!['provider'] as String;
    final envPrefix = provider.toUpperCase();
    final defaults = provider == 'edge'
        ? (
            model: EdgeTtsAdapter.model,
            zhVoice: 'zh-CN-XiaoxiaoNeural',
            enVoice: 'en-US-AriaNeural',
          )
        : provider == 'minimax'
        ? (
            model: 'speech-2.8-hd',
            zhVoice: 'Chinese (Mandarin)_Male_Announcer',
            enVoice: 'English_expressive_narrator',
          )
        : (
            model: 'qwen-audio-3.1-tts-flash',
            zhVoice: 'longsanshu_v3.1',
            enVoice: 'Emily_v3.1',
          );
    final model =
        argResults!['model'] as String? ??
        config.value(
          provider,
          'model',
          environmentVariable: '${envPrefix}_MODEL',
        ) ??
        defaults.model;
    final voice =
        argResults!['voice'] as String? ??
        config.value(
          provider,
          'voice',
          environmentVariable: '${envPrefix}_VOICE',
        ) ??
        (book.language == 'zh' ? defaults.zhVoice : defaults.enVoice);
    if (provider != 'edge' &&
        ['rate', 'volume', 'pitch'].any((name) => argResults![name] != null)) {
      usageException('Rate, volume and pitch options require --provider edge.');
    }
    final parameters = <String, Object?>{
      if (provider == 'edge')
        for (final name in ['rate', 'volume', 'pitch'])
          name:
              argResults![name] as String? ??
              config.value(
                'edge',
                name,
                environmentVariable: 'EDGE_${name.toUpperCase()}',
              ) ??
              (name == 'pitch' ? '+0Hz' : '+0%'),
    };
    final session = TtsProviderSession.open(
      config,
      providers: [provider],
      overrides: context.ttsAdapters,
      usageLedger: context.usageLedger,
      runtime: context.requestRuntime,
      queues: context.requestQueues,
    );
    try {
      final cast = await CastRepository(context.store).get(book.id);
      final result = await Synthesizer(adapters: session.adapters).synthesize(
        chapter: chapter,
        script: Script.narration(bookId: book.id, chapter: chapter),
        language: book.language,
        lexicon: cast.lexicon,
        voices: {
          'narrator': VoiceBinding(
            provider: provider,
            model: model,
            voiceId: voice,
            parameters: parameters,
          ),
        },
        outputPath:
            argResults!['output'] as String? ??
            p.join(
              context.dataDirectory.path,
              'audio',
              book.id,
              'chapter-$number.wav',
            ),
      );
      context.writeJson({
        'bookId': book.id,
        'chapter': number,
        'path': result.path,
        'durationMs': result.duration.inMilliseconds,
        'characters': result.characters,
        'requests': result.requests,
        'elapsedMs': result.elapsed.inMilliseconds,
        'provider': provider,
        'inputTokens': result.inputTokens,
        'outputTokens': result.outputTokens,
        'totalTokens': result.totalTokens,
        'model': model,
        'utterances': [
          for (final utterance in result.utterances)
            {
              'audioPath': utterance.audioPath,
              'rawAudioPath': utterance.rawAudioPath,
              'loudness': utterance.loudness.toJson(),
              'pronunciationApplied': utterance.pronunciationApplied,
              if (utterance.pronunciationWarning != null)
                'pronunciationWarning': utterance.pronunciationWarning,
            },
        ],
      });
    } finally {
      session.close();
    }
  }
}
