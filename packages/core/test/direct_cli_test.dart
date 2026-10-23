import 'dart:convert';
import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:pagestage_core/src/cli.dart';
import 'package:test/test.dart';

class CliDirectorLlm implements LlmAdapter {
  @override
  String get model => 'fake-director-cli';
  @override
  Future<LlmResponse> complete(LlmRequest request) async => const LlmResponse(
    data: {
      'lines': [
        {
          'text': '甲说。',
          'speakerId': 'lin',
          'emotion': 'calm',
          'intensity': 'mild',
          'note': '自然',
          'isDialogueTag': false,
          'isNonStory': false,
        },
      ],
    },
    usage: TokenUsage(inputTokens: 2, outputTokens: 3, totalTokens: 5),
  );
}

void main() {
  test(
    'direct CLI prints original text, speakers, provenance and usage',
    () async {
      final temp = await Directory.systemTemp.createTemp('direct-cli-');
      addTearDown(() => temp.delete(recursive: true));
      final file = await File(
        '${temp.path}/book.txt',
      ).writeAsString('第一章\n甲说。');
      final store = LocalStore('${temp.path}/pagestage.sqlite');
      final book = await Library(store).importTxt(file.path);
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 1,
          speakers: [
            Speaker(id: 'lin', name: '林舟', chapters: [1]),
          ],
        ),
      );
      await store.close();
      final output = StringBuffer();
      final errors = StringBuffer();
      final status = await runCli(
        ['--data-dir', temp.path, 'direct', book.id, '1'],
        output: output,
        errorOutput: errors,
        environment: {},
        directorLlm: CliDirectorLlm(),
      );
      expect(status, 0, reason: errors.toString());
      final result = jsonDecode(output.toString()) as Map;
      final script = result['script'] as Map;
      final line = (script['lines'] as List).single as Map;
      expect(line['text'], '甲说。');
      expect(line['speakerName'], '林舟');
      expect(script['model'], 'fake-director-cli');
      expect(script['promptVersion'], 'director-v4');
      expect((result['usage'] as Map)['totalTokens'], 5);
      expect(result['elapsedMs'], isA<int>());
    },
  );
}
