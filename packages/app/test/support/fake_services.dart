import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/app.dart';
import 'package:pagestage_app/application/app_services.dart';
import 'package:pagestage_app/shelf/bookshelf.dart';
import 'package:pagestage_app/shelf/reading_settings.dart';

/// Records every command; tests set [value] to stand for the engine.
class FakeListening extends ValueNotifier<ListeningState> implements Listening {
  FakeListening([super.value = const ListeningState()]);

  final calls = <String>[];
  final opens = <(String, int?, int?)>[];
  final seeks = <Duration>[];
  final speeds = <double>[];
  final sleepTimers = <Duration?>[];
  final sleepAfterChapter = <bool>[];
  final chapterLines = <(String, int), List<ListeningLine>>{};
  final bookmarks = <String, ListeningBookmark>{};

  @override
  Future<void> open(String bookId, {int? chapter, int? line}) async {
    calls.add('open');
    opens.add((bookId, chapter, line));
  }

  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> previousLine() async => calls.add('previousLine');
  @override
  Future<void> nextLine() async => calls.add('nextLine');
  @override
  Future<void> previousChapter() async => calls.add('previousChapter');
  @override
  Future<void> nextChapter() async => calls.add('nextChapter');

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek');
    seeks.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    calls.add('setSpeed');
    speeds.add(speed);
  }

  @override
  void setSleepTimer(Duration? duration) {
    calls.add('setSleepTimer');
    sleepTimers.add(duration);
  }

  @override
  void setSleepAfterChapter(bool enabled) {
    calls.add('setSleepAfterChapter');
    sleepAfterChapter.add(enabled);
  }

  /// Replaces [chapterLines] when set, to control when each answer arrives.
  Future<List<ListeningLine>> Function(String bookId, int chapter)? onLines;

  @override
  Future<List<ListeningLine>> lines(String bookId, int chapter) async =>
      await onLines?.call(bookId, chapter) ??
      chapterLines[(bookId, chapter)] ??
      const [];

  @override
  Future<ListeningBookmark?> bookmark(String bookId) async => bookmarks[bookId];
}

const _llmSettings = [
  EngineSetting(
    name: 'baseUrl',
    kind: EngineSettingKind.text,
    fallback: 'https://api.openai.com/v1',
  ),
  EngineSetting(
    name: 'api',
    kind: EngineSettingKind.choice,
    options: ['chat-completions', 'responses'],
    fallback: 'chat-completions',
  ),
  EngineSetting(name: 'key', kind: EngineSettingKind.secret, required: true),
  EngineSetting(
    name: 'profileModel',
    kind: EngineSettingKind.text,
    required: true,
  ),
  EngineSetting(name: 'directorModel', kind: EngineSettingKind.text),
];
const _keySetting = EngineSetting(
  name: 'key',
  kind: EngineSettingKind.secret,
  required: true,
);

/// The engines a build lists, as screens see them: the cloud language
/// model, MiniMax, Bailian and Edge, with the two on-device slots that are
/// not offered yet.
List<EngineView> fakeEngines({
  bool llmKey = false,
  String profileModel = '',
  String directorModel = '',
  String? baseUrl,
  String? api,
  bool minimaxKey = false,
  bool minimaxOn = true,
  bool bailianKey = false,
  bool bailianOn = true,
  String region = 'beijing',
  bool edgeOn = false,
}) => [
  EngineView(
    id: 'llm',
    kind: EngineKind.language,
    site: EngineSite.cloud,
    status: llmKey && profileModel.isNotEmpty
        ? EngineStatus.ready
        : EngineStatus.needsSetup,
    on: true,
    settings: _llmSettings,
    values: {
      'baseUrl': ?baseUrl,
      'api': ?api,
      if (profileModel.isNotEmpty) 'profileModel': profileModel,
      if (directorModel.isNotEmpty) 'directorModel': directorModel,
    },
    secrets: {if (llmKey) 'key'},
  ),
  const EngineView(
    id: 'llm-device',
    kind: EngineKind.language,
    site: EngineSite.device,
    status: EngineStatus.unavailable,
  ),
  EngineView(
    id: 'minimax',
    kind: EngineKind.voice,
    site: EngineSite.cloud,
    status: minimaxKey ? EngineStatus.ready : EngineStatus.needsSetup,
    on: minimaxOn,
    settings: const [_keySetting],
    secrets: {if (minimaxKey) 'key'},
    traits: const {
      EngineTrait.emotion,
      EngineTrait.vocalCues,
      EngineTrait.pacing,
      EngineTrait.voiceDesign,
    },
    voiceCount: 58,
  ),
  EngineView(
    id: 'bailian',
    kind: EngineKind.voice,
    site: EngineSite.cloud,
    status: bailianKey ? EngineStatus.ready : EngineStatus.needsSetup,
    on: bailianOn,
    settings: const [
      EngineSetting(
        name: 'region',
        kind: EngineSettingKind.choice,
        options: ['beijing', 'singapore'],
        fallback: 'beijing',
      ),
      _keySetting,
    ],
    values: {if (region != 'beijing') 'region': region},
    secrets: {if (bailianKey) 'key'},
    traits: {
      EngineTrait.instruction,
      EngineTrait.vocalCues,
      if (region == 'beijing') EngineTrait.voiceDesign,
    },
    voiceCount: 42,
  ),
  EngineView(
    id: 'edge',
    kind: EngineKind.voice,
    site: EngineSite.cloud,
    on: edgeOn,
    traits: const {EngineTrait.pacing},
    voiceCount: 17,
  ),
  const EngineView(
    id: 'device',
    kind: EngineKind.voice,
    site: EngineSite.device,
    status: EngineStatus.unavailable,
  ),
];

