import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

ProviderConfiguration _config([
  Map<String, Map<String, String>> sections = const {},
]) => ProviderConfiguration.fromValues(sections);

/// A speech model running on the device, as an app would add one.
class _DeviceEngine implements TtsEngine {
  final installed = true;
  final requests = <TtsRequest>[];
  var closed = 0;

  @override
  String get id => 'pocket';
  @override
  EngineLocality get locality => EngineLocality.device;
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
      id: 'pocket:reference-a',
      binding: VoiceBinding(
        provider: 'pocket',
        model: 'pocket-1',
        voiceId: 'reference-a',
      ),
      languages: ['zh', 'en'],
      narratorCandidate: true,
    ),
  ];
  @override
  TtsCapabilities capabilitiesFor(
    VoiceBinding binding,
    ProviderConfiguration config,
  ) => const TtsCapabilities(
    supportsPronunciation: false,
    maxCharacters: 200,
    emotions: {Emotion.calm, Emotion.happy, Emotion.sad},
  );
  @override
  String? designModel(ProviderConfiguration config) => null;
  @override
  OpenedTts open(ProviderConfiguration config, {UsageLedger? usageLedger}) =>
      (adapter: _DeviceAdapter(this), close: () => closed++);
}

class _DeviceAdapter implements TtsAdapter {
  _DeviceAdapter(this.engine);
  final _DeviceEngine engine;
  @override
  String get provider => engine.id;
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) =>
      engine.capabilitiesFor(binding, _config());
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    engine.requests.add(request);
    return TtsAudio(audio: PcmAudio(samples: Int16List.fromList([1, 2])));
  }
}

class _Runtime implements LocalLlmRuntime {
  _Runtime(this.installed);
  @override
  final bool installed;
  @override
  String get model => 'pocket-llm';
  @override
  Future<Uri> start() async => Uri.parse('http://127.0.0.1:9/v1');
}

void main() {
  group('voice engines', () {
    test('the standard registry describes what each engine needs', () {
      final engines = standardTtsEngines;
      expect(engines.ids, ['minimax', 'bailian', 'edge', 'device']);
      expect(
        engines.require('minimax').readiness(_config()),
        EngineReadiness.needsSetup,
      );
      expect(
        engines
            .require('minimax')
            .readiness(
              _config({
                'minimax': {'key': 'k'},
              }),
            ),
        EngineReadiness.ready,
      );
      // Edge asks for nothing; the device slot is not offered yet.
      expect(
        engines.require('edge').readiness(_config()),
        EngineReadiness.ready,
      );
      expect(
        engines.require('device').readiness(_config()),
        EngineReadiness.unavailable,
      );
      expect(engines.require('device').endpoint(_config()), isNull);
      expect(
        engines
            .require('bailian')
            .endpoint(
              _config({
                'bailian': {'region': 'singapore'},
              }),
            ),
        Uri.parse('https://dashscope-intl.aliyuncs.com/api/v1'),
      );
    });

    test('an engine offers the presets of its own configuration', () {
      final bailian = standardTtsEngines.require('bailian');
      final beijing = bailian.presets(_config());
      final singapore = bailian.presets(
        _config({
          'bailian': {'region': 'singapore'},
        }),
      );
      expect(beijing, isNotEmpty);
      expect(beijing.every((p) => p.regions.contains('beijing')), isTrue);
      expect(singapore.every((p) => p.regions.contains('singapore')), isTrue);
      // Only Beijing designs voices.
      expect(bailian.designModel(_config()), isNotNull);
      expect(
        bailian.designModel(
          _config({
            'bailian': {'region': 'singapore'},
          }),
        ),
        isNull,
      );
      final catalog = standardTtsEngines.catalog(_config(), only: {'edge'});
      expect(catalog, isNotEmpty);
      expect(catalog.every((p) => p.binding.provider == 'edge'), isTrue);
    });

    test('capabilities are known without a key', () {
      final capabilities = standardTtsEngines
          .require('minimax')
          .capabilitiesFor(
            const VoiceBinding(
              provider: 'minimax',
              model: 'speech-2.8-hd',
              voiceId: 'v',
            ),
            _config(),
          );
      expect(capabilities.emotions, Emotion.values.toSet());
      expect(capabilities.cues, contains(VocalCueKind.sigh));
    });

    test('a session opens any registered engine, and closes it', () async {
      final device = _DeviceEngine();
      final engines = TtsEngines([...standardTtsEngines.all, device]);
      final session = TtsProviderSession.open(
        _config(),
        providers: ['pocket'],
        engines: engines,
      );
      const binding = VoiceBinding(
        provider: 'pocket',
        model: 'pocket-1',
        voiceId: 'reference-a',
      );
      await session.adapters['pocket']!.synthesize(
        const TtsRequest(text: 'Hi.', language: 'en', binding: binding),
      );
      expect(device.requests.single.text, 'Hi.');
      session.close();
      expect(device.closed, 1);
      // A cloud engine without its key cannot open.
      expect(
        () => TtsProviderSession.open(_config(), providers: ['minimax']),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.kind,
            'kind',
            ProviderErrorKind.invalidConfiguration,
          ),
        ),
      );
      expect(
        () => TtsProviderSession.open(_config(), providers: ['unknown']),
        throwsA(isA<ProviderException>()),
      );
    });
  });

  group('language engines', () {
    test('the configuration selects the engine in use', () {
      final cloud = _config({
        'llm': {'key': 'k', 'profileModel': 'm'},
      });
      expect(standardLlmEngines.active(cloud).id, 'llm');
      expect(
        standardLlmEngines.active(cloud).readiness(cloud),
        EngineReadiness.ready,
      );
      expect(
        standardLlmEngines.active(_config()).readiness(_config()),
        EngineReadiness.needsSetup,
      );
      final device = _config({
        'llm': {'engine': 'llm-device'},
      });
      expect(standardLlmEngines.active(device).id, 'llm-device');
      expect(
        standardLlmEngines.active(device).readiness(device),
        EngineReadiness.unavailable,
      );
      expect(
        () => standardLlmEngines.active(
          _config({
            'llm': {'engine': 'nowhere'},
          }),
        ),
        throwsA(isA<ProviderException>()),
      );
    });

    test('a device engine follows its runtime and sends text nowhere', () {
      const none = DeviceLlmEngine();
      expect(
        () => none.open(_config(), LlmRole.director),
        throwsA(isA<ProviderException>()),
      );
      final missing = DeviceLlmEngine(runtime: _Runtime(false));
      expect(missing.readiness(_config()), EngineReadiness.notInstalled);
      final ready = DeviceLlmEngine(runtime: _Runtime(true));
      expect(ready.readiness(_config()), EngineReadiness.ready);
      expect(ready.endpoint(_config()), isNull);
      expect(ready.model(_config(), LlmRole.profile), 'pocket-llm');
      expect(ready.open(_config(), LlmRole.profile).model, 'pocket-llm');
    });
  });
}
