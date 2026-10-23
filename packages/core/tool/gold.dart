// Authoring helper for speaker gold references.
//
//   dart run tool/gold.dart dump <book.txt> <out-dir>
//   dart run tool/gold.dart build <book.txt> <anchors.json> <gold.json>
//   dart run tool/gold.dart render <book.txt> <gold.json>
//
// `build` reads `{"chapterNumber", "speakers", "notes", "segments"}` where each
// segment is `{"speakerId", "until", "note"?}`. A segment ends right after the
// first occurrence of `until` at or after the previous boundary; the last
// segment omits `until` and runs to the end of the chapter. Offsets are UTF-16.
import 'dart:convert';
import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';

Future<void> main(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln('usage: gold.dart dump|build|render <book.txt> ...');
    exit(64);
  }
  final temp = await Directory.systemTemp.createTemp('pagestage-gold');
  final store = LocalStore('${temp.path}/library.sqlite');
  try {
    final book = await Library(store).importTxt(args[1]);
    switch (args[0]) {
      case 'dump':
        final out = Directory(args[2])..createSync(recursive: true);
        for (final chapter in book.chapters) {
          File(
            '${out.path}/chapter-${chapter.number}.txt',
          ).writeAsStringSync(chapter.text);
        }
        File('${out.path}/meta.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert({
            'bookId': book.id,
            'chapters': [
              for (final chapter in book.chapters)
                {
                  'number': chapter.number,
                  'title': chapter.title,
                  'sourceTextHash': chapter.textHash,
                  'utf16Length': chapter.text.length,
                },
            ],
          }),
        );
      case 'build':
        final spec = jsonDecode(File(args[2]).readAsStringSync()) as Map;
        final chapter = book.chapter(spec['chapterNumber'] as int);
        final text = chapter.text;
        final speakers = Map<String, String>.from(spec['speakers'] as Map);
        final spans = <Map<String, Object?>>[];
        var start = 0;
        final segments = spec['segments'] as List;
        for (var i = 0; i < segments.length; i++) {
          final segment = segments[i] as Map;
          final speaker = segment['speakerId'] as String;
          if (!speakers.containsKey(speaker)) {
            throw FormatException('Segment $i: unknown speaker $speaker.');
          }
          final until = segment['until'] as String?;
          int end;
          if (until == null) {
            if (i != segments.length - 1) {
              throw FormatException(
                'Segment $i: only the last may omit until.',
              );
            }
            end = text.length;
          } else {
            final index = text.indexOf(until, start);
            if (index < 0) {
              throw FormatException('Segment $i: anchor not found: $until');
            }
            end = index + until.length;
          }
          if (end <= start) throw FormatException('Segment $i is empty.');
          final previous = spans.isEmpty ? null : spans.last;
          if (previous != null &&
              previous['speakerId'] == speaker &&
              previous['note'] == null &&
              segment['note'] == null) {
            previous['end'] = end;
          } else {
            spans.add({
              'start': start,
              'end': end,
              'speakerId': speaker,
              if (segment['note'] != null) 'note': segment['note'],
            });
          }
          start = end;
        }
        if (start != text.length) {
          throw FormatException('Segments stop at $start of ${text.length}.');
        }
        final gold = GoldReference.fromJson({
          'schemaVersion': 1,
          'offsetUnit': 'utf16',
          'bookId': book.id,
          'chapterNumber': chapter.number,
          'sourceTextHash': chapter.textHash,
          'humanReviewed': false,
          'speakers': speakers,
          'spans': spans,
          'notes': spec['notes'] ?? <String>[],
        });
        File(args[3]).writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(gold.toJson())}\n',
        );
        stdout.writeln('${args[3]}: ${gold.spans.length} spans');
      case 'render':
        final gold = GoldReference.fromJson(
          jsonDecode(File(args[2]).readAsStringSync()),
        );
        final chapter = book.chapter(gold.chapterNumber);
        if (gold.bookId != book.id || gold.sourceTextHash != chapter.textHash) {
          throw const FormatException('Gold does not match this chapter.');
        }
        var expected = 0;
        for (final span in gold.spans) {
          if (span.start != expected || span.end <= span.start) {
            throw FormatException('Gap or overlap at ${span.start}.');
          }
          if (!gold.speakers.containsKey(span.speakerId)) {
            throw FormatException('Unknown speaker ${span.speakerId}.');
          }
          expected = span.end;
          final body = chapter.text
              .substring(span.start, span.end)
              .replaceAll('\n', '⏎');
          stdout.writeln('[${span.speakerId}] $body');
        }
        if (expected != chapter.text.length) {
          throw const FormatException('Spans do not cover the chapter.');
        }
      default:
        throw FormatException('Unknown command ${args[0]}.');
    }
  } finally {
    await store.close();
    await temp.delete(recursive: true);
  }
}
