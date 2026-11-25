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

  /// Stops waiting for AI voices: the system voice reads the rest of this
  /// chapter from the current line.
  Future<void> useSystemVoice();
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
    this.aiVoice = false,
    this.fallback = false,
    this.waitingSince,
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

  /// Whether this book uses AI voices and can: chapters without them yet
  /// are being prepared while the system voice reads.
  final bool aiVoice;

  /// The system voice is reading a chapter whose AI voices were not ready
  /// in time; the next chapter tries them again.
  final bool fallback;

  /// When playback started waiting for AI voices; null while not waiting.
  final DateTime? waitingSince;
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
    this.listenedAt,
  });
  final String bookId;
  final int chapter;
  final int line;
  final double progress;
  final int? sourceOffset;

  /// When the book was last heard; null for bookmarks saved before this
  /// was kept.
  final DateTime? listenedAt;
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
  const ProviderPreferences({
    this.engines = const [],
    this.secretsUnavailable = false,
  });

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

  /// Stored keys could not be read, such as when the system keychain is
  /// unavailable; engines that need them show as not set up.
  final bool secretsUnavailable;
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

  /// Where [engineId] sends book text as configured now; null for an engine
  /// that keeps it on the device or is not set up enough to say.
  Future<String?> endpoint(String engineId);

  /// Tries [engineId] with the stored settings overlaid by the unsaved
  /// [values] and [secrets], with one tiny request carrying no book text.
  /// Null when it answered as needed; otherwise the same reason codes a
  /// paused task reports, such as unauthorized or schemaUnsupported.
  Future<String?> test(
    String engineId, {
    Map<String, String> values = const {},
    Map<String, String> secrets = const {},
  });
}

class ConsentRequest {
  const ConsentRequest({
    required this.id,
    this.bookTitle,
    required this.provider,
    required this.endpoint,
    required this.content,
  });
  final int id;

  /// The book about to be sent; null when asked while setting up.
  final String? bookTitle;
  final String provider;
  final String endpoint;

  /// Semantic category: chapterTextAndCast or voiceSample.
  final String content;
}

/// A provider the reader agreed to send book text to.
class ConsentRecord {
  const ConsentRecord({required this.provider, required this.endpoint});
  final String provider;
  final String endpoint;
}

abstract interface class Consents implements ValueListenable<ConsentRequest?> {
  void respond(int requestId, {required bool accepted});

  /// Asks once per provider and address; true at once when already agreed.
  /// [bookTitle] is null when asked while setting a provider up.
  Future<bool> request({
    String? bookTitle,
    required String provider,
    required String endpoint,
    required String content,
  });

  /// Every agreement the reader has given, for reviewing and withdrawing.
  Future<List<ConsentRecord>> records();

  /// Withdraws an agreement; generation that needs it pauses and asks again.
  Future<void> revoke(ConsentRecord record);
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
    this.firstChapter,
    this.spoken = false,
  });
  final String id;
  final String name;
  final CastMemberKind kind;

  /// The first chapter the speaker appears in, when known.
  final int? firstChapter;

  /// Whether a chapter voiced with the current voices has a line of theirs,
  /// so an audition needs no provider at all.
  final bool spoken;
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

/// How a chapter without AI voices is heard: they are prepared while
/// playback waits, or the system voice reads it.
enum GenerationChoice { generate, system }

class GenerationPreferences {
  const GenerationPreferences({
    this.enabled = true,
    this.automatic = true,
    this.ahead = 1,
  });

  /// AI voices for the whole app. Off, every book reads in the system voice
  /// and no book text is sent anywhere.
  final bool enabled;

  /// Whether books the reader has not decided for use AI voices.
  final bool automatic;

  /// Chapters prepared ahead of the listener.
  final int ahead;

  static const maxAhead = 10;

  /// Scripts are written one chapter further ahead than audio is made.
  int get directing => ahead == 0 ? 0 : ahead + 1;
  int get synthesis => ahead;

  GenerationPreferences copyWith({
    bool? enabled,
    bool? automatic,
    int? ahead,
  }) => GenerationPreferences(
    enabled: enabled ?? this.enabled,
    automatic: automatic ?? this.automatic,
    ahead: ahead ?? this.ahead,
  );
}

/// What a book still needs before its AI voices can be prepared.
enum VoiceSetupGap { languageModel, voiceEngine }

