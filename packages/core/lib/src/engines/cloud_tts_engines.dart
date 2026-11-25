import '../models/voice.dart';
import '../preset_catalog.dart';
import '../provider_configuration.dart';
import '../providers/bailian_tts_adapter.dart';
import '../providers/edge_tts_adapter.dart';
import '../providers/minimax_tts_adapter.dart';
import '../providers/provider_exception.dart';
import '../providers/tts_adapter.dart';
import '../providers/usage_ledger.dart';
import 'engine.dart';
import 'tts_engine.dart';

List<VoicePreset> _presetsOf(String provider) => [
  for (final preset in defaultVoiceCatalog)
    if (preset.binding.provider == provider) preset,
];

Never _invalid(String provider) => throw ProviderException(
  provider: provider,
  kind: ProviderErrorKind.invalidConfiguration,
);

/// A configured base URL, the engine's default, or an invalid configuration.
Uri _baseUrl(ProviderConfiguration config, Engine engine, String fallback) {
  final url = Uri.tryParse(engineValue(config, engine, 'baseUrl') ?? fallback);
  if (url == null) _invalid(engine.id);
  return url;
}

class MiniMaxEngine implements TtsEngine {
  const MiniMaxEngine();
  static const _endpoint = 'https://api.minimax.io/v1';

  /// Keys from MiniMax's mainland platform (minimaxi.com) only work there.
  static const _chinaEndpoint = 'https://api.minimaxi.com/v1';

  /// The address for the account's region unless a base URL is set.
  static String _regional(ProviderConfiguration config, TtsEngine engine) =>
      engineValue(config, engine, 'region') == 'china'
      ? _chinaEndpoint
      : _endpoint;

  @override
  String get id => 'minimax';
  @override
  EngineLocality get locality => EngineLocality.cloud;
  @override
  int get requestsPerMinute => 12;
  @override
  List<EngineField> get fields => const [
    EngineField.choice(
      'region',
      ['global', 'china'],
      environmentVariable: 'MINIMAX_REGION',
      fallback: 'global',
    ),
    EngineField.secret('key', environmentVariable: 'MINIMAX_API_KEY'),
    EngineField.text(
      'baseUrl',
      environmentVariable: 'MINIMAX_BASE_URL',
      advanced: true,
    ),
    EngineField.text(
      'model',
      environmentVariable: 'MINIMAX_MODEL',
      fallback: 'speech-2.8-hd',
      advanced: true,
    ),
  ];
  @override
  EngineReadiness readiness(ProviderConfiguration config) =>
      fieldsReadiness(config, this);
  @override
  Uri? endpoint(ProviderConfiguration config) =>
      _baseUrl(config, this, _regional(config, this));
  @override
  List<VoicePreset> presets(ProviderConfiguration config) => _presetsOf(id);
  @override
  TtsCapabilities capabilitiesFor(
    VoiceBinding binding,
    ProviderConfiguration config,
  ) => MiniMaxTtsAdapter.capabilities(binding);
  @override
  String? designModel(ProviderConfiguration config) =>
      engineValue(config, this, 'model');

  @override
  OpenedTts open(ProviderConfiguration config, {UsageLedger? usageLedger}) {
    final key = engineValue(config, this, 'key');
    if (key == null) _invalid(id);
    final adapter = MiniMaxTtsAdapter(
      apiKey: key,
      baseUrl: _baseUrl(config, this, _regional(config, this)),
      usageLedger: usageLedger,
    );
    return (adapter: adapter, close: adapter.close);
  }
}

class BailianEngine implements TtsEngine {
  const BailianEngine();