/// One call to [FakeProviders.configure].
class ConfigureCall {
  ConfigureCall(this.engineId, this.values, this.secrets);
  final String engineId;
  final Map<String, String> values;
  final Map<String, String> secrets;
}

class FakeProviders extends ValueNotifier<ProviderPreferences>
    implements Providers {
  FakeProviders([List<EngineView>? engines])
    : super(ProviderPreferences(engines: engines ?? fakeEngines()));

  final configures = <ConfigureCall>[];
  final switches = <(String, bool)>[];
  final selections = <String>[];

  /// Thrown by every change while set; nothing is saved.
  Object? failWith;

  void _replace(String id, EngineView Function(EngineView) change) {
    value = ProviderPreferences(
      engines: [
        for (final engine in value.engines)
          engine.id == id ? change(engine) : engine,
      ],
    );
  }

  static EngineView _with(
    EngineView e, {
    bool? on,
    Map<String, String>? values,
    Set<String>? secrets,
  }) {
    final stored = secrets ?? e.secrets;
    final next = values ?? e.values;
    final complete = e.settings
        .where((s) => s.required)
        .every(
          (s) => s.kind == EngineSettingKind.secret
              ? stored.contains(s.name)
              : (next[s.name] ?? '').isNotEmpty,
        );
    return EngineView(
      id: e.id,
      kind: e.kind,
      site: e.site,
      status: e.status == EngineStatus.unavailable
          ? e.status
          : complete
          ? EngineStatus.ready
          : EngineStatus.needsSetup,
      on: on ?? e.on,
      settings: e.settings,
      values: next,
      secrets: stored,
      traits: e.traits,
      voiceCount: e.voiceCount,
    );
  }

  @override
  Future<void> configure(
    String engineId, {
    Map<String, String> values = const {},
    Map<String, String> secrets = const {},
  }) async {
    configures.add(ConfigureCall(engineId, values, secrets));
    if (failWith case final error?) throw error;
    _replace(engineId, (engine) {
      final stored = {...engine.secrets};
      for (final entry in secrets.entries) {
        entry.value.isEmpty ? stored.remove(entry.key) : stored.add(entry.key);
      }
      final next = {...engine.values};
      for (final entry in values.entries) {
        entry.value.isEmpty
            ? next.remove(entry.key)
            : next[entry.key] = entry.value;
      }
      return _with(
        engine,
        values: next,
        secrets: stored,
        on:
            engine.kind == EngineKind.voice &&
                secrets.values.any((v) => v.isNotEmpty)
            ? true
            : null,
      );
    });
  }

  @override
  Future<void> switchVoice(String engineId, bool on) async {
    switches.add((engineId, on));
    if (failWith case final error?) throw error;
    _replace(engineId, (engine) => _with(engine, on: on));
  }

  @override
  Future<void> selectLanguage(String engineId) async {
    selections.add(engineId);
    if (failWith case final error?) throw error;
    value = ProviderPreferences(
      engines: [
        for (final engine in value.engines)
          engine.kind == EngineKind.language
              ? _with(engine, on: engine.id == engineId)
              : engine,
      ],
    );
  }
}

