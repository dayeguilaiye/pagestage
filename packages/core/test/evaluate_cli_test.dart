import 'dart:convert';
import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:pagestage_core/src/cli.dart';
import 'package:test/test.dart';

void main() {
  test(
    'evaluates a saved script offline and labels an unreviewed score',
    () async {
      final directory = await Directory.systemTemp.createTemp('evaluate-cli-');
      addTearDown(() => directory.delete(recursive: true));
      final store = LocalStore('${directory.path}/pagestage.sqlite');
      final file = await File('${directory.path}/book.txt').writeAsString('AB');
      final book = await Library(store).importTxt(file.path);
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          speakers: [
            Speaker(id: 'n', name: 'Narrator', kind: SpeakerKind.narrator),
            Speaker(id: 'a', name: 'Alice'),
          ],
        ),
      );
      await ScriptRepository(store).save(
        Script(
          bookId: book.id,
          chapterNumber: 1,
          sourceTextHash: book.chapter(1).textHash,
          model: 'fake-llm',
          promptVersion: 'director-hand-test',
          lines: const [
            ScriptLine(start: 0, end: 2, direction: Direction(speakerId: 'n')),
          ],
        ),
      );
      await store.close();
      final gold = await File('${directory.path}/gold.json').writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'offsetUnit': 'utf16',
          'bookId': book.id,
          'chapterNumber': 1,
          'sourceTextHash': book.chapter(1).textHash,
          'humanReviewed': false,
          'speakers': {'narrator': 'Narrator', 'alice': 'Alice'},
          'spans': [
            {'start': 0, 'end': 1, 'speakerId': 'narrator'},
            {'start': 1, 'end': 2, 'speakerId': 'alice'},
          ],
          'notes': ['Awaiting human correction.'],
        }),
      );
      final mapping = await File(
        '${directory.path}/map.json',
      ).writeAsString(jsonEncode({'narrator': 'n', 'alice': 'a'}));
      final output = StringBuffer();
      final errors = StringBuffer();
      final exit = await runCli(
        [
          '--data-dir',
          directory.path,
          'evaluate',
          book.id,
          '1',
          '--gold',
          gold.path,
          '--speaker-map',
          mapping.path,
        ],
        output: output,
        errorOutput: errors,
        environment: {},
      );
      expect(exit, 0, reason: errors.toString());
      final result = jsonDecode(output.toString()) as Map;
      expect(result['accuracy'], .5); // A correct, B incorrect.
      expect(result['status'], 'draft');
      expect(result['humanReviewed'], false);
      expect(result['warning'], contains('awaiting human correction'));
      expect(result['model'], 'fake-llm');
      expect(result['promptVersion'], 'director-hand-test');
      expect(
        (result['errors'] as List).single['mismatches'].single['text'],
        'B',
      );
      expect(result['speakerMap'], {'narrator': 'n', 'alice': 'a'});
    },
  );
}
