import '../delivery.dart';
import '../models/script.dart';
import '../models/cast.dart';
import '../models/voice.dart';
import '../pcm_audio.dart';

abstract interface class TtsAdapter {
  String get provider;
  TtsCapabilities capabilitiesFor(VoiceBinding binding);
  Future<TtsAudio> synthesize(TtsRequest request);
}

/// A single device operation for two separately directed requests, in input order.
abstract interface class PairedTtsAdapter implements TtsAdapter {
  Future<(TtsAudio, TtsAudio)> synthesizePair(
    TtsRequest first,
    TtsRequest second,
  );
}

class TtsRequest {
  const TtsRequest({
    required this.text,
    required this.language,
    required this.binding,
    this.delivery = const Delivery(),
    this.pronunciations = const [],
  });
  final String text;
  final String language;
  final VoiceBinding binding;

  /// Already lowered to [binding]'s capabilities; adapters only translate it.
  final Delivery delivery;
  final List<PronunciationEntry> pronunciations;
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

/// What the selected model and voice can perform through this adapter.
/// `Delivery.lower` reduces every direction to these before synthesis.
class TtsCapabilities {
  const TtsCapabilities({
    required this.supportsPronunciation,
    required this.maxCharacters,
    this.emotions = const {},
    this.intensity = false,
    this.instruction = false,
    this.cues = const {},
    this.prosody = false,
    this.pairedSynthesis = false,
  });
  final bool supportsPronunciation;

  /// Maximum source Unicode code points per request, including whitespace.
  /// An adapter may choose a conservative implementation budget.
  final int maxCharacters;

  /// Emotions the engine takes as a parameter of its own.
  final Set<Emotion> emotions;

  /// Whether an emotion's strength can be set.
  final bool intensity;

  /// Whether a free-text sentence of vocal direction is followed.
  final bool instruction;

  /// Non-verbal sounds the engine can voice inside a line.
  final Set<VocalCueKind> cues;

  /// Whether pace, loudness and pitch can be set per request.
  final bool prosody;

  final bool pairedSynthesis;
}