class FakeConsents extends ValueNotifier<ConsentRequest?> implements Consents {
  FakeConsents() : super(null);

  final responses = <(int, bool)>[];

  @override
  void respond(int requestId, {required bool accepted}) {
    responses.add((requestId, accepted));
    if (value?.id == requestId) value = null;
  }
}

class FakeCasts extends ChangeNotifier implements Casts {
  FakeCasts({CastState? state, this.exclusiveCount = 20})
    : state = state ?? const CastState(bookId: '');

  CastState state;
  @override
  int exclusiveCount;

  final profiles = <(String, int)>[];
  final resumes = <String>[];
  final auditions = <(String, String)>[];
  var stops = 0;

  @override
  String? auditioning;

  void update(CastState next) {
    state = next;
    notifyListeners();
  }

  @override
  Future<CastState> load(String bookId) async => state;

  @override
  Future<void> profile(String bookId, {required int through}) async =>
      profiles.add((bookId, through));

  @override
  Future<void> resume(String bookId) async => resumes.add(bookId);

  @override
  Future<void> audition(String bookId, String speakerId) async {
    auditions.add((bookId, speakerId));
    auditioning = speakerId;
    notifyListeners();
  }

  @override
  Future<void> stopAudition() async {
    stops++;
    auditioning = null;
    notifyListeners();
  }

  final rematches = <String>[];

  /// Thrown by [rematch] while set.
  Object? rematchFailure;

  @override
  Future<void> rematch(String bookId) async {
    if (rematchFailure case final error?) throw error;
    rematches.add(bookId);
  }

  /// Thrown by [setExclusiveCount] while set; the count stays.
  Object? countFailure;

  @override
  Future<void> setExclusiveCount(int count) async {
    if (countFailure case final error?) throw error;
    exclusiveCount = count;
    notifyListeners();
  }
}

class FakeGeneration extends ValueNotifier<GenerationState>
    implements Generation {
  FakeGeneration([super.value = const GenerationState()]);

  final responses = <(int, GenerationChoice)>[];
  final saved = <GenerationPreferences>[];
  final resumes = <String>[];
  final modes = <String, BookPerformanceMode>{};
  final modeChanges = <(String, BookPerformanceMode)>[];
  final expressions = <String, BookExpressiveness>{};
  final expressionChanges = <(String, BookExpressiveness)>[];

  /// Thrown by [setExpressiveness] while set.
  Object? expressionFailure;
  final prepares = <(String, int, int)>[];

  @override
  final ValueNotifier<GenerationProgress> progress = ValueNotifier(
    const GenerationProgress(),
  );

  @override
  Future<void> prepare(
    String bookId, {
    required int first,
    required int through,
  }) async => prepares.add((bookId, first, through));

  /// Thrown by [savePreferences] while set; nothing is saved.
  Object? saveFailure;

  @override
  Future<void> savePreferences(GenerationPreferences preferences) async {
    if (saveFailure case final error?) throw error;
    saved.add(preferences);
    value = GenerationState(
      preferences: preferences,
      request: value.request,
      failures: value.failures,
    );
  }

  @override
  void respond(int requestId, GenerationChoice choice) {
    responses.add((requestId, choice));
    if (value.request?.id == requestId) {
      value = GenerationState(
        preferences: value.preferences,
        failures: value.failures,
      );
    }
  }

  @override
  Future<BookPerformanceMode> mode(String bookId) async =>
      modes[bookId] ?? BookPerformanceMode.audiobook;

  @override
  Future<void> setMode(String bookId, BookPerformanceMode mode) async {
    modeChanges.add((bookId, mode));
    modes[bookId] = mode;
  }

  @override
  Future<BookExpressiveness> expressiveness(String bookId) async =>
      expressions[bookId] ?? BookExpressiveness.natural;

  @override
  Future<void> setExpressiveness(
    String bookId,
    BookExpressiveness value,
  ) async {
    if (expressionFailure case final error?) throw error;
    expressionChanges.add((bookId, value));
    expressions[bookId] = value;
  }

  @override
  Future<void> resume(String bookId) async => resumes.add(bookId);
}

