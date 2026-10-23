/// An independently reviewed source-range speaker annotation.
class GoldReference {
  GoldReference({
    required this.bookId,
    required this.chapterNumber,
    required this.sourceTextHash,
    required this.humanReviewed,
    required Map<String, String> speakers,
    required List<GoldSpan> spans,
    List<String> notes = const [],
  }) : speakers = Map.unmodifiable(speakers),
       spans = List.unmodifiable(spans),
       notes = List.unmodifiable(notes);

  final String bookId;
  final int chapterNumber;
  final String sourceTextHash;
  final bool humanReviewed;
  final Map<String, String> speakers;
  final List<GoldSpan> spans;
  final List<String> notes;

  factory GoldReference.fromJson(Object? json) {
    if (json is! Map ||
        json['schemaVersion'] != 1 ||
        json['offsetUnit'] != 'utf16' ||
        !_nonempty(json['bookId']) ||
        json['chapterNumber'] is! int ||
        (json['chapterNumber'] as int) < 1 ||
        json['sourceTextHash'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(json['sourceTextHash'] as String) ||
        json['humanReviewed'] is! bool ||
        json['speakers'] is! Map ||
        json['spans'] is! List) {
      throw const FormatException(
        'Invalid gold reference metadata or schema version.',
      );
    }
    final rawSpeakers = json['speakers'] as Map;
    if (rawSpeakers.entries.any(
      (entry) => !_nonempty(entry.key) || !_nonempty(entry.value),
    )) {
      throw const FormatException(
        'Gold speakers must map nonempty IDs to display names.',
      );
    }
    final notes = json['notes'] ?? <String>[];
    if (notes is! List || notes.any((note) => note is! String)) {
      throw const FormatException('Gold notes must be a list of strings.');
    }
    return GoldReference(
      bookId: json['bookId'] as String,
      chapterNumber: json['chapterNumber'] as int,
      sourceTextHash: json['sourceTextHash'] as String,
      humanReviewed: json['humanReviewed'] as bool,
      speakers: Map<String, String>.from(rawSpeakers),
      spans: (json['spans'] as List).map(GoldSpan.fromJson).toList(),
      notes: notes.cast<String>(),
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'offsetUnit': 'utf16',
    'bookId': bookId,
    'chapterNumber': chapterNumber,
    'sourceTextHash': sourceTextHash,
    'humanReviewed': humanReviewed,
    'speakers': speakers,
    'spans': spans.map((span) => span.toJson()).toList(),
    'notes': notes,
  };
}

/// A half-open UTF-16 source interval assigned to a semantic gold speaker.
class GoldSpan {
  const GoldSpan({
    required this.start,
    required this.end,
    required this.speakerId,
    this.note,
  });
  final int start;
  final int end;
  final String speakerId;
  final String? note;

  factory GoldSpan.fromJson(Object? json) {
    if (json is! Map ||
        json['start'] is! int ||
        json['end'] is! int ||
        !_nonempty(json['speakerId']) ||
        (json['note'] != null && json['note'] is! String)) {
      throw const FormatException('Invalid gold source interval.');
    }
    return GoldSpan(
      start: json['start'] as int,
      end: json['end'] as int,
      speakerId: json['speakerId'] as String,
      note: json['note'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'speakerId': speakerId,
    if (note != null) 'note': note,
  };
}

bool _nonempty(Object? value) => value is String && value.trim().isNotEmpty;
