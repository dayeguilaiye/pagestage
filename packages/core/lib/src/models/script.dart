import 'book.dart';

enum Emotion { calm, happy, sad, angry, fearful, disgusted, surprised }

enum Intensity { mild, medium, strong }

/// How fast a line is spoken, relative to the speaker's usual pace.
enum Pace { slow, normal, fast }

/// How loudly a line is spoken, relative to the speaker's usual volume.
enum Volume { soft, normal, loud }

/// Sounds a speaker makes that are not words.
enum VocalCueKind {
  laugh,
  chuckle,
  sigh,
  gasp,
  sob,
  sniff,
  cough,
  clearThroat,
  pant,
  groan,
  yawn,
}

/// A non-verbal sound inside a line. [offset] counts UTF-16 code units from
/// the start of the line's text: 0 is before the first word, the text length
/// is after the last. The source text itself never changes.
class VocalCue {
  const VocalCue(this.kind, {this.offset = 0});
  final VocalCueKind kind;
  final int offset;

  Map<String, Object?> toJson() => {'kind': kind.name, 'offset': offset};
  factory VocalCue.fromJson(Map<String, Object?> json) => VocalCue(
    VocalCueKind.values.byName(json['kind'] as String),
    offset: json['offset'] as int? ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is VocalCue && other.kind == kind && other.offset == offset;
  @override
  int get hashCode => Object.hash(kind, offset);
}

/// What the director asks of one line, independent of any voice engine.
/// Each engine performs as much of it as it can; see `Delivery.lower`.
class Direction {
  const Direction({
    required this.speakerId,
    this.emotion = Emotion.calm,
    this.intensity = Intensity.mild,
    this.note = '',
    this.pace = Pace.normal,
    this.volume = Volume.normal,
    this.cues = const [],
  });
  final String speakerId;
  final Emotion emotion;
  final Intensity intensity;

  /// One sentence of vocal direction in the book's language.
  final String note;
  final Pace pace;
  final Volume volume;
  final List<VocalCue> cues;

  Direction copyWith({
    String? speakerId,
    Emotion? emotion,
    Intensity? intensity,
    String? note,
    Pace? pace,
    Volume? volume,
    List<VocalCue>? cues,
  }) => Direction(
    speakerId: speakerId ?? this.speakerId,
    emotion: emotion ?? this.emotion,
    intensity: intensity ?? this.intensity,
    note: note ?? this.note,
    pace: pace ?? this.pace,
    volume: volume ?? this.volume,
    cues: cues ?? this.cues,
  );

  // Fields added after director-v5 are written only when set, so scripts
  // directed before them keep their hash and their audio.
  Map<String, Object?> toJson() => {
    'speakerId': speakerId,
    'emotion': emotion.name,
    'intensity': intensity.name,
    'note': note,
    if (pace != Pace.normal) 'pace': pace.name,
    if (volume != Volume.normal) 'volume': volume.name,
    if (cues.isNotEmpty) 'cues': cues.map((cue) => cue.toJson()).toList(),
  };
  factory Direction.fromJson(Map<String, Object?> json) => Direction(
    speakerId: json['speakerId'] as String,
    emotion: Emotion.values.byName(json['emotion'] as String),
    intensity: Intensity.values.byName(json['intensity'] as String),
    note: json['note'] as String,
    pace: Pace.values.byName(json['pace'] as String? ?? 'normal'),
    volume: Volume.values.byName(json['volume'] as String? ?? 'normal'),
    cues: [
      for (final cue in json['cues'] as List? ?? const [])
        VocalCue.fromJson(Map<String, Object?>.from(cue as Map)),
    ],
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