class FakePackages implements Packages {
  FakePackages([this.packageContents = const PackageContents()]);

  PackageContents packageContents;

  /// Each share as (bookId, audio).
  final shares = <(String, bool)>[];

  /// Thrown by [share] while set.
  Object? shareFailure;

  @override
  Future<PackageContents> contents(String bookId) async => packageContents;

  @override
  Future<void> share(String bookId, {required bool audio}) async {
    if (shareFailure case final error?) throw error;
    shares.add((bookId, audio));
  }
}

class FakeScripts implements Scripts {
  /// Chapters whose audio came in a package, as (bookId, chapter).
  final imported = <(String, int)>{};

  /// Each change as (bookId, chapter, line, speakerId).
  final reassignments = <(String, int, int, String)>[];

  /// Thrown by [reassign] while set.
  Object? failure;

  @override
  Future<bool> hasImportedAudio(String bookId, int chapter) async =>
      imported.contains((bookId, chapter));

  @override
  Future<void> reassign(
    String bookId,
    int chapter,
    int line,
    String speakerId,
  ) async {
    if (failure case final error?) throw error;
    reassignments.add((bookId, chapter, line, speakerId));
  }
}

class FakeVoices extends ChangeNotifier implements Voices {
  FakeVoices({
    this.presetOptions = const [],
    this.providers = const [],
    this.savedCandidates = const [],
    this.notices = const [],
  });

  List<VoiceOption> presetOptions;
  List<String> providers;
  List<VoiceOption> savedCandidates;
  @override
  List<VoiceRebuildNotice> notices;

  /// Thrown by [design] while set.
  Object? designFailure;

  @override
  String? auditioning;

  final presetAuditions = <String>[];
  final candidateAuditions = <String>[];
  final selectedPresets = <(String, String, String)>[];
  final selectedCandidates = <(String, String, String)>[];
  final designs = <(String, String)>[];
  final dismissed = <String>[];
  var stops = 0;

  @override
  Future<List<VoiceOption>> presets(String bookId, String speakerId) async =>
      presetOptions;

  @override
  Future<void> auditionPreset(
    String bookId,
    String speakerId,
    String presetId,
  ) async {
    presetAuditions.add(presetId);
    auditioning = presetId;
    notifyListeners();
  }

  @override
  Future<void> selectPreset(
    String bookId,
    String speakerId,
    String presetId,
  ) async => selectedPresets.add((bookId, speakerId, presetId));

  @override
  Future<List<String>> designProviders(String bookId) async => providers;

  @override
  Future<List<VoiceOption>> candidates(String bookId, String speakerId) async =>
      savedCandidates;

  @override
  Future<List<VoiceOption>> design(
    String bookId,
    String speakerId, {
    required String provider,
    required String description,
  }) async {
    designs.add((provider, description));
    if (designFailure case final error?) throw error;
    return savedCandidates = [
      for (var i = 1; i <= 3; i++)
        VoiceOption(id: 'c$i', name: '候选 $i', provider: provider),
    ];
  }

  @override
  Future<void> auditionCandidate(
    String bookId,
    String speakerId,
    String candidateId,
  ) async {
    candidateAuditions.add(candidateId);
    auditioning = candidateId;
    notifyListeners();
  }

  @override
  Future<void> selectCandidate(
    String bookId,
    String speakerId,
    String candidateId,
  ) async => selectedCandidates.add((bookId, speakerId, candidateId));

  @override
  Future<void> stopAudition() async {
    stops++;
    auditioning = null;
    notifyListeners();
  }

  @override
  Future<void> dismissNotice(String id) async {
    dismissed.add(id);
    notices = [
      for (final n in notices)
        if (n.id != id) n,
    ];
    notifyListeners();
  }
}

class FakeAudioStorage extends ChangeNotifier implements AudioStorage {
  FakeAudioStorage([this.books = const []]);

  List<BookStorageUsage> books;
  final cleared = <String>[];

  /// Thrown by [usage] while set.
  Object? usageFailure;

  /// Thrown by [clearAudio] while set; nothing is cleared.
  Object? clearFailure;

  @override
  Future<List<BookStorageUsage>> usage() async {
    if (usageFailure case final error?) throw error;
    return books;
  }

