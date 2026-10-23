import 'models/book.dart';
import 'models/cast.dart';
import 'models/gold_reference.dart';
import 'models/script.dart';

/// Compares speakers on shared source intervals, independent of line cuts.
class Evaluator {
  const Evaluator();

  EvaluationResult evaluate({
    required Book book,
    required Cast cast,
    required Script script,
    required GoldReference reference,
    required Map<String, String?> speakerMap,
  }) {
    if (script.bookId != book.id ||
        reference.bookId != book.id ||
        cast.bookId != book.id) {
      throw const FormatException('Book IDs do not match.');
    }
    if (script.chapterNumber != reference.chapterNumber ||
        script.chapterNumber < 1 ||
        script.chapterNumber > book.chapters.length) {
      throw const FormatException('Chapter numbers do not match the book.');
    }
    final chapter = book.chapter(script.chapterNumber);
    if (script.sourceTextHash != chapter.textHash ||
        reference.sourceTextHash != chapter.textHash) {
      throw const FormatException(
        'Source hash mismatch: regenerate the script or reference for this chapter.',
      );
    }
    final source = chapter.text;
    final boundaries = <int>{0};
    var offset = 0;
    for (final rune in source.runes) {
      if (rune >= 0xd800 && rune <= 0xdfff) {
        throw const FormatException('Source contains an unpaired surrogate.');
      }
      offset += rune > 0xffff ? 2 : 1;
      boundaries.add(offset);
    }
    _validateIntervals(
      script.lines.map((line) => (line.start, line.end)),
      boundaries,
      source.length,
      'Script',
    );
    _validateIntervals(
      reference.spans.map((span) => (span.start, span.end)),
      boundaries,
      source.length,
      'Reference',
    );
    final knownSpeakers = {
      for (final speaker in cast.speakers) speaker.id: speaker,
    };
    if (knownSpeakers.length != cast.speakers.length) {
      throw const FormatException('Cast contains duplicate speaker IDs.');
    }
    final mappedSpeakers = <String, String?>{};
    for (final span in reference.spans) {
      if (!reference.speakers.containsKey(span.speakerId)) {
        throw const FormatException(
          'Reference span uses an undefined speaker.',
        );
      }
      final target = speakerMap[span.speakerId];
      if (!speakerMap.containsKey(span.speakerId)) {
        throw FormatException('Missing speaker mapping for ${span.speakerId}.');
      }
      mappedSpeakers[span.speakerId] = target == null
          ? null
          : _resolveSpeakerId(target, cast, knownSpeakers);
    }
    final presentTargets = mappedSpeakers.values.whereType<String>().toList();
    if (presentTargets.toSet().length != presentTargets.length) {
      throw const FormatException(
        'Distinct reference speakers must map to distinct cast IDs.',
      );
    }
    final actualSpeakers = [
      for (final line in script.lines)
        knownSpeakers[_resolveSpeakerId(
          line.direction.speakerId,
          cast,
          knownSpeakers,
        )]!,
    ];
    var goldIndex = 0;
    var total = 0;
    var correct = 0;
    final errors = <EvaluationLineError>[];
    for (var lineIndex = 0; lineIndex < script.lines.length; lineIndex++) {
      final line = script.lines[lineIndex];
      final actual = actualSpeakers[lineIndex];
      final mismatches = <SpeakerMismatch>[];
      while (goldIndex < reference.spans.length) {
        final gold = reference.spans[goldIndex];
        if (gold.start >= line.end) break;
        final start = line.start > gold.start ? line.start : gold.start;
        final end = line.end < gold.end ? line.end : gold.end;
        final text = source.substring(start, end);
        final weight = text.runes.where((rune) => !_isWhitespace(rune)).length;
        total += weight;
        if (actual.id == mappedSpeakers[gold.speakerId]) {
          correct += weight;
        } else if (weight > 0) {
          mismatches.add(
            SpeakerMismatch(
              start: start,
              end: end,
              text: text,
              characters: weight,
              expectedSpeakerId: gold.speakerId,
              expectedSpeakerName: reference.speakers[gold.speakerId]!,
              expectedCastId: mappedSpeakers[gold.speakerId],
              actualSpeakerId: actual.id,
              actualSpeakerName: actual.name,
            ),
          );
        }
        if (gold.end > line.end) break;
        goldIndex++;
      }
      if (mismatches.isNotEmpty) {
        errors.add(
          EvaluationLineError(
            lineNumber: lineIndex + 1,
            start: line.start,
            end: line.end,
            text: line.textIn(source),
            mismatches: mismatches,
          ),
        );
      }
    }
    return EvaluationResult(
      script: script,
      humanReviewed: reference.humanReviewed,
      correctCharacters: correct,
      totalCharacters: total,
      errors: errors,
      notes: reference.notes,
      speakerMap: mappedSpeakers,
    );
  }
}