/// Where a book stands with its AI voices, for the book page and player.
class BookVoice {
  const BookVoice({
    required this.bookId,
    this.ai = false,
    this.chosen = false,
    this.enabled = true,
    this.gap,
    this.sample = false,
    this.profiledThrough = 0,
    this.chapterCount = 0,
    this.profileNeeded,
  });
  final String bookId;

  /// The book's choice: AI voices, or the system voice throughout.
  final bool ai;

  /// Whether the reader chose for this book rather than the default.
  final bool chosen;

  /// AI voices are on for the app.
  final bool enabled;

  /// What is missing before AI voices can be prepared; null when nothing.
  final VoiceSetupGap? gap;

  /// A bundled example, voiced in advance; its performance is fixed.
  final bool sample;
  final int profiledThrough;
  final int chapterCount;

  /// A chapter listened to so far past the characters found so far that
  /// finding them first waits for the reader's go-ahead.
  final int? profileNeeded;

  /// Whether chapters without AI voices get them as they are listened to.
  bool get active => ai && enabled && gap == null && !sample;
}

class GenerationFailure {
  const GenerationFailure({
    required this.bookId,
    required this.chapter,
    required this.provider,
    required this.reason,
    this.profiling = false,
  });
  final String bookId;
  final int chapter;
  final String provider;

  /// Uses the same safe reason codes as CastState.reason.
  final String reason;

  /// Finding the book's characters paused, which holds every chapter
  /// after it.
  final bool profiling;
}

class GenerationState {
  const GenerationState({
    this.preferences = const GenerationPreferences(),
    this.failures = const [],
  });
  final GenerationPreferences preferences;
  final List<GenerationFailure> failures;
}

/// Where a chapter stands while its generation is under way: waiting its
/// turn, waiting for the characters up to it to be found, being directed,
/// being voiced, or paused.
enum ChapterStage { queued, profiling, directing, voicing, paused }

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

/// What providers reported spending on one book, in their own units:
/// nothing here is estimated.
class BookUsage {
  const BookUsage({
    required this.bookId,
    this.tokens = 0,
    this.characters = const {},
    this.requests = 0,
  });

  /// Empty for spending recorded before it was kept per book.
  final String bookId;

  /// Language model tokens, in and out.
  final int tokens;

  /// Characters voiced, by voice provider.
  final Map<String, int> characters;

  /// Billable responses.
  final int requests;
}

abstract interface class Generation
    implements ValueListenable<GenerationState> {
  /// What providers reported spending, per book, most first.
  Future<List<BookUsage>> usage();

  /// The bundled example books, which come voiced and stay as they are.
  Future<Set<String>> samples();

  /// Kept apart from [value] because it changes with every voiced line.
  ValueListenable<GenerationProgress> get progress;
  Future<void> savePreferences(GenerationPreferences preferences);
  Future<BookPerformanceMode> mode(String bookId);
  Future<void> setMode(String bookId, BookPerformanceMode mode);
  Future<BookExpressiveness> expressiveness(String bookId);

  /// Chapters already voiced are voiced again the next time they are heard;
  /// lines whose delivery does not change come from the cache.
  Future<void> setExpressiveness(String bookId, BookExpressiveness value);

  /// Resumes the book's paused work, asking again for any agreement the
  /// reader has not given.
  Future<void> resume(String bookId);

  /// Where [bookId] stands with its AI voices.
  Future<BookVoice> voice(String bookId);

  /// AI voices for this book, or the system voice throughout. Turning them
  /// off drops the book's queued work; voices already made still play.
  Future<void> setAiVoice(String bookId, bool on);

  /// Asks for the agreements AI voices for [bookId] need: sending its text
  /// to the language model and to each voice engine in use. False when the
  /// reader declines one.
  Future<bool> allow(String bookId);

  /// Drops the book's queued work. While it is listened to with AI voices
  /// on, the chapters just ahead are still prepared.
  Future<void> stopPreparing(String bookId);

  /// Finds the characters through [chapter] after the reader agreed to the
  /// wait, when listening jumped far past the profiled chapters.
  Future<void> profileThrough(String bookId, int chapter);

  /// Directs and voices chapters [first]..[through] ahead of listening, in
  /// the book's mode. Finished chapters are skipped; chapters not profiled
  /// yet are profiled first.
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
