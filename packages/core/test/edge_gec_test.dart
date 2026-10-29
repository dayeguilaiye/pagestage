import 'package:pagestage_core/src/providers/edge_gec.dart';
import 'package:test/test.dart';

void main() {
  // Independent expected values from edge-tts 7.3.1 generate_sec_ms_gec_v2.
  const vectors = {
    '2026-01-01T00:00:00Z':
        '723A6EBC411B23BB-214991EA6B1E401F3D777A699DDDEE75E29740EA7A5DCD1007366FA1090DD267',
    '2026-10-29T01:02:03Z':
        '665D83B34BA96B8C-20A037BCBCC8AEEDE4C23212D3D188CC82114432FD50435A4698EB95B10FA37A',
    '2026-10-29T01:04:59.999Z':
        '665D83B34BA96B8C-20A037BCBCC8AEEDE4C23212D3D188CC82114432FD50435A4698EB95B10FA37A',
    '2026-10-29T01:05:00Z':
        '5D0C0465A56021E2-27605FF667C5A165F91BD8249D61DE4E38EA210DA426B9A872C0AAB14EFF6019',
    '2026-10-29T09:02:03+08:00':
        '665D83B34BA96B8C-20A037BCBCC8AEEDE4C23212D3D188CC82114432FD50435A4698EB95B10FA37A',
  };
  for (final entry in vectors.entries) {
    test('v2 token matches reference at ${entry.key}', () {
      expect(edgeSecMsGec(DateTime.parse(entry.key)), entry.value);
    });
  }
}
