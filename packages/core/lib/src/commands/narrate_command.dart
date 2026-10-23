import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../cli.dart';
import '../models/script.dart';
import '../models/voice.dart';
import '../provider_configuration.dart';
import '../providers/minimax_tts_adapter.dart';
import '../providers/provider_exception.dart';
import '../synthesizer.dart';

class NarrateCommand extends Command<void> {
  NarrateCommand(this.context) {
    argParser
      ..addOption('config', help: 'Local provider JSON configuration file.')
      ..addOption('model', help: 'MiniMax speech model.')
      ..addOption('voice', help: 'MiniMax preset voice identifier.')
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
    final model =
        argResults!['model'] as String? ??
        config.value(
          'minimax',
          'model',
          environmentVariable: 'MINIMAX_MODEL',
        ) ??
        'speech-2.8-hd';
    final voice =
        argResults!['voice'] as String? ??
        config.value(
          'minimax',
          'voice',
          environmentVariable: 'MINIMAX_VOICE',
        ) ??
        (book.language == 'zh'
            ? 'Chinese (Mandarin)_Male_Announcer'
            : 'English_expressive_narrator');
    var adapter = context.ttsAdapters['minimax'];
    MiniMaxTtsAdapter? ownedAdapter;
    if (adapter == null) {
      final key = config.value(
        'minimax',
        'key',
        environmentVariable: 'MINIMAX_API_KEY',
      );
      final baseUrl = Uri.tryParse(
        config.value(
              'minimax',
              'baseUrl',
              environmentVariable: 'MINIMAX_BASE_URL',
            ) ??
            'https://api.minimax.io/v1',
      );
      if (key == null || baseUrl == null) {
        throw const ProviderException(
          provider: 'minimax',
          kind: ProviderErrorKind.invalidConfiguration,
        );
      }
      ownedAdapter = MiniMaxTtsAdapter(apiKey: key, baseUrl: baseUrl);
      adapter = ownedAdapter;
    }
    try {
      final result = await Synthesizer(adapters: {'minimax': adapter})
          .synthesize(
            chapter: chapter,
            script: Script.narration(bookId: book.id, chapter: chapter),
            language: book.language,
            voices: {
              'narrator': VoiceBinding(
                provider: 'minimax',
                model: model,
                voiceId: voice,
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
        'provider': 'minimax',
        'model': model,
      });
    } finally {
      ownedAdapter?.close();
    }
  }
}
