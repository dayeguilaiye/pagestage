import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:pagestage_app/playback/playback_queue.dart';

/// Local packaging only. The source directory must contain complete CLI output.
/// AAC encoding uses macOS afconvert or ffmpeg on other platforms.
Future<void> main(List<String> arguments) async {
  final args =
      (ArgParser()
            ..addOption('source-dir', mandatory: true)
            ..addOption(
              'output-dir',
              defaultsTo: 'packages/app/assets/examples',
            ))
          .parse(arguments);
  final source = args['source-dir'] as String;
  final output = Directory(args['output-dir'] as String);
  final store = LocalStore('$source/pagestage.sqlite');
  const expected = {'15bad7444de48233ea12c39c', 'e29cb883376b4e31947bb861'};
  final entries = <Map<String, Object?>>[];
  var size = 0;
  var duration = Duration.zero;
  await output.create(recursive: true);
  try {
    for (final id in expected) {
      final book = await Library(store).getBook(id);
      if (book.chapters.length != 5) {
        throw StateError('Each example must contain exactly five chapters.');
      }
      final records = <Map<String, Object?>>[];
      for (final collection in ['casts', 'voices', 'casting', 'scripts']) {
        if (collection == 'casting') {
          final row = await store.get(collection, id);
          if (row != null) {
            records.add({'collection': collection, 'key': id, 'value': row});
          }
        } else {
          for (final row in await store.list(collection)) {
            if (row['bookId'] != id) continue;
            final key = collection == 'casts'
                ? id
                : collection == 'scripts'
                ? '$id:${row['chapterNumber']}'
                : row['id'];
            records.add({
              'collection': collection,
              'key': key,
              'value': {...row, if (collection == 'voices') 'samplePath': null},
            });
          }
        }
      }
      final playlists = <Map<String, Object?>>[];
      final repository = AudioRepository(store);
      for (final chapter in book.chapters) {
        final script = await ScriptRepository(store).get(id, chapter.number);
        if (script == null ||
            script.promptVersion != Director.promptVersion ||
            !await repository.isComplete(script)) {
          throw StateError(
            'Current complete script/audio required: $id chapter ${chapter.number}',
          );
        }
        final audio = (await repository.get(id, chapter.number))!;
        final wav = File('$source/example-$id-${chapter.number}.wav');
        final queue = PlaybackQueue(audio.utterances);
        await queue.writeWav(wav);
        final name = '$id-${chapter.number}.m4a';
        final path = '${output.path}/$name';
        final result = Platform.isMacOS
            ? await Process.run('/usr/bin/afconvert', [
                wav.path,
                path,
                '-f',
                'm4af',
                '-d',
                'aac',
                '-b',
                '64000',
              ])
            : await Process.run('ffmpeg', [
                '-y',
                '-i',
                wav.path,
                '-c:a',
                'aac',
                '-b:a',
                '64k',
                path,
              ]);
        if (result.exitCode != 0) {
          throw StateError('AAC encoder failed for $name');
        }
        await wav.delete();
        final bytes = await File(path).readAsBytes();
        size += bytes.length;
        duration += queue.duration;
        playlists.add({
          'asset': 'assets/examples/$name',
          'sha256': sha256.convert(bytes).toString(),
          'playlist': {
            ...audio.toJson(),
            'path': name,
            'utterances': [
              for (final u in audio.utterances)
                {...u.toJson(), 'audioPath': name, 'rawAudioPath': name},
            ],
          },
        });
      }
      entries.add({
        'book': {...book.toJson(), 'sourcePath': 'bundled:$id'},
        'records': records,
        'audio': playlists,
      });
    }
    final manifest = {
      'schema': 1,
      'promptVersion': Director.promptVersion,
      'format': 'AAC-LC, mono, 64 kbps, M4A',
      'audioBytes': size,
      'durationMs': duration.inMilliseconds,
      'books': entries,
    };
    final file = File('${output.path}/manifest.json.part');
    await file.writeAsString(jsonEncode(manifest), flush: true);
    await file.rename('${output.path}/manifest.json');
    stdout.writeln(
      'Packaged ${entries.length} books: $size bytes, ${duration.inSeconds} seconds',
    );
  } finally {
    await store.close();
  }
}