  @override
  Future<void> clearAudio(String bookId) async {
    if (clearFailure case final error?) throw error;
    cleared.add(bookId);
    books = [
      for (final b in books)
        b.bookId == bookId
            ? BookStorageUsage(
                bookId: b.bookId,
                title: b.title,
                totalBytes: b.totalBytes - b.audioBytes,
                audioBytes: 0,
              )
            : b,
    ];
    notifyListeners();
  }
}

/// Each call waits for the test to finish it through [finishExport] or
/// [finishFeedback].
class FakeDiagnostics implements Diagnostics {
  var exports = 0;
  var feedbacks = 0;
  Completer<void>? _export;
  Completer<void>? _feedback;

  @override
  Future<void> export() {
    exports++;
    return (_export = Completer<void>()).future;
  }

  @override
  Future<void> feedback() {
    feedbacks++;
    return (_feedback = Completer<void>()).future;
  }

  @override
  Future<void> recordPause({
    required String provider,
    required String task,
    required String reason,
    String? code,
  }) async {}

  void finishExport([Object? error]) => _finish(_export!, error);
  void finishFeedback([Object? error]) => _finish(_feedback!, error);

  static void _finish(Completer<void> c, Object? error) =>
      error == null ? c.complete() : c.completeError(error);
}

class Fakes {
  Fakes({
    FakeListening? listening,
    FakeProviders? providers,
    FakeConsents? consents,
    FakeCasts? casts,
    FakeGeneration? generation,
    FakeVoices? voices,
    FakeAudioStorage? audioStorage,
    FakePackages? packages,
    FakeScripts? scripts,
    bool withDiagnostics = true,
  }) : diagnostics = withDiagnostics ? FakeDiagnostics() : null,
       packages = packages ?? FakePackages(),
       scripts = scripts ?? FakeScripts(),
       listening = listening ?? FakeListening(),
       providers = providers ?? FakeProviders(),
       consents = consents ?? FakeConsents(),
       casts = casts ?? FakeCasts(),
       generation = generation ?? FakeGeneration(),
       voices = voices ?? FakeVoices(),
       audioStorage = audioStorage ?? FakeAudioStorage();

  final FakeListening listening;
  final FakeProviders providers;
  final FakeConsents consents;
  final FakeCasts casts;
  final FakeGeneration generation;
  final FakeVoices voices;
  final FakeAudioStorage audioStorage;
  final FakePackages packages;
  final FakeScripts scripts;
  final FakeDiagnostics? diagnostics;

  late final services = AppServices(
    diagnostics: diagnostics,
    listening: listening,
    providers: providers,
    consents: consents,
    casts: casts,
    generation: generation,
    voices: voices,
    audioStorage: audioStorage,
    packages: packages,
    scripts: scripts,
  );
}

/// Turns on the system's reduce-motion setting, which stops looping
/// animations such as the playing bars and the buffering ring, so
/// pumpAndSettle can settle while something plays.
void reduceMotion(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// Pumps the whole app on a phone-sized screen.
Future<void> pumpApp(
  WidgetTester tester,
  Bookshelf shelf,
  Fakes fakes, {
  Locale locale = const Locale('zh', 'CN'),
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    PagestageApp(
      bookshelf: shelf,
      readingSettings: MemoryReadingSettings(),
      services: fakes.services,
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

/// Lines that cover [paragraphs] exactly, one per paragraph, joined by
/// newline runs as the original chapter text would be.
List<ListeningLine> linesFor(
  List<String> paragraphs, {
  Set<int> nonStory = const {},
  Map<int, String> speakers = const {},
  Map<int, String> speakerIds = const {},
  bool directed = false,
}) {
  final out = <ListeningLine>[];
  var offset = 0;
  var index = 0;
  for (final (i, text) in paragraphs.indexed) {
    out.add(
      ListeningLine(
        index: index,
        text: text,
        start: offset,
        end: offset + text.length,
        speakerId: speakerIds[index],
        speakerName: speakers[index],
        nonStory: nonStory.contains(index),
        directed: directed,
      ),
    );
    offset += text.length;
    index++;
    if (i < paragraphs.length - 1) {
      out.add(
        ListeningLine(
          index: index,
          text: '\n',
          start: offset,
          end: offset + 1,
          nonStory: true,
        ),
      );
      offset += 1;
      index++;
    }
  }
  return out;
}
