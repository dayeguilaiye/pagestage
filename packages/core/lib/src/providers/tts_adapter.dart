import '../models/script.dart';
import '../models/voice.dart';
import '../pcm_audio.dart';

abstract interface class TtsAdapter {
  String get provider;
  TtsCapabilities capabilitiesFor(VoiceBinding binding);
  Future<TtsAudio> synthesize(TtsRequest request);
}

class TtsRequest {
  const TtsRequest({
    required this.text,
    required this.language,
    required this.binding,
    required this.direction,
  });
  final String text;
  final String language;
  final VoiceBinding binding;
  final Direction direction;
}

class TtsAudio {
  const TtsAudio({
    required this.audio,
    this.characters,
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
  });
  final PcmAudio audio;
  final int? characters;
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;
}

enum EmotionControl { none, enumerated, instruction }

/// Capabilities of the selected model/voice and this adapter's transport mode.
class TtsCapabilities {
  const TtsCapabilities({
    required this.supportsVoiceDesign,
    required this.emotionControl,
    required this.supportsPronunciation,
    required this.returnsTimestamps,
    required this.maxCharacters,
  });
  final bool supportsVoiceDesign;
  final EmotionControl emotionControl;
  final bool supportsPronunciation;
  final bool returnsTimestamps;

  /// Maximum source Unicode code points per request, including whitespace.
  /// An adapter may choose a conservative implementation budget.
  final int maxCharacters;
}
