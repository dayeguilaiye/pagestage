import 'package:flutter/foundation.dart';

/// Local diagnostic export and user-initiated external feedback.
abstract interface class Diagnostics {
  /// Exports a sanitized local report through the system share sheet.
  Future<void> export();

  /// Opens this project's new GitHub issue page in the system browser.
  Future<void> feedback();

  /// Journals why generation paused, using fixed categories only.
  Future<void> recordPause({
    required String provider,
    required String task,
    required String reason,
    String? code,
  });
}

/// Application capabilities consumed by screens and their test doubles.
abstract interface class Listening implements ValueListenable<ListeningState> {
  Future<void> open(String bookId, {int? chapter, int? line});
  Future<void> play();
  Future<void> pause();
  Future<void> previousLine();
  Future<void> nextLine();
  Future<void> previousChapter();
  Future<void> nextChapter();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  void setSleepTimer(Duration? duration);
  void setSleepAfterChapter(bool enabled);
  Future<List<ListeningLine>> lines(String bookId, int chapter);
  Future<ListeningBookmark?> bookmark(String bookId);
}

enum ListeningSource { synthesized, system }

class ListeningState {
  const ListeningState({
    this.bookId,
    this.bookTitle = '',
    this.chapter = 1,
    this.chapterTitle = '',
    this.chapterCount = 0,
    this.line = 0,
    this.lineCount = 0,
    this.lineRevision = 0,
    this.activeLines = const [],
    this.playing = false,
    this.buffering = false,
    this.source = ListeningSource.synthesized,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.durationComplete = true,
    this.speed = 1,
    this.sleepRemaining,
    this.sleepAfterChapter = false,
    this.error,
  });
  final String? bookId;
  final String bookTitle;
  final int chapter;
  final String chapterTitle;
  final int chapterCount;
  final int line;
  final int lineCount;

  /// Changes when authoritative line segmentation/source changes.
  final int lineRevision;
  final List<int> activeLines;
  final bool playing;
  final bool buffering;
  final ListeningSource source;
  final Duration position;
  final Duration duration;

  /// A growing playlist's duration covers only its available audio.
  final bool durationComplete;
  final double speed;
  final Duration? sleepRemaining;
  final bool sleepAfterChapter;

  /// Stable, non-sensitive error code; the screen supplies localized text.
  final String? error;
  double get progress => error == 'endOfBook'
      ? 1
      : (source == ListeningSource.system || !durationComplete) && lineCount > 0
      ? (line / lineCount).clamp(0, 1)
      : duration.inMicroseconds <= 0
      ? 0
      : (position.inMicroseconds / duration.inMicroseconds).clamp(0, 1);
}

class ListeningLine {
  const ListeningLine({
    required this.index,
    required this.text,
    required this.start,
    required this.end,
    this.speakerName,
    this.nonStory = false,
  });
  final int index;
  final String text;
  final int start;
  final int end;
  final String? speakerName;
  final bool nonStory;
}

class ListeningBookmark {
  const ListeningBookmark({
    required this.bookId,
    required this.chapter,
    required this.line,
    required this.progress,
    this.sourceOffset,
  });
  final String bookId;
  final int chapter;
  final int line;
  final double progress;
  final int? sourceOffset;
}

enum LlmProtocol { chatCompletions, responses }

enum ProviderRegion { beijing, singapore }

class ProviderPreferences {
  const ProviderPreferences({
    this.baseUrl = 'https://api.openai.com/v1',
    this.protocol = LlmProtocol.chatCompletions,
    this.profileModel = '',
    this.directorModel = '',
    this.region = ProviderRegion.beijing,
    this.hasLlmKey = false,
    this.hasMinimaxKey = false,
    this.hasBailianKey = false,
  });
  final String baseUrl;
  final LlmProtocol protocol;
  final String profileModel;

  /// An empty value uses profileModel.
  final String directorModel;
  final ProviderRegion region;
  final bool hasLlmKey;
  final bool hasMinimaxKey;
  final bool hasBailianKey;
}

abstract interface class Providers
    implements ValueListenable<ProviderPreferences> {
  /// Null retains a stored key; an empty string removes it. Keys are never
  /// returned by this interface or included in preferences.
  Future<void> save(
    ProviderPreferences preferences, {
    String? llmKey,
    String? minimaxKey,
    String? bailianKey,
  });
}

class ConsentRequest {
  const ConsentRequest({
    required this.id,
    required this.bookTitle,
    required this.provider,
    required this.endpoint,
    required this.content,
  });
  final int id;
  final String bookTitle;
  final String provider;
  final String endpoint;

  /// Semantic category: chapterTextAndCast or voiceSample.
  final String content;
}

abstract interface class Consents implements ValueListenable<ConsentRequest?> {
  void respond(int requestId, {required bool accepted});
}

enum ProfilingStatus { idle, queued, running, paused, complete }

enum CastMemberKind { narrator, character, persona, provisional }

