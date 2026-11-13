import '../provider_configuration.dart';
import '../providers/llm_adapter.dart';
import '../providers/llm_settings.dart';
import '../providers/provider_exception.dart';
import '../providers/request_recovery.dart';
import '../providers/usage_ledger.dart';
import 'engine.dart';

/// The two jobs a language model does for a book.
enum LlmRole { profile, director }

/// A language engine. Every engine speaks the same OpenAI-compatible
/// protocols, so they differ only in where they run and what they need.
abstract interface class LlmEngine implements Engine {
  /// The model [role] will use, for provenance; empty while unset.
  String model(ProviderConfiguration config, LlmRole role);

  /// Opens an adapter for [role]. Errors report the provider `llm`
  /// whichever engine raised them.
  LlmAdapter open(
    ProviderConfiguration config,
    LlmRole role, {
    UsageLedger? usageLedger,
    RequestRuntime? runtime,
  });
}

/// Releases what [adapter] holds once its operation is over.
void closeLlm(LlmAdapter adapter) {
  if (adapter is OpenAiLlmAdapter) adapter.close();
}

/// The language engines known to one build and which of them is in use.
class LlmEngines {
  LlmEngines(Iterable<LlmEngine> engines)
    : _engines = {for (final engine in engines) engine.id: engine};
  final Map<String, LlmEngine> _engines;

  Iterable<LlmEngine> get all => _engines.values;
  LlmEngine? operator [](String id) => _engines[id];

  /// The engine the configuration selects: `llm.engine`, or the first.
  LlmEngine active(ProviderConfiguration config) {
    final id = config.value('llm', 'engine', environmentVariable: 'LLM_ENGINE');
    final engine = id == null ? _engines.values.firstOrNull : _engines[id];
    if (engine == null) {
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    return engine;
  }
}

/// A cloud endpoint the reader configures: base URL, protocol, key and a
/// model for each role.
class OpenAiLlmEngine implements LlmEngine {
  const OpenAiLlmEngine();

  @override
  String get id => 'llm';
  @override
  EngineLocality get locality => EngineLocality.cloud;
  @override
  List<EngineField> get fields => const [
    EngineField.text(
      'baseUrl',
      environmentVariable: 'LLM_BASE_URL',
      fallback: 'https://api.openai.com/v1',
    ),
    EngineField.choice(
      'api',
      ['chat-completions', 'responses'],
      environmentVariable: 'LLM_API',
      fallback: 'chat-completions',
    ),
    EngineField.secret('key', environmentVariable: 'LLM_KEY'),
    EngineField.text(
      'profileModel',
      environmentVariable: 'LLM_PROFILE_MODEL',
      required: true,
    ),
    EngineField.text(
      'directorModel',
      environmentVariable: 'LLM_DIRECTOR_MODEL',
    ),
  ];

  @override
  EngineReadiness readiness(ProviderConfiguration config) {
    try {
      LlmSettings.fromConfiguration(config);
      return EngineReadiness.ready;
    } on ProviderException {
      return EngineReadiness.needsSetup;
    }
  }

  @override
  Uri? endpoint(ProviderConfiguration config) =>
      LlmSettings.fromConfiguration(config).baseUrl;

  @override
  String model(ProviderConfiguration config, LlmRole role) {
    try {
      final settings = LlmSettings.fromConfiguration(config);
      return role == LlmRole.profile
          ? settings.profileModel
          : settings.directorModel;
    } on ProviderException {
      return '';
    }
  }

  @override
  LlmAdapter open(
    ProviderConfiguration config,
    LlmRole role, {
    UsageLedger? usageLedger,
    RequestRuntime? runtime,
  }) {
    final settings = LlmSettings.fromConfiguration(config);
    return role == LlmRole.profile
        ? settings.createProfileAdapter(
            usageLedger: usageLedger,
            runtime: runtime,
          )
        : settings.createDirectorAdapter(
            usageLedger: usageLedger,
            runtime: runtime,
          );
  }
}

/// What runs a language model on the device. Native inference lives in the
/// app package; it serves the same OpenAI-compatible protocol on a loopback
/// address, so nothing else about directing changes.
abstract interface class LocalLlmRuntime {
  /// Whether the model's files are on this device.
  bool get installed;

  /// The model's name, recorded as each script's provenance.
  String get model;

  /// Loads the model if needed and returns the loopback base URL serving it.
  Future<Uri> start();
}

/// A language model running on the reader's device. Without a [runtime] it
/// is listed as unavailable, marking where one plugs in.
class DeviceLlmEngine implements LlmEngine {
  const DeviceLlmEngine({this.runtime});
  final LocalLlmRuntime? runtime;

  @override
  String get id => 'llm-device';
  @override
  EngineLocality get locality => EngineLocality.device;
  @override
  List<EngineField> get fields => const [];
  @override
  EngineReadiness readiness(ProviderConfiguration config) => runtime == null
      ? EngineReadiness.unavailable
      : runtime!.installed
      ? EngineReadiness.ready
      : EngineReadiness.notInstalled;
  @override
  Uri? endpoint(ProviderConfiguration config) => null;
  @override
  String model(ProviderConfiguration config, LlmRole role) =>
      runtime?.model ?? '';

  @override
  LlmAdapter open(
    ProviderConfiguration config,
    LlmRole role, {
    UsageLedger? usageLedger,
    RequestRuntime? runtime,
  }) {
    final local = this.runtime;
    if (local == null || !local.installed) {
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidConfiguration,
        code: 'engineUnavailable',
      );
    }
    return _DeviceLlm(local, runtime);
  }
}

class _DeviceLlm implements LlmAdapter {
  _DeviceLlm(this.local, this.runtime);
  final LocalLlmRuntime local;
  final RequestRuntime? runtime;
  @override
  String get model => local.model;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final adapter = OpenAiLlmAdapter(
      baseUrl: await local.start(),
      // The loopback server asks for no credential.
      apiKey: 'device',
      model: local.model,
      runtime: runtime,
    );
    try {
      return await adapter.complete(request);
    } finally {
      adapter.close();
    }
  }
}
