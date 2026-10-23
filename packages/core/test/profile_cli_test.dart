import 'dart:convert';
import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:pagestage_core/src/cli.dart';
import 'package:test/test.dart';

class FakeProfileLlm implements LlmAdapter {
  @override
  String get model => 'fake-cli';
  @override
  Future<LlmResponse> complete(LlmRequest request) async => const LlmResponse(
    data: {
      'characters': [],
      'personas': [],
      'merges': [],
      'provisionalResolutions': [],
      'lexicon': [],
    },
    usage: TokenUsage(inputTokens: 3, outputTokens: 2, totalTokens: 5),
  );
}

void main() {
  test(
    'profile CLI reports saved cast, model, elapsed time and usage without keys',
    () async {
      final temp = await Directory.systemTemp.createTemp('profile-cli-');
      addTearDown(() => temp.delete(recursive: true));
      final source = await File(
        '${temp.path}/book.txt',
      ).writeAsString('Chapter I\nHello.');
      final store = LocalStore('${temp.path}/pagestage.sqlite');
      final book = await Library(store).importTxt(source.path);
      await store.close();
      final output = StringBuffer();
      final errors = StringBuffer();
      final status = await runCli(
        ['--data-dir', temp.path, 'profile', book.id, '--through', '1'],
        output: output,
        errorOutput: errors,
        environment: {'LLM_KEY': 'secret-key'},
        profileLlm: FakeProfileLlm(),
      );
      expect(status, 0, reason: errors.toString());
      final result = jsonDecode(output.toString()) as Map;
      expect(result['model'], 'fake-cli');
      expect(result['promptVersion'], 'profile-v1');
      expect((result['usage'] as Map)['totalTokens'], 5);
      expect(result['elapsedMs'], isA<int>());
      expect(output.toString(), isNot(contains('secret-key')));
    },
  );
}
