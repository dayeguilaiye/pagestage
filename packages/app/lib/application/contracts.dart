import 'package:flutter/foundation.dart';

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
    this.activeLines = const [],
    this.playing = false,
    this.buffering = false,
    this.source = ListeningSource.synthesized,
    this.position = Duration.zero,
    this.duration = Duration.zero,
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
  final List<int> activeLines;
  final bool playing;
  final bool buffering;
  final ListeningSource source;
  final Duration position;
  final Duration duration;
  final double speed;
  final Duration? sleepRemaining;
  final bool sleepAfterChapter;

  /// Stable, non-sensitive error code; the screen supplies localized text.
  final String? error;
  double get progress => error == 'endOfBook'
      ? 1
      : source == ListeningSource.system && lineCount > 0
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
  });
  final String bookId;
  final int chapter;
  final int line;
  final double progress;
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
    this.members = const [],
  });
  final String bookId;
  final int profiledThrough;
  final int targetChapter;
  final int chapterCount;
  final ProfilingStatus status;
  final String? provider;
  final String? reason;
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
