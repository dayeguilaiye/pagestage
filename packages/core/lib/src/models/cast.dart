import '../local_store.dart';

enum SpeakerKind { narrator, character, persona, provisional }

class Speaker {
  Speaker({
    required this.id,
    required this.name,
    this.kind = SpeakerKind.character,
    List<String> aliases = const [],
    this.gender = 'unknown',
    this.ageGroup = 'unknown',
    this.personality = '',
    this.speakingStyle = '',
    this.voiceDescription = '',
    this.dialogueCount = 0,
    List<int> chapters = const [],
    this.characterId,
    this.revealChapter,
    this.voiceId,
  }) : aliases = List.unmodifiable(aliases),
       chapters = List.unmodifiable(chapters);
  final String id;
  final String name;
  final SpeakerKind kind;
  final List<String> aliases;
  final String gender;
  final String ageGroup;
  final String personality;
  final String speakingStyle;
  final String voiceDescription;
  final int dialogueCount;
  final List<int> chapters;
  final String? characterId;
  final int? revealChapter;
  final String? voiceId;

  Speaker copyWith({
    String? id,
    String? name,
    SpeakerKind? kind,
    List<String>? aliases,
    String? gender,
    String? ageGroup,
    String? personality,
    String? speakingStyle,
    String? voiceDescription,
    int? dialogueCount,
    List<int>? chapters,
    String? characterId,
    int? revealChapter,
    String? voiceId,
  }) => Speaker(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    aliases: aliases ?? this.aliases,
    gender: gender ?? this.gender,
    ageGroup: ageGroup ?? this.ageGroup,
    personality: personality ?? this.personality,
    speakingStyle: speakingStyle ?? this.speakingStyle,
    voiceDescription: voiceDescription ?? this.voiceDescription,
    dialogueCount: dialogueCount ?? this.dialogueCount,
    chapters: chapters ?? this.chapters,
    characterId: characterId ?? this.characterId,
    revealChapter: revealChapter ?? this.revealChapter,
    voiceId: voiceId ?? this.voiceId,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'aliases': aliases,
    'gender': gender,
    'ageGroup': ageGroup,
    'personality': personality,
    'speakingStyle': speakingStyle,
    'voiceDescription': voiceDescription,
    'dialogueCount': dialogueCount,
    'chapters': chapters,
    'characterId': characterId,
    'revealChapter': revealChapter,
    'voiceId': voiceId,
  };
  factory Speaker.fromJson(Map<String, Object?> json) => Speaker(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: SpeakerKind.values.byName(json['kind'] as String),
    aliases: (json['aliases'] as List).cast<String>(),
    gender: json['gender'] as String,
    ageGroup: json['ageGroup'] as String,
    personality: json['personality'] as String,
    speakingStyle: json['speakingStyle'] as String,
    voiceDescription: json['voiceDescription'] as String,
    dialogueCount: json['dialogueCount'] as int,
    chapters: (json['chapters'] as List).cast<int>(),
    characterId: json['characterId'] as String?,
    revealChapter: json['revealChapter'] as int?,
    voiceId: json['voiceId'] as String?,
  );
}

class PronunciationEntry {
  const PronunciationEntry(this.term, this.pinyin);
  final String term;
  final String pinyin;
  Map<String, Object?> toJson() => {'term': term, 'pinyin': pinyin};
  factory PronunciationEntry.fromJson(Map<String, Object?> json) =>
      PronunciationEntry(json['term'] as String, json['pinyin'] as String);
}

class Cast {
  Cast({
    required this.bookId,
    this.profiledThrough = 0,
    List<Speaker> speakers = const [],
    List<PronunciationEntry> lexicon = const [],
    Map<String, String> redirects = const {},
  }) : speakers = List.unmodifiable(speakers),
       lexicon = List.unmodifiable(lexicon),
       redirects = Map.unmodifiable(redirects);
  final String bookId;
  final int profiledThrough;
  final List<Speaker> speakers;
  final List<PronunciationEntry> lexicon;
  final Map<String, String> redirects;
  Speaker speaker(String id) => speakers.firstWhere(
    (s) => s.id == (redirects[id] ?? id),
    orElse: () => throw StateError('Speaker not found.'),
  );
  Speaker? findSpeaker(String reference) {
    reference = redirects[reference] ?? reference;
    for (final speaker in speakers) {
      if (speaker.id == reference) return speaker;
    }
    for (final speaker in speakers) {
      if (speaker.name == reference || speaker.aliases.contains(reference)) {
        return speaker;
      }
    }
    return null;
  }

  Cast copyWith({
    int? profiledThrough,
    List<Speaker>? speakers,
    List<PronunciationEntry>? lexicon,
    Map<String, String>? redirects,
  }) => Cast(
    bookId: bookId,
    profiledThrough: profiledThrough ?? this.profiledThrough,
    speakers: speakers ?? this.speakers,
    lexicon: lexicon ?? this.lexicon,
    redirects: redirects ?? this.redirects,
  );
  Map<String, Object?> toJson() => {
    'bookId': bookId,
    'profiledThrough': profiledThrough,
    'redirects': redirects,
    'speakers': speakers.map((s) => s.toJson()).toList(),
    'lexicon': lexicon.map((e) => e.toJson()).toList(),
  };
  factory Cast.fromJson(Map<String, Object?> json) => Cast(
    bookId: json['bookId'] as String,
    profiledThrough: json['profiledThrough'] as int,
    redirects: Map<String, String>.from(json['redirects'] as Map? ?? {}),
    speakers: (json['speakers'] as List)
        .map((s) => Speaker.fromJson(Map<String, Object?>.from(s as Map)))
        .toList(),
    lexicon: (json['lexicon'] as List)
        .map(
          (e) =>
              PronunciationEntry.fromJson(Map<String, Object?>.from(e as Map)),
        )
        .toList(),
  );
}

/// Typed cast persistence shared by profiling, directing and casting.
class CastRepository {
  CastRepository(this.store);
  final LocalStore store;
  Future<Cast> get(String bookId) async {
    final json = await store.get('casts', bookId);
    return json == null
        ? Cast(
            bookId: bookId,
            speakers: [
              Speaker(
                id: 'narrator',
                name: 'Narrator',
                kind: SpeakerKind.narrator,
              ),
            ],
          )
        : Cast.fromJson(json);
  }

  Future<void> save(Cast cast) =>
      store.put('casts', cast.bookId, cast.toJson());
}
