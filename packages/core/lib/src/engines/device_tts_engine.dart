import '../models/voice.dart';
import '../preset_catalog.dart';
import '../provider_configuration.dart';
import '../providers/provider_exception.dart';
import '../providers/tts_adapter.dart';
import '../providers/usage_ledger.dart';
import 'engine.dart';
import 'tts_engine.dart';

/// Marks where a speech model running on the reader's device plugs in.
///
/// It is listed as unavailable and never synthesizes. A real device engine
/// implements [TtsEngine] in the app package, next to its native runtime:
/// [EngineLocality.device], no [endpoint] (so no consent is asked and no
/// key is needed), [EngineReadiness.notInstalled] until its model is on the
/// device, its reference voices as [presets], and what its model can
/// perform as [capabilitiesFor].
class PlannedDeviceTtsEngine implements TtsEngine {
  const PlannedDeviceTtsEngine({this.id = 'device'});

  @override
  final String id;
  @override
  EngineLocality get locality => EngineLocality.device;
  @override
  int get requestsPerMinute => 60000;
  @override
  List<EngineField> get fields => const [];
  @override
  EngineReadiness readiness(ProviderConfiguration config) =>
      EngineReadiness.unavailable;
  @override
  Uri? endpoint(ProviderConfiguration config) => null;
  @override
  List<VoicePreset> presets(ProviderConfiguration config) => const [];
  @override
  TtsCapabilities capabilitiesFor(
    VoiceBinding binding,
    ProviderConfiguration config,
  ) => throw _unavailable;
  @override
  String? designModel(ProviderConfiguration config) => null;
  @override
  OpenedTts open(ProviderConfiguration config, {UsageLedger? usageLedger}) =>
      throw _unavailable;

  ProviderException get _unavailable => ProviderException(
    provider: id,
    kind: ProviderErrorKind.invalidConfiguration,
    code: 'engineUnavailable',
  );
}
