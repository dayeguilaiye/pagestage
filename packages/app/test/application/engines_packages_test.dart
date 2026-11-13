import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/cast_controller.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/application/generation_controller.dart';
import 'package:pagestage_app/application/listening_controller.dart';
import 'package:pagestage_app/application/package_controller.dart';
import 'package:pagestage_app/application/provider_store.dart';
import 'package:pagestage_app/application/voice_controller.dart';
import 'package:pagestage_core/pagestage_core.dart' hide EngineLocality;
import 'package:pagestage_core/pagestage_core.dart' as core show EngineLocality;

import '../../../core/test/support/generation_fakes.dart';
import 'support.dart';

/// A speech model on the device, registered the way the app adds one: it
/// has no key, no endpoint, and reports whether its model is installed.
class PocketEngine implements TtsEngine {
  var installed = true;
  final requests = <TtsRequest>[];

  @override
  String get id => 'pocket';
  @override
  core.EngineLocality get locality => core.EngineLocality.device;
  @override
  int get requestsPerMinute => 60000;
  @override
  List<EngineField> get fields => const [];
  @override
  EngineReadiness readiness(ProviderConfiguration config) =>
      installed ? EngineReadiness.ready : EngineReadiness.notInstalled;
  @override
  Uri? endpoint(ProviderConfiguration config) => null;
  @override
  List<VoicePreset> presets(ProviderConfiguration config) => const [
    VoicePreset(
      id: 'pocket:a',
      binding: VoiceBinding(provider: 'pocket', model: 'p1', voiceId: 'a'),
      languages: ['en', 'zh'],
      narratorCandidate: true,
    ),
    VoicePreset(
      id: 'pocket:b',
      binding: VoiceBinding(provider: 'pocket', model: 'p1', voiceId: 'b'),
      languages: ['en', 'zh'],
    ),
  ];
  @override
  TtsCapabilities capabilitiesFor(
    VoiceBinding binding,
    ProviderConfiguration config,
  ) => const TtsCapabilities(
    supportsPronunciation: false,
    maxCharacters: 500,
    emotions: {Emotion.calm, Emotion.happy, Emotion.sad},
  );
  @override
  String? designModel(ProviderConfiguration config) => null;
  @override
  OpenedTts open(ProviderConfiguration config, {UsageLedger? usageLedger}) =>
      (adapter: _PocketAdapter(this), close: () {});
}

class _PocketAdapter implements TtsAdapter {
  _PocketAdapter(this.engine);
  final PocketEngine engine;
  @override
  String get provider => engine.id;
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) => engine
      .capabilitiesFor(binding, ProviderConfiguration.fromValues(const {}));
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    engine.requests.add(request);
    return TtsAudio(
      audio: PcmAudio(
        samples: Int16List.fromList(List.filled(240, 900)),
        sampleRate: 24000,
      ),
    );
  }
}

Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition never held.');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _Sharing implements FileSharing {
  final shared = <String>[];
  @override
  Future<void> share(String path) async => shared.add(path);
}

