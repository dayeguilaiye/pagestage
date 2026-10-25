import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/application/provider_store.dart';
import 'package:pagestage_core/pagestage_core.dart';

import 'support.dart';

void main() {
  late Directory root;
  late LocalStore store;
  late MemorySecrets secrets;
  late ProviderStore providers;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('provider-store-');
    store = LocalStore('${root.path}/db.sqlite');
    secrets = MemorySecrets();
    providers = await ProviderStore.open(store, secrets);
  });
  tearDown(() async {
    await providers.saved;
    providers.dispose();
    await store.close();
    await root.delete(recursive: true);
  });

  test(
    'keys stay in secure store; omitted keys survive edits and empty deletes',
    () async {
      const p = ProviderPreferences(
        baseUrl: 'https://example.test/v1',
        profileModel: 'profile',
      );
      await providers.save(
        p,
        llmKey: 'private-llm-value',
        minimaxKey: 'private-tts-value',
      );
      expect(providers.value.hasLlmKey, isTrue);
      final config = await providers.configuration();
      expect(LlmSettings.fromConfiguration(config).directorModel, 'profile');
      await providers.save(p);
      expect(secrets.values['llm'], 'private-llm-value');
      await providers.save(p, llmKey: '');
      expect(providers.value.hasLlmKey, isFalse);
      expect(providers.value.hasMinimaxKey, isTrue);
      final persisted = await store.get('settings', 'providers');
      expect(persisted.toString(), isNot(contains('private-')));
      final reopened = await ProviderStore.open(store, secrets);
      expect(reopened.value.hasMinimaxKey, isTrue);
      expect(reopened.value.profileModel, 'profile');
      reopened.dispose();
      expect(
        String.fromCharCodes(await File(store.path).readAsBytes()),
        isNot(contains('private-')),
      );
    },
  );

  test('rejects credentials in URL without persisting them', () async {
    expect(
      () => providers.save(
        const ProviderPreferences(baseUrl: 'https://key@example.test/v1'),
      ),
      throwsA(isA<ProviderException>()),
    );
    expect(await store.get('settings', 'providers'), isNull);
  });

  test(
    'consent cancellation, destination isolation, persistence and concurrent prompts',
    () async {
      final broker = ConsentBroker(store);
      final seen = <ConsentRequest>[];
      var accept = false;
      broker.addListener(() {
        final request = broker.value;
        if (request != null) {
          seen.add(request);
          broker.respond(request.id, accepted: accept);
        }
      });
      Future<bool> ask(String endpoint) => broker.request(
        bookTitle: 'Book',
        provider: 'llm',
        endpoint: endpoint,
        content: 'chapterTextAndCast',
      );
      expect(await ask('https://one.test'), isFalse);
      accept = true;
      expect(await ask('https://one.test'), isTrue);
      expect(await ask('https://one.test'), isTrue);
      expect(seen.length, 2);
      expect(
        await Future.wait([ask('https://two.test'), ask('https://three.test')]),
        [true, true],
      );
      expect(seen.length, 4);
      await broker.close();
      final reopened = ConsentBroker(store);
      expect(
        await reopened.request(
          bookTitle: 'Another book',
          provider: 'llm',
          endpoint: 'https://one.test',
          content: 'chapterTextAndCast',
        ),
        isTrue,
      );
      await reopened.close();
    },
  );
}