String _resolveSpeakerId(String id, Cast cast, Map<String, Speaker> known) {
  final visited = <String>{};
  while (cast.redirects.containsKey(id)) {
    if (!visited.add(id)) {
      throw const FormatException('Cast speaker redirects contain a cycle.');
    }
    id = cast.redirects[id]!;
  }
  if (!known.containsKey(id)) {
    throw FormatException('Unknown cast speaker ID: $id.');
  }
  return id;
}

void _validateIntervals(
  Iterable<(int, int)> intervals,
  Set<int> boundaries,
  int length,
  String label,
) {
  var cursor = 0;
  for (final (start, end) in intervals) {
    if (start != cursor ||
        end <= start ||
        end > length ||
        !boundaries.contains(start) ||
        !boundaries.contains(end)) {
      throw FormatException(
        '$label intervals must cover the source in order without gaps, overlaps or split Unicode scalars.',
      );
    }
    cursor = end;
  }
  if (cursor != length) {
    throw FormatException('$label intervals do not cover the complete source.');
  }
}

// Unicode White_Space property. Punctuation and supplementary scalars count.
bool _isWhitespace(int rune) =>
    rune >= 0x09 && rune <= 0x0d ||
    rune == 0x20 ||
    rune == 0x85 ||
    rune == 0xa0 ||
    rune == 0x1680 ||
    rune >= 0x2000 && rune <= 0x200a ||
    rune == 0x2028 ||
    rune == 0x2029 ||
    rune == 0x202f ||
    rune == 0x205f ||
    rune == 0x3000;

class EvaluationResult {
  EvaluationResult({
    required this.script,
    required this.humanReviewed,
    required this.correctCharacters,
    required this.totalCharacters,
    required List<EvaluationLineError> errors,
    required List<String> notes,
    required Map<String, String?> speakerMap,
  }) : speakerMap = Map.unmodifiable(speakerMap),
       errors = List.unmodifiable(errors),
       notes = List.unmodifiable(notes);

  final Script script;
  final Map<String, String?> speakerMap;
  final bool humanReviewed;
  final int correctCharacters;
  final int totalCharacters;
  final List<EvaluationLineError> errors;
  final List<String> notes;
  double? get accuracy =>
      totalCharacters == 0 ? null : correctCharacters / totalCharacters;

  Map<String, Object?> toJson() => {
    'status': humanReviewed ? 'reviewed' : 'draft',
    'humanReviewed': humanReviewed,
    if (!humanReviewed)
      'warning':
          'Draft reference: awaiting human correction; this is not a validated quality score.',
    'bookId': script.bookId,
    'chapterNumber': script.chapterNumber,
    'sourceTextHash': script.sourceTextHash,
    'model': script.model,
    'promptVersion': script.promptVersion,
    'speakerMap': speakerMap,
    'weighting': 'unicode-scalars-excluding-whitespace',
    'correctCharacters': correctCharacters,
    'totalCharacters': totalCharacters,
    'accuracy': accuracy,
    'errors': errors.map((error) => error.toJson()).toList(),
    'notes': notes,
  };
}

class EvaluationLineError {
  EvaluationLineError({
    required this.lineNumber,
    required this.start,
    required this.end,
    required this.text,
    required List<SpeakerMismatch> mismatches,
  }) : mismatches = List.unmodifiable(mismatches);
  final int lineNumber;
  final int start;
  final int end;
  final String text;
  final List<SpeakerMismatch> mismatches;
  Map<String, Object?> toJson() => {
    'lineNumber': lineNumber,
    'start': start,
    'end': end,
    'text': text,
    'mismatches': mismatches.map((mismatch) => mismatch.toJson()).toList(),
  };
}

class SpeakerMismatch {
  const SpeakerMismatch({
    required this.start,
    required this.end,
    required this.text,
    required this.characters,
    required this.expectedSpeakerId,
    required this.expectedSpeakerName,
    required this.expectedCastId,
    required this.actualSpeakerId,
    required this.actualSpeakerName,
  });
  final int start;
  final int end;
  final String text;
  final int characters;
  final String expectedSpeakerId;
  final String expectedSpeakerName;
  final String? expectedCastId;
  final String actualSpeakerId;
  final String actualSpeakerName;
  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'text': text,
    'characters': characters,
    'expectedSpeakerId': expectedSpeakerId,
    'expectedSpeakerName': expectedSpeakerName,
    'expectedCastId': expectedCastId,
    'actualSpeakerId': actualSpeakerId,
    'actualSpeakerName': actualSpeakerName,
  };
}
