import 'dart:typed_data';

/// Decodes provider audio in one pass with constant stack usage.
Uint8List decodeHexAudio(String hex) {
  if (hex.isEmpty || hex.length.isOdd) {
    throw const FormatException('Invalid audio encoding.');
  }
  final bytes = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] =
        (_digit(hex.codeUnitAt(i * 2)) << 4) |
        _digit(hex.codeUnitAt(i * 2 + 1));
  }
  return bytes;
}

int _digit(int code) {
  if (code >= 0x30 && code <= 0x39) return code - 0x30;
  if (code >= 0x41 && code <= 0x46) return code - 0x41 + 10;
  if (code >= 0x61 && code <= 0x66) return code - 0x61 + 10;
  throw const FormatException('Invalid audio encoding.');
}
