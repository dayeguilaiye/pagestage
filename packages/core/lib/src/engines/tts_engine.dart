import '../models/voice.dart';
import '../preset_catalog.dart';
import '../provider_configuration.dart';
import '../providers/provider_exception.dart';
import '../providers/tts_adapter.dart';
import '../providers/usage_ledger.dart';
import 'engine.dart';

/// An adapter opened for one operation, and how to release it.
typedef OpenedTts = ({TtsAdapter adapter, void Function() close});

/// A voice engine: everything the rest of pagestage needs to know about one
/// way of turning lines into audio. Its [id] is recorded as
/// [VoiceBinding.provider]. Adding an engine means implementing this and
/// listing it in a [TtsEngines] registry; casting, synthesis, settings and
/// consent find it there.
abstract interface class TtsEngine implements Engine {
  /// The pace requests start at, unless the configuration sets another.
  int get requestsPerMinute;

  /// The voices offered under [config], such as those of its region.
  List<VoicePreset> presets(ProviderConfiguration config);

  /// What [binding] can perform. Local and free of credentials, so screens
  /// and the synthesizer may ask before anything is sent.
  TtsCapabilities capabilitiesFor(
    VoiceBinding binding,
    ProviderConfiguration config,
  );

  /// The model new voices are designed for from a description; null when
  /// the engine, or its configuration, cannot design voices.
  String? designModel(ProviderConfiguration config);

  /// Opens an adapter with [config]'s credentials. Throws a
  /// [ProviderException] of kind invalidConfiguration when it is not ready.
  OpenedTts open(ProviderConfiguration config, {UsageLedger? usageLedger});
}

/// The voice engines known to one build, in the order screens list them.
class TtsEngines {
  TtsEngines(Iterable<TtsEngine> engines)
    : _engines = {for (final engine in engines) engine.id: engine};
  final Map<String, TtsEngine> _engines;

  Iterable<TtsEngine> get all => _engines.values;
  Iterable<String> get ids => _engines.keys;
  TtsEngine? operator [](String id) => _engines[id];

  TtsEngine require(String id) =>
      _engines[id] ??
      (throw ProviderException(
        provider: id,
        kind: ProviderErrorKind.invalidConfiguration,
      ));

  /// Every preset offered under [config] by the engines in [only], or by
  /// all of them.
  List<VoicePreset> catalog(
    ProviderConfiguration config, {
    Iterable<String>? only,
  }) => [
    for (final engine in all)
      if (only == null || only.contains(engine.id)) ...engine.presets(config),
  ];
}
