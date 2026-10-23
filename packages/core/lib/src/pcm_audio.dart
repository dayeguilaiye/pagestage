import 'dart:typed_data';

/// Mono signed 16-bit PCM. WAV encoding is a transport/storage detail.
class PcmAudio {
  PcmAudio({required Int16List samples, this.sampleRate = 24000})
    : samples = Int16List.fromList(samples) {
    if (sampleRate <= 0) throw ArgumentError.value(sampleRate, 'sampleRate');
  }
  final Int16List samples;
  final int sampleRate;
  Duration get duration =>
      Duration(microseconds: samples.length * 1000000 ~/ sampleRate);

  factory PcmAudio.fromWav(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    String tag(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));
    if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') {
      throw const FormatException('Expected RIFF/WAVE audio.');
    }
    final end = data.getUint32(4, Endian.little) + 8;
    if (end > bytes.length || end < 12) {
      throw const FormatException('Truncated WAV audio.');
    }
    int? sampleRate;
    Uint8List? pcm;
    for (var offset = 12; offset + 8 <= end;) {
      final size = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (start + size > end) {
        throw const FormatException('Truncated WAV chunk.');
      }
      if (tag(offset) == 'fmt ') {
        if (size < 16 ||
            data.getUint16(start, Endian.little) != 1 ||
            data.getUint16(start + 2, Endian.little) != 1 ||
            data.getUint16(start + 12, Endian.little) != 2 ||
            data.getUint16(start + 14, Endian.little) != 16) {
          throw const FormatException('Expected mono 16-bit PCM audio.');
        }
        sampleRate = data.getUint32(start + 4, Endian.little);
        if (sampleRate <= 0) {
          throw const FormatException('Invalid WAV sample rate.');
        }
      } else if (tag(offset) == 'data') {
        pcm = Uint8List.sublistView(bytes, start, start + size);
      }
      offset = start + size + (size.isOdd ? 1 : 0);
    }
    if (sampleRate == null || pcm == null || pcm.length.isOdd) {
      throw const FormatException('Missing or invalid WAV audio chunks.');
    }
    final source = ByteData.sublistView(pcm);
    return PcmAudio(
      sampleRate: sampleRate,
      samples: Int16List.fromList([
        for (var i = 0; i < pcm.length; i += 2)
          source.getInt16(i, Endian.little),
      ]),
    );
  }

  Uint8List toWav() {
    final bytes = Uint8List(44 + samples.length * 2);
    final data = ByteData.sublistView(bytes);
    void tag(int offset, String value) =>
        bytes.setRange(offset, offset + value.length, value.codeUnits);
    tag(0, 'RIFF');
    data.setUint32(4, bytes.length - 8, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    data.setUint32(40, samples.length * 2, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(44 + i * 2, samples[i], Endian.little);
    }
    return bytes;
  }
}
