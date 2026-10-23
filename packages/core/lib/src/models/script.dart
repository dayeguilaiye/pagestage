import 'book.dart';

enum Emotion { calm, happy, sad, angry, fearful, disgusted, surprised }

enum Intensity { mild, medium, strong }

class Direction {
  const Direction({
    required this.speakerId,
    this.emotion = Emotion.calm,
    this.intensity = Intensity.mild,
    this.note = '',
  });
  final String speakerId;
  final Emotion emotion;
  final Intensity intensity;
  final String note;

  Map<String, Object?> toJson() => {
    'speakerId': speakerId,
    'emotion': emotion.name,
    'intensity': intensity.name,
    'note': note,
  };
  factory Direction.fromJson(Map<String, Object?> json) => Direction(
    speakerId: json['speakerId'] as String,
    emotion: Emotion.values.byName(json['emotion'] as String),
    intensity: Intensity.values.byName(json['intensity'] as String),
    note: json['note'] as String,
  );
}

/// A half-open UTF-16 interval in the unchanged chapter body.
class ScriptLine {
  const ScriptLine({
    required this.start,
    required this.end,
    required this.direction,
    this.isDialogueTag = false,
    this.isNonStory = false,
  });
  final int start;
  final int end;
  final Direction direction;
  final bool isDialogueTag;
  final bool isNonStory;
  String textIn(String source) => source.substring(start, end);
  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'direction': direction.toJson(),
    'isDialogueTag': isDialogueTag,
    'isNonStory': isNonStory,
  };
  factory ScriptLine.fromJson(Map<String, Object?> json) => ScriptLine(
    start: json['start'] as int,
    end: json['end'] as int,
    direction: Direction.fromJson(
      Map<String, Object?>.from(json['direction'] as Map),
    ),
    isDialogueTag: json['isDialogueTag'] as bool,
    isNonStory: json['isNonStory'] as bool,
  );
}

class Script {
  Script({
    required this.bookId,
    required this.chapterNumber,
    required this.sourceTextHash,
    required this.model,
    required this.promptVersion,
    required List<ScriptLine> lines,
  }) : lines = List.unmodifiable(lines);
  final String bookId;
  final int chapterNumber;
  final String sourceTextHash;
  final String model;
  final String promptVersion;
  final List<ScriptLine> lines;

  /// The CLI tracer bullet: every nonempty text line is a narrator paragraph.
  /// Whitespace stays attached to source ranges, preserving the complete body.
  factory Script.narration({required String bookId, required Chapter chapter}) {
    final paragraphs = RegExp(r'[^\r\n]+')
        .allMatches(chapter.text)
        .where((match) => match.group(0)!.trim().isNotEmpty)
        .toList();
    return Script(
      bookId: bookId,
      chapterNumber: chapter.number,
      sourceTextHash: chapter.textHash,
      model: 'narrator',
      promptVersion: 'narrator-paragraphs-v1',
      lines: [
        for (var i = 0; i < paragraphs.length; i++)
          ScriptLine(
            start: i == 0 ? 0 : paragraphs[i].start,
            end: i + 1 < paragraphs.length
                ? paragraphs[i + 1].start
                : chapter.text.length,
            direction: const Direction(speakerId: 'narrator'),
          ),
      ],
    );
  }
  Map<String, Object?> toJson() => {
    'bookId': bookId,
    'chapterNumber': chapterNumber,
    'sourceTextHash': sourceTextHash,
    'model': model,
    'promptVersion': promptVersion,
    'lines': lines.map((line) => line.toJson()).toList(),
  };
  factory Script.fromJson(Map<String, Object?> json) => Script(
    bookId: json['bookId'] as String,
    chapterNumber: json['chapterNumber'] as int,
    sourceTextHash: json['sourceTextHash'] as String,
    model: json['model'] as String,
    promptVersion: json['promptVersion'] as String,
    lines: (json['lines'] as List)
        .map(
          (line) => ScriptLine.fromJson(Map<String, Object?>.from(line as Map)),
        )
        .toList(),
  );
}
