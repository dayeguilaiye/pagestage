import '../models/script.dart';
import '../models/cast.dart';
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
    this.emotion,
    this.instruction,
    this.pronunciations = const [],
  });
  final String text;
  final String language;
  final VoiceBinding binding;
  final Direction direction;
  final String? emotion;
  final String? instruction;
  final List<PronunciationEntry> pronunciations;

  factory TtsRequest.forCapabilities({
    required String text,
    required String language,
    required VoiceBinding binding,
    required Direction direction,
    required TtsCapabilities capabilities,
    List<PronunciationEntry> pronunciations = const [],
  }) => TtsRequest(
    text: text,
    language: language,
    binding: binding,
    direction: direction,
    pronunciations: List.unmodifiable(pronunciations),
    emotion: capabilities.emotionControl == EmotionControl.enumerated
        ? direction.emotion.name
        : null,
    instruction: capabilities.emotionControl == EmotionControl.instruction
        ? _instruction(direction, language)
        : null,
  );
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

String _instruction(Direction direction, String language) {
  final note = direction.note.trim();
  if (language == 'zh') {
    const emotions = ['平静', '开心', '悲伤', '愤怒', '恐惧', '厌恶', '惊讶'];
    const intensities = ['轻', '中', '强'];
    return '以${emotions[direction.emotion.index]}的语气、'
        '强度${intensities[direction.intensity.index]}朗读。$note';
  }
  return 'Read with a ${direction.emotion.name} emotion and '
      '${direction.intensity.name} intensity.${note.isEmpty ? '' : ' $note'}';
}
