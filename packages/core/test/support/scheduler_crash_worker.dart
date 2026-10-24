import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';

import 'generation_fakes.dart';

/// Test process exits during chapter 2, without closing its scheduler or store.
Future<void> main(List<String> args) async {
  final store = LocalStore('${args.single}/db.sqlite');
  final book = (await Library(store).listBooks()).single;
  final profile = GenerationLlm()
    ..before = (chapter) {
      if (chapter == 2) exit(0);
    };
  final scheduler = await Scheduler.open(
    store: store,
    profileLlm: profile,
    directorLlm: GenerationLlm(),
    ttsAdapters: {},
  );
  await scheduler.enqueue(book.id, TaskKind.profile, through: 3);
  await scheduler.idle;
}
