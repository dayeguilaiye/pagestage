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
    this.speakerId,
    this.speakerName,
    this.nonStory = false,
    this.directed = false,
  });
  final int index;
  final String text;
  final int start;
  final int end;
  final String? speakerId;
  final String? speakerName;
  final bool nonStory;

  /// A line of the chapter's script, so [index] is a script line index;
  /// false for sentences split for the system voice.
  final bool directed;
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

/// What an engine does for a book.
enum EngineKind { language, voice }

enum EngineSite { cloud, device }

/// Whether an engine can be used as configured.
enum EngineStatus {
  ready,

  /// A required setting, such as a key, is missing.
  needsSetup,

  /// Its model has not been installed on this device.
  notInstalled,

  /// Not offered in this build.
  unavailable,
}

enum EngineSettingKind { secret, text, choice }

/// One setting an engine asks the reader for.
class EngineSetting {
  const EngineSetting({
    required this.name,
    required this.kind,
    this.options = const [],
    this.fallback,
    this.required = false,
  });

  /// Stable name, such as key, region or baseUrl; screens label it.
  final String name;
  final EngineSettingKind kind;
  final List<String> options;

  /// The value in use while nothing is stored.
  final String? fallback;
  final bool required;
}

/// What a voice engine can perform beyond reading in a voice, for the
/// labels that tell engines apart.
enum EngineTrait { emotion, instruction, vocalCues, pacing, voiceDesign }

/// An engine as screens see it. Secrets never appear, only which are stored.
class EngineView {
  const EngineView({
    required this.id,
    required this.kind,
    required this.site,
    this.status = EngineStatus.ready,
    this.on = false,
    this.settings = const [],
    this.values = const {},
    this.secrets = const {},
    this.traits = const {},
    this.voiceCount = 0,
  });
  final String id;
  final EngineKind kind;
  final EngineSite site;
  final EngineStatus status;

  /// A voice engine's switch; for a language engine, whether it is the one
  /// in use.
  final bool on;
  final List<EngineSetting> settings;

  /// Stored values of the settings that are not secret.
  final Map<String, String> values;

  /// Names of the secret settings that have a stored value.
  final Set<String> secrets;
  final Set<EngineTrait> traits;

  /// Preset voices offered under the current settings.
  final int voiceCount;

  bool get ready => status == EngineStatus.ready;

  /// The stored or default value of setting [name].
  String value(String name) =>
      values[name] ??
      settings.where((s) => s.name == name).firstOrNull?.fallback ??
      '';
}

class ProviderPreferences {
  const ProviderPreferences({this.engines = const []});

  /// Every engine of this build, language engines first, each kind in the
  /// order screens list it.
  final List<EngineView> engines;

  EngineView? engine(String id) => engines.where((e) => e.id == id).firstOrNull;
  Iterable<EngineView> get languageEngines =>
      engines.where((e) => e.kind == EngineKind.language);
  Iterable<EngineView> get voiceEngines =>
      engines.where((e) => e.kind == EngineKind.voice);

  /// The language engine in use.
  EngineView? get language => languageEngines.where((e) => e.on).firstOrNull;

  /// Whether profiling and directing can run.
  bool get llmReady => language?.ready ?? false;

  /// The voice engines casting, voices and synthesis may use: switched on
  /// and ready.
  Set<String> get voiceProviders => {
    for (final engine in voiceEngines)
      if (engine.on && engine.ready) engine.id,
  };

  /// Whether [engineId]'s switch can be turned on: it has what it needs.
  bool canSwitchOn(String engineId) => engine(engineId)?.ready ?? false;
}

