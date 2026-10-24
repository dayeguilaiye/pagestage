import 'dart:convert';
import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';

import 'package:pagestage_app/playback/playback_queue.dart';

/// Converts existing local CLI output into a relocatable, ignored test fixture.
/// Run from the repository root. No provider or configuration is opened.
Future<void> main(List<String> args) async {
  final output = Directory(
    args.isEmpty ? '.pagestage/playback-prototype' : args.single,
  );
  await Directory('${output.path}/clips').create(recursive: true);
  final synthesized =
      jsonDecode(
            await File('.pagestage/spike/out/aq-synth-1.json').readAsString(),
          )
          as Map;
  final directed =
      jsonDecode(
            await File('.pagestage/spike/out/aq-direct-1.json').readAsString(),
          )
          as Map;
  final store = LocalStore('${output.path}/fixture.sqlite');
  try {
    final book = await Library(
      store,
    ).importTxt('test/fixtures/books/aq-zh.txt', title: '阿Q正传');
    final script = Script.fromJson(
      Map<String, Object?>.from(directed['script'] as Map),
    );
    final chapter = book.chapter(1);
    if (script.sourceTextHash != chapter.textHash) {
      throw StateError('Fixture text does not match the saved script.');
    }
    final utterances = <SynthesizedUtterance>[];
    final seen = <String>{};
    for (final value in synthesized['lines'] as List) {
      final row = Map<String, Object?>.from(value as Map);
      if (row['audioPath'] == null || !seen.add(row['cacheKey'] as String)) {
        continue;
      }
      final path = '${output.path}/clips/${row['cacheKey']}.wav';
      await File(row['audioPath'] as String).copy(path);
      final clip = PcmAudio.fromWav(await File(path).readAsBytes());
      utterances.add(
        SynthesizedUtterance.fromJson({
          ...row,
          'speakerId': (row['direction'] as Map)['speakerId'],
          'lineIndices': row['utteranceLineIndices'],
          'durationUs': clip.duration.inMicroseconds,
          'pauseBeforeUs': (row['pauseBeforeMs'] as int) * 1000,
          'audioPath': path,
          'rawAudioPath': path,
        }),
      );
    }
    final queue = PlaybackQueue(utterances);
    await queue.writeWav(File('${output.path}/chapter.wav'));
    await File('${output.path}/fixture.json').writeAsString(
      jsonEncode({
        'title': book.title,
        'chapter': chapter.toJson(),
        'script': script.toJson(),
        'utterances': [
          for (final item in utterances)
            {
              ...item.toJson(),
              'audioPath': 'clips/${item.cacheKey}.wav',
              'rawAudioPath': 'clips/${item.cacheKey}.wav',
            },
        ],
      }),
    );
    stdout.writeln(
      'Prepared ${utterances.length} utterances, ${queue.duration.inMilliseconds} ms in ${output.path}',
    );
  } finally {
    await store.close();
  }
}