void main() {
  late Directory root;
  late LocalStore store;
  late Book book;
  late PocketEngine pocket;
  late ProviderStore providers;
  late ConsentBroker consents;
  late ListeningController listening;
  late CastController casts;
  late GenerationController generation;
  late VoiceController voices;
  final asked = <ConsentRequest>[];

  Future<void> voiced(int through) async {
    await casts.profile(book.id, through: 2);
    await casts.idle;
    await generation.prepare(book.id, first: 1, through: through);
    await casts.idle;
  }

  Future<bool> complete(int chapter) async => AudioRepository(
    store,
  ).isComplete((await ScriptRepository(store).get(book.id, chapter))!);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('engines-app-');
    store = LocalStore('${root.path}/db.sqlite');
    book = await importBook(store, root);
    pocket = PocketEngine();
    providers = await ProviderStore.open(
      store,
      MemorySecrets(),
      engines: AppEngines(voice: TtsEngines([pocket])),
    );
    await providers.configure(
      'llm',
      values: {'baseUrl': 'https://offline.test/v1', 'profileModel': 'fake'},
      secrets: {'key': 'fake'},
    );
    await providers.switchVoice('pocket', true);
    consents = ConsentBroker(store);
    asked.clear();
    consents.addListener(() {
      if (consents.value case final request?) {
        asked.add(request);
        consents.respond(request.id, accepted: true);
      }
    });
    listening = ListeningController(
      store: store,
      engine: MemoryEngine(),
      speech: MemorySpeech(),
    );
    // Only the language model is replaced; the device engine is opened
    // through the registry like any other.
    casts = await CastController.open(
      store: store,
      providers: providers,
      consents: consents,
      listening: listening,
      auditionEngine: MemoryEngine(),
      profileFactory: (_) => GenerationLlm(),
      directorFactory: (_) => GenerationLlm(),
    );
    generation = await GenerationController.open(store, casts.scheduler);
    listening.attachGeneration(generation);
    voices = await VoiceController.open(store, casts, listening);
  });
  tearDown(() async {
    await listening.pause();
    await consents.close();
    await voices.close();
    await casts.idle;
    await listening.close();
    await generation.close();
    await casts.close();
    providers.dispose();
    await store.close();
    await root.delete(recursive: true);
  });

  test(
    'a device engine is cast and speaks with no key and no asking',
    () async {
      final view = providers.value.engine('pocket')!;
      expect(view.site, EngineSite.device);
      expect(view.settings, isEmpty);
      expect(view.traits, {EngineTrait.emotion});
      expect(providers.value.voiceProviders, {'pocket'});

      await voiced(1);
      expect((await casts.load(book.id)).members.single.provider, 'pocket');
      expect(await complete(1), isTrue);
      expect(pocket.requests, isNotEmpty);
      // Only the cloud language model was asked about; the device engine
      // sends the text nowhere.
      expect(asked.map((r) => r.provider).toSet(), {'llm'});
      expect(
        (await voices.presets(book.id, 'narrator')).map((v) => v.provider),
        everyElement('pocket'),
      );
      expect(await voices.designProviders(book.id), isEmpty);
    },
  );

  test('an engine whose model is missing is never called and says '
      'why', () async {
    await casts.profile(book.id, through: 2);
    await casts.idle;
    pocket.installed = false;
    await providers.switchVoice('pocket', true);
    expect(providers.value.engine('pocket')!.status, EngineStatus.notInstalled);
    expect(providers.value.voiceProviders, isEmpty);

    await generation.prepare(book.id, first: 1, through: 1);
    await casts.idle;
    await _eventually(() => generation.value.failures.isNotEmpty);
    expect(pocket.requests, isEmpty);
    final failure = generation.value.failures.single;
    expect(failure.provider, 'pocket');
    expect(failure.reason, 'engineNotInstalled');
  });

  test('expressiveness is kept per book; unchanged deliveries are not '
      'voiced again', () async {
    await voiced(1);
    final requests = pocket.requests.length;
    expect(
      await generation.expressiveness(book.id),
      BookExpressiveness.natural,
    );

    await generation.setExpressiveness(book.id, BookExpressiveness.plain);
    expect(await generation.expressiveness(book.id), BookExpressiveness.plain);
    // The mode is untouched, and the chapter waits to be voiced again.
    expect(await generation.mode(book.id), BookPerformanceMode.audiobook);
    expect(await complete(1), isFalse);

    await generation.prepare(book.id, first: 1, through: 1);
    await casts.idle;
    expect(await complete(1), isTrue);
    // Calm lines read the same either way, so every line came from the
    // cache.
    expect(pocket.requests, hasLength(requests));
  });

  test('a book is packed into one file and handed to the share '
      'sheet', () async {
    await voiced(1);
    final sharing = _Sharing();
    final packages = PackageController(
      store,
      directory: Directory('${root.path}/exports'),
      sharing: sharing,
    );
    final contents = await packages.contents(book.id);
    expect(contents.scriptChapters, 1);
    expect(contents.audioChapters, 1);

    await packages.share(book.id, audio: true);
    final audio = File(sharing.shared.single);
    expect(audio.path, endsWith('/exports/en.audio.pagestage'));
    final summary = await BookPackages(store).inspect(audio.path);
    expect(summary.kind, BookPackageKind.audio);
    expect(summary.audioChapters, [1]);

    // Only the latest export is kept.
    await packages.share(book.id, audio: false);
    expect(sharing.shared.last, endsWith('/exports/en.script.pagestage'));
    expect(await audio.exists(), isFalse);
    expect(
      (await BookPackages(store).inspect(sharing.shared.last)).audioChapters,
      isEmpty,
    );
  });

  test('giving a line to another speaker voices only that line '
      'again', () async {
    await voiced(1);
    final cast = await CastRepository(store).get(book.id);
    await CastRepository(store).save(
      cast.copyWith(
        speakers: [
          ...cast.speakers,
          Speaker(id: 'hero', name: 'Hero', chapters: [1]),
        ],
      ),
    );
    final library = Library(store)
      ..editBook = (bookId, action) async {
        await listening.invalidate(bookId);
        await casts.scheduler.withBookPaused(bookId, () async {
          await casts.scheduler.cancelGeneration(bookId);
          await action();
        });
      };
    final scripts = ScriptController(
      store,
      library,
      revoice: (bookId, chapter) =>
          generation.prepare(bookId, first: chapter, through: chapter),
    );
    expect(await scripts.hasImportedAudio(book.id, 1), isFalse);
    final requests = pocket.requests.length;

    await scripts.reassign(book.id, 1, 0, 'hero');
    await casts.idle;
    final script = (await ScriptRepository(store).get(book.id, 1))!;
    expect(script.lines.first.direction.speakerId, 'hero');
    expect(await complete(1), isTrue);
    expect(pocket.requests, hasLength(requests + 1));
    expect(
      pocket.requests.last.text,
      script.lines.first.textIn(book.chapter(1).text),
    );
    // The reader sees who speaks each line.
    final lines = await listening.lines(book.id, 1);
    expect(lines.first.speakerId, 'hero');
    expect(lines.first.directed, isTrue);
  });
}
