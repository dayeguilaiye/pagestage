import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../cli.dart';
import '../evaluator.dart';
import '../models/cast.dart';
import '../models/gold_reference.dart';
import '../script_repository.dart';

class EvaluateCommand extends Command<void> {
  EvaluateCommand(this.context) {
    argParser.addOption('gold', help: 'Source-range gold reference JSON.');
    argParser.addOption(
      'speaker-map',
      help: 'JSON mapping gold speaker IDs to cast IDs.',
    );
  }
  final CliContext context;
  @override
  String get name => 'evaluate';
  @override
  String get description =>
      'Compare a saved script with a source-range speaker reference.';
  @override
  String get invocation =>
      'pagestage evaluate <book-id> <chapter> --gold <file> --speaker-map <file>';

  @override
  Future<void> run() async {
    final goldPath = argResults!['gold'] as String?;
    final mapPath = argResults!['speaker-map'] as String?;
    if (argResults!.rest.length != 2 || goldPath == null || mapPath == null) {
      usageException(
        'Provide a book ID, chapter number, --gold and --speaker-map.',
      );
    }
    final book = await context.library.getBook(argResults!.rest.first);
    final number = int.tryParse(argResults!.rest[1]);
    if (number == null || number < 1 || number > book.chapters.length) {
      usageException('Provide a chapter number in this book.');
    }
    final script = await ScriptRepository(context.store).get(book.id, number);
    if (script == null) {
      throw StateError('Direct this chapter before evaluating it.');
    }
    final reference = GoldReference.fromJson(
      jsonDecode(await File(goldPath).readAsString()),
    );
    final rawMap = jsonDecode(await File(mapPath).readAsString());
    if (rawMap is! Map ||
        rawMap.entries.any(
          (entry) =>
              entry.key is! String ||
              (entry.key as String).trim().isEmpty ||
              entry.value != null &&
                  (entry.value is! String ||
                      (entry.value as String).trim().isEmpty),
        )) {
      throw const FormatException(
        'Speaker map must be an object mapping gold IDs to cast IDs or null.',
      );
    }
    final result = const Evaluator().evaluate(
      book: book,
      cast: await CastRepository(context.store).get(book.id),
      script: script,
      reference: reference,
      speakerMap: Map<String, String?>.from(rawMap),
    );
    context.writeJson(result.toJson());
  }
}
