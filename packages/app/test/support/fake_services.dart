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

  @override
  Future<List<ListeningLine>> lines(String bookId, int chapter) async =>
      chapterLines[(bookId, chapter)] ?? const [];

  @override
  Future<ListeningBookmark?> bookmark(String bookId) async => bookmarks[bookId];
}

class SaveCall {
  SaveCall(this.preferences, this.llmKey, this.minimaxKey, this.bailianKey);
  final ProviderPreferences preferences;
  final String? llmKey;
  final String? minimaxKey;
  final String? bailianKey;
}

class FakeProviders extends ValueNotifier<ProviderPreferences>
    implements Providers {
  FakeProviders([super.value = const ProviderPreferences()]);

  final saves = <SaveCall>[];
  Object? failWith;

  @override
  Future<void> save(
    ProviderPreferences preferences, {
    String? llmKey,
    String? minimaxKey,
    String? bailianKey,
  }) async {
    saves.add(SaveCall(preferences, llmKey, minimaxKey, bailianKey));
    if (failWith case final error?) throw error;
    bool has(bool before, String? key) => key == null ? before : key.isNotEmpty;
    value = ProviderPreferences(
      baseUrl: preferences.baseUrl,
      protocol: preferences.protocol,
      profileModel: preferences.profileModel,
      directorModel: preferences.directorModel,
      region: preferences.region,
      hasLlmKey: has(value.hasLlmKey, llmKey),
      hasMinimaxKey: has(value.hasMinimaxKey, minimaxKey),
      hasBailianKey: has(value.hasBailianKey, bailianKey),
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

  @override
  Future<void> setExclusiveCount(int count) async {
    exclusiveCount = count;
    notifyListeners();
  }
}

class Fakes {
  Fakes({
    FakeListening? listening,
    FakeProviders? providers,
    FakeConsents? consents,
    FakeCasts? casts,
  }) : listening = listening ?? FakeListening(),
       providers = providers ?? FakeProviders(),
       consents = consents ?? FakeConsents(),
       casts = casts ?? FakeCasts();

  final FakeListening listening;
  final FakeProviders providers;
  final FakeConsents consents;
  final FakeCasts casts;

  late final services = AppServices(
    listening: listening,
    providers: providers,
    consents: consents,
    casts: casts,
  );
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
        speakerName: speakers[index],
        nonStory: nonStory.contains(index),
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
