import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  Uint8List withSizes(Uint8List wav, int riff, int data) {
    final bytes = Uint8List.fromList(wav);
    final view = ByteData.sublistView(bytes);
    view.setUint32(4, riff, Endian.little);
    view.setUint32(40, data, Endian.little);
    return bytes;
  }

  final wav = PcmAudio(samples: Int16List.fromList([1, -2, 3])).toWav();

  test('streamed WAV placeholder sizes read to the end of the file', () {
    // Bailian result files declare RIFF 0x7FFFFFBF and data 0x7FFFFF9B.
    for (final (riff, data) in [
      (0x7FFFFFBF, 0x7FFFFF9B),
      (0xFFFFFFFF, 0xFFFFFFFF),
    ]) {
      final audio = PcmAudio.fromWav(withSizes(wav, riff, data));
      expect(audio.samples, [1, -2, 3]);
      expect(audio.sampleRate, 24000);
    }
  });

  test('a WAV shorter than its declared real size is still truncated', () {
    expect(
      () => PcmAudio.fromWav(Uint8List.sublistView(wav, 0, wav.length - 2)),
      throwsFormatException,
    );
  });
}
