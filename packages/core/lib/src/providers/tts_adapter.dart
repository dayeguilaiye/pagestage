import '../models/script.dart';
import '../models/voice.dart';
import '../pcm_audio.dart';

abstract interface class TtsAdapter {
  String get provider;
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
  const TtsAudio({required this.audio, required this.characters});
  final PcmAudio audio;
  final int characters;
}
