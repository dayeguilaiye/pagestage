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
      const values = {
        'baseUrl': 'https://example.test/v1',
        'profileModel': 'profile',
      };
      await providers.configure(
        'llm',
        values: values,
        secrets: {'key': 'private-llm-value'},
      );
      await providers.configure(
        'minimax',
        secrets: {'key': 'private-tts-value'},
      );
      expect(providers.value.llmReady, isTrue);
      expect(providers.value.engine('llm')!.secrets, {'key'});
      final config = await providers.configuration();
      expect(LlmSettings.fromConfiguration(config).directorModel, 'profile');
      // Saving other settings keeps the key; an empty value removes it.
      await providers.configure('llm', values: values);
      expect(secrets.values['llm.key'], 'private-llm-value');
      await providers.configure('llm', secrets: {'key': ''});
      expect(providers.value.llmReady, isFalse);
      expect(providers.value.engine('llm')!.secrets, isEmpty);
      expect(providers.value.voiceProviders, {'minimax'});
      // What screens and the local store see never includes a key.
      expect(providers.settings.value('minimax', 'key'), isNull);
      final persisted = await store.get('settings', 'engines');
      expect(persisted.toString(), isNot(contains('private-')));
      final reopened = await ProviderStore.open(store, secrets);
      expect(reopened.value.engine('minimax')!.ready, isTrue);
      expect(reopened.value.engine('llm')!.value('profileModel'), 'profile');
      reopened.dispose();
      expect(
        String.fromCharCodes(await File(store.path).readAsBytes()),
        isNot(contains('private-')),
      );
    },
  );

  test('rejects credentials in URL without persisting them', () async {
    expect(
      () => providers.configure(
        'llm',
        values: {'baseUrl': 'https://key@example.test/v1'},
      ),
      throwsA(isA<ProviderException>()),
    );
    // A secret may only be saved as a secret, and only a setting the engine
    // declares.
    expect(
      () => providers.configure('minimax', values: {'key': 'in-the-open'}),
      throwsA(isA<ProviderException>()),
    );
    expect(
      () => providers.configure('edge', values: {'anything': 'x'}),
      throwsA(isA<ProviderException>()),
    );
    expect(
      () => providers.configure('bailian', values: {'region': 'mars'}),
      throwsA(isA<ProviderException>()),
    );
    expect(await store.get('settings', 'engines'), isNull);
  });

  test('every registered engine is listed with what it needs and can do', () {
    final engines = providers.value.engines;
    expect(engines.map((e) => e.id), [
      'llm',
      'llm-device',
      'minimax',
      'bailian',
      'edge',
      'device',
    ]);
    final minimax = providers.value.engine('minimax')!;
    expect(minimax.status, EngineStatus.needsSetup);
    // On from the start: nothing is sent until its key is stored.
    expect(minimax.on, isTrue);
    expect(minimax.settings.map((s) => s.name), ['region', 'key']);
    expect(minimax.traits, {
      EngineTrait.emotion,
      EngineTrait.vocalCues,
      EngineTrait.pacing,
      EngineTrait.voiceDesign,
    });
    expect(minimax.voiceCount, greaterThan(20));
    final edge = providers.value.engine('edge')!;
    expect(edge.ready, isTrue);
    expect(edge.on, isFalse);
    expect(edge.traits, {EngineTrait.pacing});
    expect(providers.value.voiceProviders, isEmpty);
    // The on-device slots are named but not offered.
    for (final id in ['llm-device', 'device']) {
      final engine = providers.value.engine(id)!;
      expect(engine.site, EngineSite.device);
      expect(engine.status, EngineStatus.unavailable);
    }
    expect(providers.value.language!.id, 'llm');
  });

  test('switches, the language choice and regions persist', () async {
    await providers.switchVoice('edge', true);
    await providers.configure(
      'bailian',
      values: {'region': 'singapore'},
      secrets: {'key': 'k'},
    );
    expect(providers.value.voiceProviders, {'bailian', 'edge'});
    // Singapore offers its own presets and cannot design voices.
    final bailian = providers.value.engine('bailian')!;
    expect(bailian.traits, isNot(contains(EngineTrait.voiceDesign)));
    await providers.switchVoice('bailian', false);
    await providers.selectLanguage('llm-device');
    final reopened = await ProviderStore.open(store, secrets);
    expect(reopened.value.voiceProviders, {'edge'});
    expect(reopened.value.engine('bailian')!.value('region'), 'singapore');
    expect(reopened.value.language!.id, 'llm-device');
    expect(reopened.value.llmReady, isFalse);
    expect(
      (await reopened.configuration()).value('llm', 'engine'),
      'llm-device',
    );
    reopened.dispose();
    expect(() => providers.switchVoice('llm', true), throwsArgumentError);
    expect(() => providers.selectLanguage('edge'), throwsArgumentError);
  });

  test('settings and keys saved before engines carry over', () async {
    await store.put('settings', 'providers', {
      'baseUrl': 'https://old.test/v1',
      'protocol': 'responses',
      'profileModel': 'old-model',
      'directorModel': '',
      'region': 'singapore',
      'minimaxOn': false,
      'bailianOn': true,
      'edgeOn': true,
    });
    secrets.values.addAll({'llm': 'old-llm', 'minimax': 'old-minimax'});
    final migrated = await ProviderStore.open(store, secrets);
    addTearDown(migrated.dispose);
    final llm = migrated.value.engine('llm')!;
    expect(llm.ready, isTrue);
    expect(llm.value('api'), 'responses');
    expect(llm.value('baseUrl'), 'https://old.test/v1');
    expect(migrated.value.engine('bailian')!.value('region'), 'singapore');
    expect(migrated.value.engine('minimax')!.ready, isTrue);
    expect(migrated.value.voiceProviders, {'edge'});
    final config = await migrated.configuration();
    expect(config.value('llm', 'key'), 'old-llm');
    expect(config.value('minimax', 'key'), 'old-minimax');
    // Deleting a key removes the copy stored under the old name too.
    await migrated.configure('minimax', secrets: {'key': ''});
    expect(migrated.value.engine('minimax')!.ready, isFalse);
    expect(secrets.values.containsKey('minimax'), isFalse);
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