  @override
  String get id => 'bailian';
  @override
  EngineLocality get locality => EngineLocality.cloud;
  @override
  int get requestsPerMinute => 60;
  @override
  List<EngineField> get fields => const [
    EngineField.choice(
      'region',
      ['beijing', 'singapore'],
      environmentVariable: 'BAILIAN_REGION',
      fallback: 'beijing',
    ),
    EngineField.secret('key', environmentVariable: 'BAILIAN_API_KEY'),
    EngineField.text(
      'baseUrl',
      environmentVariable: 'BAILIAN_BASE_URL',
      advanced: true,
    ),
    EngineField.text(
      'model',
      environmentVariable: 'BAILIAN_MODEL',
      fallback: BailianTtsAdapter.defaultModel,
      advanced: true,
    ),
  ];

  BailianRegion _region(ProviderConfiguration config) {
    final name = engineValue(config, this, 'region');
    return BailianRegion.values.where((r) => r.name == name).firstOrNull ??
        _invalid(id);
  }

  Uri? _custom(ProviderConfiguration config) {
    final value = engineValue(config, this, 'baseUrl');
    if (value == null) return null;
    return Uri.tryParse(value) ?? _invalid(id);
  }

  @override
  EngineReadiness readiness(ProviderConfiguration config) =>
      fieldsReadiness(config, this);
  @override
  Uri? endpoint(ProviderConfiguration config) =>
      _custom(config) ??
      Uri.parse(
        _region(config) == BailianRegion.beijing
            ? 'https://dashscope.aliyuncs.com/api/v1'
            : 'https://dashscope-intl.aliyuncs.com/api/v1',
      );
  @override
  List<VoicePreset> presets(ProviderConfiguration config) {
    final region = _region(config).name;
    return [
      for (final preset in _presetsOf(id))
        if (preset.regions.contains(region)) preset,
    ];
  }

  @override
  TtsCapabilities capabilitiesFor(
    VoiceBinding binding,
    ProviderConfiguration config,
  ) => BailianTtsAdapter.capabilities(
    binding,
    region: _region(config),
    baseUrl: _custom(config),
  );
  @override
  String? designModel(ProviderConfiguration config) =>
      BailianTtsAdapter.designsVoices(_region(config), _custom(config))
      ? engineValue(config, this, 'model')
      : null;

  @override
  OpenedTts open(ProviderConfiguration config, {UsageLedger? usageLedger}) {
    final key = engineValue(config, this, 'key');
    if (key == null) _invalid(id);
    final adapter = BailianTtsAdapter(
      apiKey: key,
      baseUrl: _custom(config),
      region: _region(config),
      usageLedger: usageLedger,
    );
    return (adapter: adapter, close: adapter.close);
  }
}

/// Microsoft Edge Read Aloud: free, and needs no key.
class EdgeEngine implements TtsEngine {
  const EdgeEngine();

  @override
  String get id => 'edge';
  @override
  EngineLocality get locality => EngineLocality.cloud;
  @override
  int get requestsPerMinute => 60;
  @override
  List<EngineField> get fields => const [
    EngineField.text(
      'baseUrl',
      environmentVariable: 'EDGE_BASE_URL',
      fallback: EdgeTtsAdapter.defaultEndpoint,
      advanced: true,
    ),
  ];
  @override
  EngineReadiness readiness(ProviderConfiguration config) =>
      EngineReadiness.ready;
  @override
  Uri? endpoint(ProviderConfiguration config) =>
      _baseUrl(config, this, EdgeTtsAdapter.defaultEndpoint);
  @override
  List<VoicePreset> presets(ProviderConfiguration config) => _presetsOf(id);
  @override
  TtsCapabilities capabilitiesFor(
    VoiceBinding binding,
    ProviderConfiguration config,
  ) => EdgeTtsAdapter.capabilities(binding);
  @override
  String? designModel(ProviderConfiguration config) => null;

  @override
  OpenedTts open(ProviderConfiguration config, {UsageLedger? usageLedger}) {
    final adapter = EdgeTtsAdapter(
      endpoint: _baseUrl(config, this, EdgeTtsAdapter.defaultEndpoint),
      usageLedger: usageLedger,
    );
    return (adapter: adapter, close: adapter.close);
  }
}
