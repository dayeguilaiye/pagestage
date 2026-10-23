import 'gb18030_data.dart';

/// Strict GB18030 decoding, including the four-byte supplementary ranges.
/// https://encoding.spec.whatwg.org/#gb18030-decoder
String decodeGb18030(List<int> bytes) {
  final output = StringBuffer();
  for (var offset = 0; offset < bytes.length;) {
    final first = bytes[offset++];
    if (first <= 0x7f) {
      output.writeCharCode(first);
      continue;
    }
    if (first == 0x80) {
      output.writeCharCode(0x20ac);
      continue;
    }
    if (first < 0x81 || first > 0xfe || offset == bytes.length) {
      throw const FormatException('Invalid GB18030 input.');
    }
    final second = bytes[offset++];
    if (second >= 0x30 && second <= 0x39) {
      if (offset + 1 >= bytes.length) {
        throw const FormatException('Incomplete GB18030 character.');
      }
      final third = bytes[offset++];
      final fourth = bytes[offset++];
      if (third < 0x81 || third > 0xfe || fourth < 0x30 || fourth > 0x39) {
        throw const FormatException('Invalid GB18030 character.');
      }
      final pointer =
          ((first - 0x81) * 10 + second - 0x30) * 1260 +
          (third - 0x81) * 10 +
          fourth -
          0x30;
      if ((pointer > 39419 && pointer < 189000) || pointer > 1237575) {
        throw const FormatException('Unassigned GB18030 character.');
      }
      if (pointer == 7457) {
        output.writeCharCode(0xe7c7);
        continue;
      }
      var low = 0;
      var high = gb18030Ranges.length;
      while (low + 1 < high) {
        final middle = (low + high) ~/ 2;
        if (gb18030Ranges[middle].$1 <= pointer) {
          low = middle;
        } else {
          high = middle;
        }
      }
      final range = gb18030Ranges[low];
      output.writeCharCode(range.$2 + pointer - range.$1);
    } else {
      if (second < 0x40 || second > 0xfe || second == 0x7f) {
        throw const FormatException('Invalid GB18030 character.');
      }
      final pointer =
          (first - 0x81) * 190 + second - (second < 0x7f ? 0x40 : 0x41);
      output.writeCharCode(gb18030Index[pointer]);
    }
  }
  return output.toString();
}
