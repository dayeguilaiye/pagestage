import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../casting.dart';
import '../cli.dart';
import '../models/cast.dart';
import '../models/script.dart';
import '../provider_configuration.dart';
import '../providers/tts_settings.dart';
import '../script_repository.dart';
import '../synthesizer.dart';

class SynthesizeCommand extends Command<void> {
  SynthesizeCommand(this.context) {
    argParser
      ..addOption('config', help: 'Local provider JSON configuration file.')
      ..addOption(
        'mode',
        allowed: ['audiobook', 'drama'],
        defaultsTo: 'audiobook',
      )
      ..addFlag(
        'merge-narrator',
        defaultsTo: false,
        help:
            'Join adjacent narrator lines with the same emotion and intensity.',
      )
      ..addOption('output', help: 'Destination chapter WAV path.');
  }
  final CliContext context;
  @override
  String get name => 'synthesize';
  @override
  String get description =>
      'Synthesize a saved script using its selected speaker voices.';
  @override
  String get invocation => 'pagestage synthesize <book-id> <chapter> [options]';

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
    final script = await ScriptRepository(context.store).get(book.id, number);
    if (script == null) {
      throw StateError('Direct this chapter before synthesis.');
    }
    if (script.sourceTextHash != chapter.textHash) {
      throw StateError('Direct the updated chapter before synthesis.');
    }
    final mode = PerformanceMode.values.byName(argResults!['mode'] as String);
    String? skipped(ScriptLine line) => line.isNonStory
        ? 'nonStory'
        : mode == PerformanceMode.drama && line.isDialogueTag
        ? 'dialogueTag'
        : line.textIn(chapter.text).trim().isEmpty
        ? 'whitespace'
        : null;
    final speakerIds = script.lines
        .where((line) => skipped(line) == null)
        .map((line) => line.direction.speakerId)
        .toSet();
    final bindings = await Casting(
      context.store,
    ).prepareChapterBindings(book, number, speakerIds: speakerIds);
    final session = TtsProviderSession.open(
      await ProviderConfiguration.load(
        argResults!['config'] as String?,
        environment: context.environment,
      ),
      providers: speakerIds.map((id) {
        final binding = bindings[id];
        if (binding == null) {
          throw StateError('A speaker has no voice binding.');
        }
        return binding.provider;
      }),
      overrides: context.ttsAdapters,
      usageLedger: context.usageLedger,
      runtime: context.requestRuntime,
      queues: context.requestQueues,
    );
    try {
      final cast = await CastRepository(context.store).get(book.id);
      final result =
          await Synthesizer(
            adapters: session.adapters,
            cacheDirectory: Directory(
              p.join(context.dataDirectory.path, 'audio', 'cache'),
            ),
          ).synthesize(
            chapter: chapter,
            script: script,
            language: book.language,
            lexicon: cast.lexicon,
            voices: bindings,
            mode: mode,
            mergeAdjacentNarrator: argResults!['merge-narrator'] as bool,
            outputPath:
                argResults!['output'] as String? ??
                p.join(
                  context.dataDirectory.path,
                  'audio',
                  book.id,
                  'chapter-$number-${mode.name}.wav',
                ),
          );
      final byLine = {
        for (final utterance in result.utterances)
          for (final index in utterance.lineIndices) index: utterance,
      };
      context.writeJson({
        'bookId': book.id,
        'chapter': number,
        'mode': mode.name,
        'path': result.path,
        'durationMs': result.duration.inMilliseconds,
        'characters': result.characters,
        'requests': result.requests,
        'cacheHits': result.cacheHits,
        'elapsedMs': result.elapsed.inMilliseconds,
        'inputTokens': result.inputTokens,
        'outputTokens': result.outputTokens,
        'totalTokens': result.totalTokens,
        'scriptModel': script.model,
        'promptVersion': script.promptVersion,
        'lines': [
          for (var index = 0; index < script.lines.length; index++)
            {
              ...script.lines[index].toJson(),
              'text': script.lines[index].textIn(chapter.text),
              'speakerName':
                  cast
                      .findSpeaker(script.lines[index].direction.speakerId)
                      ?.name ??
                  'Narrator',
              'skipped': skipped(script.lines[index]),
              if (byLine[index] case final utterance?) ...{
                'audioPath': utterance.audioPath,
                'rawAudioPath': utterance.rawAudioPath,
                'loudness': utterance.loudness.toJson(),
                'pronunciationApplied': utterance.pronunciationApplied,
                if (utterance.pronunciationWarning != null)
                  'pronunciationWarning': utterance.pronunciationWarning,
                'cacheKey': utterance.cacheKey,
                'cacheHit': utterance.cacheHit,
                'utteranceLineIndices': utterance.lineIndices,
                'utteranceDurationMs': utterance.duration.inMilliseconds,
                'pauseBeforeMs': utterance.pauseBefore.inMilliseconds,
              },
            },
        ],
      });
    } finally {
      session.close();
    }
  }
}