class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    required this.kind,
    this.gender = '',
    this.ageGroup = '',
    this.personality = '',
    this.speakingStyle = '',
    this.voiceDescription = '',
    this.voiceName,
    this.provider,
  });
  final String id;
  final String name;
  final CastMemberKind kind;
  final String gender;
  final String ageGroup;
  final String personality;
  final String speakingStyle;
  final String voiceDescription;
  final String? voiceName;
  final String? provider;
}

class CastState {
  const CastState({
    required this.bookId,
    this.profiledThrough = 0,
    this.targetChapter = 0,
    this.chapterCount = 0,
    this.status = ProfilingStatus.idle,
    this.provider,
    this.reason,
    this.skippedChapters = const [],
    this.members = const [],
  });
  final String bookId;
  final int profiledThrough;
  final int targetChapter;
  final int chapterCount;
  final ProfilingStatus status;
  final String? provider;
  final String? reason;

  /// Profiled chapters the provider would not process, in order.
  final List<int> skippedChapters;
  final List<CastMember> members;
}

abstract interface class Casts implements Listenable {
  int get exclusiveCount;

  /// Speaker whose audition is currently playing; clears on end or stop.
  String? get auditioning;
  Future<CastState> load(String bookId);
  Future<void> profile(String bookId, {required int through});
  Future<void> resume(String bookId);
  Future<void> audition(String bookId, String speakerId);
  Future<void> stopAudition();
  Future<void> setExclusiveCount(int count);
}

enum BookPerformanceMode { audiobook, drama }

enum GenerationChoice { generate, system, cancel }

class GenerationPreferences {
  const GenerationPreferences({
    this.automatic = false,
    this.directing = 2,
    this.synthesis = 1,
  });
  final bool automatic;
  final int directing;
  final int synthesis;
}

class GenerationRequest {
  const GenerationRequest({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.chapter,
    required this.canGenerate,
  });
  final int id;
  final String bookId;
  final String bookTitle;
  final int chapter;
  final bool canGenerate;
}

class GenerationFailure {
  const GenerationFailure({
    required this.bookId,
    required this.chapter,
    required this.provider,
    required this.reason,
  });
  final String bookId;
  final int chapter;
  final String provider;

  /// Uses the same safe reason codes as CastState.reason.
  final String reason;
}

class GenerationState {
  const GenerationState({
    this.preferences = const GenerationPreferences(),
    this.request,
    this.failures = const [],
  });
  final GenerationPreferences preferences;
  final GenerationRequest? request;
  final List<GenerationFailure> failures;
}

abstract interface class Generation
    implements ValueListenable<GenerationState> {
  Future<void> savePreferences(GenerationPreferences preferences);
  void respond(int requestId, GenerationChoice choice);
  Future<BookPerformanceMode> mode(String bookId);
  Future<void> setMode(String bookId, BookPerformanceMode mode);
  Future<void> resume(String bookId);
}

class VoiceOption {
  const VoiceOption({
    required this.id,
    required this.name,
    required this.provider,
    this.description = '',
    this.selected = false,
  });
  final String id;
  final String name;
  final String provider;
  final String description;
  final bool selected;
}

class VoiceRebuildNotice {
  const VoiceRebuildNotice({
    required this.id,
    required this.bookId,
    required this.speakerId,
    required this.speakerName,
    required this.provider,
  });
  final String id;
  final String bookId;
  final String speakerId;
  final String speakerName;
  final String provider;
}

abstract interface class Voices implements Listenable {
  /// ID of a playing preset or candidate; null after playback completes/stops.
  String? get auditioning;
  List<VoiceRebuildNotice> get notices;
  Future<List<VoiceOption>> presets(String bookId, String speakerId);
  Future<void> auditionPreset(String bookId, String speakerId, String presetId);
  Future<void> selectPreset(String bookId, String speakerId, String presetId);

  /// Provider names supporting design for the current configuration and region.
  Future<List<String>> designProviders(String bookId);
  Future<List<VoiceOption>> candidates(String bookId, String speakerId);
  Future<List<VoiceOption>> design(
    String bookId,
    String speakerId, {
    required String provider,
    required String description,
  });
  Future<void> auditionCandidate(
    String bookId,
    String speakerId,
    String candidateId,
  );
  Future<void> selectCandidate(
    String bookId,
    String speakerId,
    String candidateId,
  );
  Future<void> stopAudition();
  Future<void> dismissNotice(String id);
}

class BookStorageUsage {
  const BookStorageUsage({
    required this.bookId,
    required this.title,
    required this.totalBytes,
    required this.audioBytes,
  });
  final String bookId;
  final String title;

  /// Encoded book-owned records plus owned files; excludes shared SQLite overhead.
  final int totalBytes;

  /// Bytes released by clearAudio, including speech, previews and synthesis cache.
  final int audioBytes;
}

abstract interface class AudioStorage implements Listenable {
  Future<List<BookStorageUsage>> usage();
  Future<void> clearAudio(String bookId);
}
