import 'cloud_tts_engines.dart';
import 'device_tts_engine.dart';
import 'llm_engine.dart';
import 'tts_engine.dart';

/// The engines pagestage ships with. The app adds its own device engines
/// to these when it has them.
final standardTtsEngines = TtsEngines(const [
  MiniMaxEngine(),
  BailianEngine(),
  EdgeEngine(),
  PlannedDeviceTtsEngine(),
]);

final standardLlmEngines = LlmEngines(const [
  OpenAiLlmEngine(),
  DeviceLlmEngine(),
]);
