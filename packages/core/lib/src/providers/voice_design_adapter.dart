import 'dart:typed_data';

import '../models/voice.dart';
import '../pcm_audio.dart';

/// Optional TTS provider capability. Providers without design need only TtsAdapter.
abstract interface class VoiceDesignAdapter {
  /// Validates the model, region and endpoint before sending a design request.
  Future<DesignedVoice> design(VoiceDesignRequest request);
}

class VoiceDesignRequest {
  const VoiceDesignRequest({
    required this.description,
    required this.previewText,
    required this.language,
    required this.model,
  });
  final String description;
  final String previewText;
  final String language;
  final String model;
}

class DesignedVoice {
  const DesignedVoice({required this.binding, required this.preview});
  final VoiceBinding binding;
  final VoicePreview preview;
}

/// Encoded preview bytes retain their actual container; they are never raw PCM.
class VoicePreview {
  VoicePreview._(this.bytes, this.extension);
  final Uint8List bytes;
  final String extension;

  factory VoicePreview.detect(Uint8List bytes) {
    bool magic(List<int> values, [int offset = 0]) =>
        bytes.length >= offset + values.length &&
        List.generate(
          values.length,
          (i) => bytes[offset + i] == values[i],
        ).every((v) => v);
    if (magic([82, 73, 70, 70]) && magic([87, 65, 86, 69], 8)) {
      if (PcmAudio.fromWav(bytes).samples.isEmpty) {
        throw const FormatException('Empty preview audio.');
      }
      return VoicePreview._(bytes, 'wav');
    }
    final id3 = magic([73, 68, 51]) && bytes.length > 10;
    // MPEG audio frame sync, valid layer and bitrate (excludes ADTS AAC).
    final mpeg =
        bytes.length >= 4 &&
        bytes[0] == 255 &&
        bytes[1] & 0xe0 == 0xe0 &&
        bytes[1] & 0x06 != 0 &&
        bytes[2] & 0xf0 != 0 &&
        bytes[2] & 0xf0 != 0xf0;
    if (id3 || mpeg) return VoicePreview._(bytes, 'mp3');
    throw const FormatException('Unsupported preview audio container.');
  }
}
