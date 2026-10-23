import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'commands/profile_command.dart';
import 'commands/cast_command.dart';
import 'commands/direct_command.dart';
import 'providers/llm_adapter.dart';
import 'providers/provider_exception.dart';
import 'commands/narrate_command.dart';
import 'providers/tts_adapter.dart';
import 'library.dart';
import 'local_store.dart';

/// Resources shared by commands during a single CLI invocation.
class CliContext {
  CliContext({
    required this.dataDirectory,
    required this.output,
    Map<String, String>? environment,
    this.profileLlm,
    this.directorLlm,
    Map<String, TtsAdapter>? ttsAdapters,
  }) : environment = Map.unmodifiable(environment ?? Platform.environment),
       ttsAdapters = Map.unmodifiable(ttsAdapters ?? {}) {
    store = LocalStore(p.join(dataDirectory.path, 'pagestage.sqlite'));
    library = Library(store);
  }

  final Directory dataDirectory;
  final StringSink output;
  final Map<String, String> environment;
  final LlmAdapter? profileLlm;
  final LlmAdapter? directorLlm;
  final Map<String, TtsAdapter> ttsAdapters;
  late final LocalStore store;
  late final Library library;

  void writeJson(Object? value) =>
      output.writeln(const JsonEncoder.withIndent('  ').convert(value));
}

class PagestageCommandRunner extends CommandRunner<void> {
  PagestageCommandRunner(this.context)
    : super('pagestage', 'Import and produce multi-voice audiobooks.') {
    argParser.addOption('data-dir', defaultsTo: context.dataDirectory.path);
    addCommand(_ImportCommand(context));
    addCommand(_ChaptersCommand(context));
    addCommand(_BooksCommand(context));
    addCommand(ProfileCommand(context));
    addCommand(CastCommand(context));
    addCommand(DirectCommand(context));
    addCommand(NarrateCommand(context));
  }

  final CliContext context;
}

/// Entrypoint returns an exit code so callers can run the CLI in-process.
Future<int> runCli(
  List<String> arguments, {
  StringSink? output,
  StringSink? errorOutput,
  Map<String, String>? environment,
  LlmAdapter? profileLlm,
  LlmAdapter? directorLlm,
  Map<String, TtsAdapter>? ttsAdapters,
}) async {
  final out = output ?? stdout;
  final err = errorOutput ?? stderr;
  // Resolve the global storage option before constructing command resources.
  var dataPath = '.pagestage';
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i] == '--data-dir' && i + 1 < arguments.length) {
      dataPath = arguments[++i];
    } else if (arguments[i].startsWith('--data-dir=')) {
      dataPath = arguments[i].substring('--data-dir='.length);
    }
  }
  final context = CliContext(
    dataDirectory: Directory(dataPath),
    output: out,
    environment: environment,
    profileLlm: profileLlm,
    directorLlm: directorLlm,
    ttsAdapters: ttsAdapters,
  );
  try {
    await PagestageCommandRunner(context).run(arguments);
    return 0;
  } on ProviderException catch (error) {
    err.writeln(error);
    return 69;
  } on UsageException catch (error) {
    err.writeln(error);
    return 64;
  } on FormatException catch (error) {
    err.writeln('Invalid input: ${error.message}');
    return 65;
  } on FileSystemException catch (_) {
    err.writeln('Unable to read or write the requested local file.');
    return 74;
  } on StateError catch (error) {
    err.writeln(error.message);
    return 65;
  } finally {
    await context.store.close();
  }
}

class _ImportCommand extends Command<void> {
  _ImportCommand(this.context) {
    argParser.addOption('title', help: 'Display title for the book.');
  }
  final CliContext context;
  @override
  String get name => 'import';
  @override
  String get description => 'Import a TXT novel and list its chapters.';
  @override
  String get invocation => 'pagestage import <file> [--title <title>]';

  @override
  Future<void> run() async {
    if (argResults!.rest.length != 1) usageException('Provide one TXT path.');
    final book = await context.library.importTxt(
      argResults!.rest.single,
      title: argResults!['title'] as String?,
    );
    context.writeJson({
      'bookId': book.id,
      'title': book.title,
      'language': book.language,
      'chapters': book.chapters
          .map(
            (chapter) => {
              'number': chapter.number,
              'title': chapter.title,
              'characters': chapter.text.runes.length,
              if (chapter.volume != null) 'volume': chapter.volume,
            },
          )
          .toList(),
    });
  }
}

class _ChaptersCommand extends Command<void> {
  _ChaptersCommand(this.context);
  final CliContext context;
  @override
  String get name => 'chapters';
  @override
  String get description => 'List chapters of an imported book.';
  @override
  Future<void> run() async {
    if (argResults!.rest.length != 1) usageException('Provide one book ID.');
    final book = await context.library.getBook(argResults!.rest.single);
    context.writeJson({
      'bookId': book.id,
      'chapters': book.chapters
          .map(
            (chapter) => {
              'number': chapter.number,
              'title': chapter.title,
              'characters': chapter.text.runes.length,
              if (chapter.volume != null) 'volume': chapter.volume,
            },
          )
          .toList(),
    });
  }
}

class _BooksCommand extends Command<void> {
  _BooksCommand(this.context);
  final CliContext context;
  @override
  String get name => 'books';
  @override
  String get description => 'List imported books.';
  @override
  Future<void> run() async {
    if (argResults!.rest.isNotEmpty) usageException('No arguments expected.');
    context.writeJson(
      (await context.library.listBooks())
          .map(
            (book) => {
              'bookId': book.id,
              'title': book.title,
              'language': book.language,
              'chapters': book.chapters.length,
            },
          )
          .toList(),
    );
  }
}
