import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/bundled_examples.dart';
import 'package:pagestage_app/application/cast_controller.dart';
import 'package:pagestage_app/application/listening_controller.dart';
import 'package:pagestage_app/application/provider_store.dart';
import 'package:pagestage_core/pagestage_core.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the bundled example auditions every voice that speaks, with no key',
    () async {
      final root = await Directory.systemTemp.createTemp('sample-audition-');
      final store = LocalStore('${root.path}/db.sqlite');
      addTearDown(() async {
        await store.close();
        await root.delete(recursive: true);
      });
      await installBundledExamples(store);
      final providers = await ProviderStore.open(store, MemorySecrets());
      final listening = ListeningController(
        store: store,
        engine: MemoryEngine(),
        speech: MemorySpeech(),
      );
      final engine = MemoryEngine();
      final casts = await CastController.open(
        store: store,
        providers: providers,
        consents: ConsentBroker(store),
        listening: listening,
        auditionEngine: engine,
      );
      addTearDown(() async {
        await casts.close();
        await listening.close();
        providers.dispose();
      });
      final book = (await Library(
        store,
      ).listBooks()).firstWhere((b) => b.language == 'zh');
      final state = await casts.load(book.id);
      // Only those who speak in the bundled chapter can be heard without a
      // key; the cast page offers no audition for the rest.
      final heard = [
        for (final member in state.members)
          if (member.spoken) member,
      ];
      expect(heard, isNotEmpty);
      expect(state.members.where((m) => !m.spoken), isNotEmpty);
      for (final member in heard) {
        await casts.audition(book.id, member.id);
        expect(
          engine.loads.last,
          endsWith('.m4a'),
          reason: '${member.name} plays a line from the chapter',
        );
        await casts.stopAudition();
      }
    },
  );
}