abstract interface class Providers
    implements ValueListenable<ProviderPreferences> {
  /// Saves settings of [engineId]. In [secrets] an empty string removes the
  /// stored value and an absent name keeps it; secrets are never returned.
  /// Storing a secret turns a voice engine's switch on.
  Future<void> configure(
    String engineId, {
    Map<String, String> values = const {},
    Map<String, String> secrets = const {},
  });

  /// Turns a voice engine's switch.
  Future<void> switchVoice(String engineId, bool on);

  /// Chooses the language engine that profiles and directs.
  Future<void> selectLanguage(String engineId);
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

  /// Recasts the speakers whose voices belong to providers now switched off
  /// or without a key, choosing among the providers still on. Voices chosen
  /// by hand or designed are replaced too; every other voice stays.
  Future<void> rematch(String bookId);
}

enum BookPerformanceMode { audiobook, drama }

/// How much of the director's performance a book asks of its voices.
enum BookExpressiveness { plain, natural, dramatic }

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

/// Where a chapter stands while its generation is under way.
enum ChapterStage { queued, directing, voicing, paused }

/// A chapter with directing or voicing still ahead, in its book's mode.
class ChapterProgress {
  const ChapterProgress({
    required this.bookId,
    required this.chapter,
    required this.stage,
    this.directed = false,
    this.voiced = 0,
    this.total = 0,
    this.unvoiced = const {},
    this.since,
  });
  final String bookId;
  final int chapter;
  final ChapterStage stage;

  /// Whether the script exists, so [unvoiced] indexes its lines. Until then
  /// none of the chapter has a voice.
  final bool directed;

  /// Script lines voiced so far, out of [total] that will have a voice.
  final int voiced;
  final int total;

  /// Script line indices still waiting for their voice.
  final Set<int> unvoiced;

  /// When directing started, for showing the time it has taken.
  final DateTime? since;
}

/// Every chapter with generation under way. Chapters not listed are either
/// untouched or finished, and look the same as each other.
class GenerationProgress {
  const GenerationProgress([this.chapters = const []]);
  final List<ChapterProgress> chapters;

  ChapterProgress? of(String bookId, int chapter) {
    for (final progress in chapters) {
      if (progress.bookId == bookId && progress.chapter == chapter) {
        return progress;
      }
    }
    return null;
  }
}

abstract interface class Generation
    implements ValueListenable<GenerationState> {
  /// Kept apart from [value] because it changes with every voiced line.
  ValueListenable<GenerationProgress> get progress;
  Future<void> savePreferences(GenerationPreferences preferences);
  void respond(int requestId, GenerationChoice choice);
  Future<BookPerformanceMode> mode(String bookId);
  Future<void> setMode(String bookId, BookPerformanceMode mode);
  Future<BookExpressiveness> expressiveness(String bookId);

  /// Chapters already voiced are voiced again the next time they are heard;
  /// lines whose delivery does not change come from the cache.
  Future<void> setExpressiveness(String bookId, BookExpressiveness value);
  Future<void> resume(String bookId);

  /// Directs and voices chapters [first]..[through] ahead of listening, in
  /// the book's mode. Finished chapters are skipped; the range must already
  /// be profiled.
  Future<void> prepare(
    String bookId, {
    required int first,
    required int through,
  });
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

/// What of a book can be packed for another device or another reader.
class PackageContents {
  const PackageContents({this.scriptChapters = 0, this.audioChapters = 0});

  /// Chapters with a current script.
  final int scriptChapters;

  /// Chapters fully voiced in the book's performance mode.
  final int audioChapters;
}

/// Sharing a book's scripts and audio as one file.
abstract interface class Packages {
  Future<PackageContents> contents(String bookId);

  /// Packs the book and hands the file to the system share sheet. With
  /// [audio] the voiced chapters travel too; otherwise only the text, cast
  /// and scripts.
  Future<void> share(String bookId, {required bool audio});
}

/// The reader's corrections to a directed chapter.
abstract interface class Scripts {
  /// Whether [chapter]'s audio arrived in an audio package, so correcting
  /// a line voices the whole chapter again with this device's voices.
  Future<bool> hasImportedAudio(String bookId, int chapter);

  /// Gives script line [line] of [chapter] to [speakerId]. The chapter is
  /// voiced again when next heard; unchanged lines come from the cache.
  Future<void> reassign(String bookId, int chapter, int line, String speakerId);
}
