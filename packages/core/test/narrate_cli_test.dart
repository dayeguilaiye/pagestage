import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:pagestage_core/src/cli.dart';
import 'package:test/test.dart';

void main() {
  test('CLI narrates an imported chapter through a fake TTS adapter', () async {
    final directory = await Directory.systemTemp.createTemp(
      'pagestage-narrate-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File(
      '${directory.path}/book.txt',
    ).writeAsString('Chapter I.\nFirst.\nSecond.');
    final imported = StringBuffer();
    expect(
      await runCli([
        '--data-dir',
        directory.path,
        'import',
        file.path,
      ], output: imported),
      0,
    );
    final bookId = (jsonDecode(imported.toString()) as Map)['bookId'] as String;
    final output = StringBuffer();
    final fake = _FakeTts();
    expect(
      await runCli(
        ['--data-dir', directory.path, 'narrate', bookId, '1'],
        output: output,
        environment: {},
        ttsAdapters: {'minimax': fake},
      ),
      0,
    );
    final result = jsonDecode(output.toString()) as Map;
    expect(result['requests'], 2);
    expect(result['durationMs'], 320);
    expect(await File(result['path'] as String).exists(), isTrue);
    expect(fake.requests.map((r) => r.text).join(), 'First.\nSecond.');
  });
  test(
    'CLI keeps malformed local configuration and provider failures out of output',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pagestage-safe-cli-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = await File(
        '${directory.path}/book.txt',
      ).writeAsString('Chapter I.\nFirst.');
      final imported = StringBuffer();
      await runCli([
        '--data-dir',
        directory.path,
        'import',
        file.path,
      ], output: imported);
      final bookId =
          (jsonDecode(imported.toString()) as Map)['bookId'] as String;
      final config = await File(
        '${directory.path}/config.json',
      ).writeAsString('{"minimax":{"key":"fixture-secret"');
      final output = StringBuffer();
      final errors = StringBuffer();
      expect(
        await runCli(
          [
            '--data-dir',
            directory.path,
            'narrate',
            bookId,
            '1',
            '--config',
            config.path,
          ],
          output: output,
          errorOutput: errors,
          environment: {},
          ttsAdapters: {'minimax': _FakeTts()},
        ),
        65,
      );
      expect(
        output.toString() + errors.toString(),
        isNot(contains('fixture-secret')),
      );
      errors.clear();
      expect(
        await runCli(
          ['--data-dir', directory.path, 'narrate', bookId, '1'],
          output: output,
          errorOutput: errors,
          environment: {},
          ttsAdapters: {'minimax': _FailingTts()},
        ),
        69,
      );
      expect(errors.toString(), contains('insufficient balance'));
      expect(
        output.toString() + errors.toString(),
        isNot(contains('fixture-secret')),
      );
    },
  );
}

class _FakeTts implements TtsAdapter {
  final requests = <TtsRequest>[];
  @override
  String get provider => 'minimax';
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    requests.add(request);
    return TtsAudio(
      audio: PcmAudio(samples: Int16List(240)),
      characters: request.text.runes.length,
    );
  }
}

class _FailingTts implements TtsAdapter {
  @override
  String get provider => 'minimax';
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async =>
      throw const ProviderException(
        provider: 'minimax',
        kind: ProviderErrorKind.insufficientBalance,
        code: 'fixture-secret',
      );
}
