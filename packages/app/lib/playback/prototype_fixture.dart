import 'dart:convert';
import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:path_provider/path_provider.dart';

import 'playback_queue.dart';

class PlaybackFixture {
  PlaybackFixture(this.title, this.chapter, this.script, this.queue, this.path);
  final String title;
  final Chapter chapter;
  final Script script;
  final PlaybackQueue queue;
  final String path;

  static Future<PlaybackFixture> load({Directory? directory}) async {
    const override = String.fromEnvironment('PLAYBACK_FIXTURE');
    final root =
        directory ??
        Directory(
          override.isNotEmpty
              ? override
              : '${(await getApplicationSupportDirectory()).path}/playback-prototype',
        );
    final json =
        jsonDecode(await File('${root.path}/fixture.json').readAsString())
            as Map<String, dynamic>;
    final utterances = (json['utterances'] as List).map((value) {
      final row = Map<String, Object?>.from(value as Map);
      row['audioPath'] = '${root.path}/${row['audioPath']}';
      row['rawAudioPath'] = row['audioPath'];
      return SynthesizedUtterance.fromJson(row);
    }).toList();
    return PlaybackFixture(
      json['title'] as String,
      Chapter.fromJson(Map<String, Object?>.from(json['chapter'] as Map)),
      Script.fromJson(Map<String, Object?>.from(json['script'] as Map)),
      PlaybackQueue(utterances),
      '${root.path}/chapter.wav',
    );
  }
}
