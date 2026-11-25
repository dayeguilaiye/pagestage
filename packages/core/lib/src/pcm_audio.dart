import 'dart:math' as math;
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
    // Streamed WAV files (e.g. Bailian results) declare placeholder sizes
    // near 2^31 or 2^32; such a chunk runs to the end of the file.
    bool placeholder(int size) => size >= 0x7FFF0000;
    final declared = data.getUint32(4, Endian.little);
    final end = placeholder(declared) ? bytes.length : declared + 8;
    if (end > bytes.length || end < 12) {
      throw const FormatException('Truncated WAV audio.');
    }
    int? sampleRate;
    Uint8List? pcm;
    for (var offset = 12; offset + 8 <= end;) {
      var size = data.getUint32(offset + 4, Endian.little);
      final start = offset + 8;
      if (tag(offset) == 'data' && placeholder(size)) {
        size = (end - start) & ~1;
      }
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

  /// Converts the chapter mix to a common clock. Original voice clips keep
  /// their native sampling rate for replay and cache reuse.
  PcmAudio atSampleRate(int rate) {
    if (rate == sampleRate) return this;
    if (rate <= 0) throw ArgumentError.value(rate, 'rate');
    final result = Int16List((samples.length * rate / sampleRate).round());
    // Windowed-sinc interpolation with a low-pass cutoff for downsampling.
    // The polyphase table keeps the inner loop independent of transcendental math.
    const radius = 16, phases = 128;
    final cutoff = math.min(1.0, rate / sampleRate);
    final filters = List.generate(phases, (phase) {
      final coefficients = Float64List(radius * 2);
      var sum = 0.0;
      for (var i = 0; i < coefficients.length; i++) {
        final x = i - radius + 1 - phase / phases;
        final sinc = x == 0
            ? cutoff
            : math.sin(math.pi * x * cutoff) / (math.pi * x);
        coefficients[i] = sinc * (0.5 + 0.5 * math.cos(math.pi * x / radius));
        sum += coefficients[i];
      }
      for (var i = 0; i < coefficients.length; i++) {
        coefficients[i] /= sum;
      }
      return coefficients;
    });
    for (var i = 0; i < result.length; i++) {
      final ticks = i * sampleRate;
      final start = ticks ~/ rate - radius + 1;
      final weights = filters[(ticks % rate) * phases ~/ rate];
      var value = 0.0;
      for (var j = 0; j < weights.length; j++) {
        value += samples[(start + j).clamp(0, samples.length - 1)] * weights[j];
      }
      result[i] = value.round().clamp(-32768, 32767);
    }
    return PcmAudio(samples: result, sampleRate: rate);
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
