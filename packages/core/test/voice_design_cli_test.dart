import 'dart:convert';
import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:pagestage_core/src/cli.dart';
import 'package:test/test.dart';

import 'voice_design_test.dart' show FakeDesignTts;

void main() {
  test(
    'CLI generates, lists and selects persistent voice candidates',
    () async {
      final temp = await Directory.systemTemp.createTemp('design-cli-');
      addTearDown(() => temp.delete(recursive: true));
      final file = await File(
        '${temp.path}/novel.txt',
      ).writeAsString('Chapter 1\nHello, world.');
      final store = LocalStore('${temp.path}/pagestage.sqlite');
      final book = await Library(store).importTxt(file.path);
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 1,
          speakers: [
            Speaker(
              id: 'hero',
              name: 'Hero',
              voiceDescription: 'A warm voice.',
            ),
          ],
        ),
      );
      await store.close();
      final fake = FakeDesignTts();
      Future<Object?> command(List<String> args) async {
        final out = StringBuffer();
        final error = StringBuffer();
        final code = await runCli(
          ['--data-dir', temp.path, 'voice-design', ...args],
          output: out,
          errorOutput: error,
          environment: {},
          ttsAdapters: {'minimax': fake},
        );
        expect(code, 0, reason: error.toString());
        return jsonDecode(out.toString());
      }

      final candidates =
          await command(['generate', book.id, 'hero', '--provider', 'minimax'])
              as List;
      expect(candidates, hasLength(3));
      final candidate = candidates[1] as Map;
      expect(
        ((candidate['voice'] as Map)['binding'] as Map)['designed'],
        isTrue,
      );
      expect((candidate['voice'] as Map)['description'], 'A warm voice.');
      final listed =
          await command(['list', book.id, '--speaker', 'hero']) as List;
      expect(listed, hasLength(3));
      final selected =
          await command(['select', book.id, 'hero', candidate['id'] as String])
              as Map;
      expect(selected['id'], candidate['id']);
      expect(selected['samplePath'], endsWith('.selected.wav'));
      expect(fake.synthesis.single.binding.voiceId, 'designed-2');
    },
  );
}
