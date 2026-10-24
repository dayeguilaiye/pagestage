import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:pagestage_core/src/cli.dart';
import 'package:test/test.dart';

import 'support/fake_request_clock.dart';

void main() {
  test(
    'CLI imports, profiles, casts, directs and synthesizes with provider fakes',
    () async {
      final temp = await Directory.systemTemp.createTemp('pipeline-cli-');
      addTearDown(() => temp.delete(recursive: true));
      final source = await File('${temp.path}/story.txt').writeAsString(
        'Chapter I\nA quiet morning.\nAlice said:Hello!\nWho are you?\nAuthor note.',
      );
      final minimax = _Tts('minimax');
      final bailian = _Tts('bailian');
      Future<Map<String, dynamic>> run(List<String> arguments) async {
        final output = StringBuffer();
        final errors = StringBuffer();
        final status = await runCli(
          ['--data-dir', temp.path, ...arguments],
          output: output,
          errorOutput: errors,
          environment: {},
          profileLlm: _Profile(),
          directorLlm: _Director(),
          requestRuntime: FakeRequestClock().runtime,
          ttsAdapters: {'minimax': minimax, 'bailian': bailian},
        );
        expect(status, 0, reason: errors.toString());
        return jsonDecode(output.toString()) as Map<String, dynamic>;
      }

      final imported = await run(['import', source.path]);
      final id = imported['bookId'] as String;
      await run(['profile', id, '--through', '1']);
      final cast = await run([
        'cast',
        'recommend',
        id,
        '--provider',
        'minimax',
      ]);
      final alice = (cast['speakers'] as List).cast<Map>().singleWhere(
        (s) => s['name'] == 'Alice',
      );
      await run([
        'cast',
        'set',
        id,
        alice['speakerId'] as String,
        'bailian:Emily_v3.1',
      ]);
      final directed = await run(['direct', id, '1']);
      expect(((directed['script'] as Map)['lines'] as List), hasLength(5));
      final result = await run(['synthesize', id, '1']);
      expect(result['requests'], 4);
      expect(result['cacheHits'], 0);
      expect(
        (result['lines'] as List).map((line) => (line as Map)['speakerName']),
        ['Narrator', 'Narrator', 'Alice', 'Stranger', 'Narrator'],
      );
      expect((result['lines'] as List).last['skipped'], 'nonStory');
      expect(bailian.requests.single.text, contains('Hello!'));
      expect(
        minimax.requests.map((r) => r.text).join(),
        contains('Who are you?'),
      );
      expect(File(result['path'] as String).existsSync(), isTrue);
      expect(
        PcmAudio.fromWav(
          await File(result['path'] as String).readAsBytes(),
        ).samples,
        isNotEmpty,
      );
      for (final line in (result['lines'] as List).cast<Map>().where(
        (line) => line['skipped'] == null,
      )) {
        expect(File(line['audioPath'] as String).existsSync(), isTrue);
      }
      final replay = await run(['synthesize', id, '1']);
      expect(replay['requests'], 0);
      expect(replay['cacheHits'], 4);
      final drama = await run(['synthesize', id, '1', '--mode', 'drama']);
      expect(drama['requests'], 0);
      expect(drama['cacheHits'], 3);
      expect((drama['lines'] as List)[1]['skipped'], 'dialogueTag');
      await run([
        'cast',
        'set',
        id,
        alice['speakerId'] as String,
        'minimax:English_expressive_narrator',
      ]);
      final recast = await run(['synthesize', id, '1']);
      expect(recast['requests'], 1);
      expect(recast['cacheHits'], 3);
      expect(minimax.requests.last.text, contains('Hello!'));
    },
  );
  test('CLI applies the saved Chinese cast lexicon', () async {
    final temp = await Directory.systemTemp.createTemp('lexicon-cli-');
    addTearDown(() => temp.delete(recursive: true));
    final source = await File(
      '${temp.path}/zh.txt',
    ).writeAsString('第一章\n长乐来了。');
    final store = LocalStore('${temp.path}/pagestage.sqlite');
    final book = await Library(store).importTxt(source.path);
    final repository = CastRepository(store);
    final cast = await repository.get(book.id);
    await repository.save(
      cast.copyWith(
        profiledThrough: 1,
        lexicon: const [PronunciationEntry('长乐', 'chang2 le4')],
      ),
    );
    await Casting(store).recommend(book, providers: {'minimax'});
    await ScriptRepository(
      store,
    ).save(Script.narration(bookId: book.id, chapter: book.chapter(1)));
    await store.close();
    final tts = _Tts('minimax');
    final out = StringBuffer();
    expect(
      await runCli(
        ['--data-dir', temp.path, 'synthesize', book.id, '1'],
        output: out,
        errorOutput: StringBuffer(),
        environment: {},
        requestRuntime: FakeRequestClock().runtime,
        ttsAdapters: {'minimax': tts},
      ),
      0,
    );
    expect(tts.requests.single.pronunciations.single.pinyin, 'chang2 le4');
    final line =
        ((jsonDecode(out.toString()) as Map)['lines'] as List).first as Map;
    expect(line['pronunciationApplied'], isTrue);
    expect(line['audioPath'], isNot(line['rawAudioPath']));
    expect((line['loudness'] as Map)['targetLufs'], -20);
    tts.requests.clear();
    expect(
      await runCli(
        ['--data-dir', temp.path, 'narrate', book.id, '1'],
        output: StringBuffer(),
        errorOutput: StringBuffer(),
        environment: {},
        requestRuntime: FakeRequestClock().runtime,
        ttsAdapters: {'minimax': tts},
      ),
      0,
    );
    expect(tts.requests.single.pronunciations.single.pinyin, 'chang2 le4');
  });
  test(
    'CLI rejects a stale script before persisting casting changes',
    () async {
      final temp = await Directory.systemTemp.createTemp('stale-script-cli-');
      addTearDown(() => temp.delete(recursive: true));
      final source = await File(
        '${temp.path}/story.txt',
      ).writeAsString('Chapter I\nHello.');
      final store = LocalStore('${temp.path}/pagestage.sqlite');
      final book = await Library(store).importTxt(source.path);
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 1,
          speakers: [Speaker(id: 'hero', name: 'Hero')],
        ),
      );
      await Casting(store).recommend(book, providers: {'minimax'});
      await ScriptRepository(store).save(
        Script(
          bookId: book.id,
          chapterNumber: 1,
          sourceTextHash: 'stale',
          model: 'fixture',
          promptVersion: 'fixture',
          lines: [
            ScriptLine(
              start: 0,
              end: book.chapter(1).text.length,
              direction: const Direction(speakerId: 'hero'),
            ),
          ],
        ),
      );
      final before = await store.get('casts', book.id);
      await store.close();
      final tts = _Tts('minimax');
      final errors = StringBuffer();
      final status = await runCli(
        ['--data-dir', temp.path, 'synthesize', book.id, '1'],
        output: StringBuffer(),
        errorOutput: errors,
        environment: {},
        requestRuntime: FakeRequestClock().runtime,
        ttsAdapters: {'minimax': tts},
      );
      expect(status, isNot(0));
      expect(errors.toString(), contains('Direct the updated chapter'));
      expect(tts.requests, isEmpty);
      final reopened = LocalStore('${temp.path}/pagestage.sqlite');
      try {
        expect(await reopened.get('casts', book.id), before);
        expect(
          (await CastRepository(
            reopened,
          ).get(book.id)).speaker('hero').chapters,
          isEmpty,
        );
      } finally {
        await reopened.close();
      }
    },
  );
}

class _Profile implements LlmAdapter {
  @override
  String get model => 'fake-profile';
  @override
  Future<LlmResponse> complete(LlmRequest request) async => const LlmResponse(
    data: {
      'characters': [
        {
          'id': 'alice',
          'name': 'Alice',
          'aliases': <String>[],
          'gender': 'female',
          'ageGroup': 'youngAdult',
          'personality': 'calm',
          'speakingStyle': 'clear',
          'voiceDescription': 'warm',
          'dialogueCount': 1,
          'chapters': [1],
        },
      ],
      'personas': [],
      'merges': [],
      'provisionalResolutions': [],
      'lexicon': [],
    },
  );
}

class _Director implements LlmAdapter {
  @override
  String get model => 'fake-director';
  @override
  Future<LlmResponse> complete(LlmRequest request) async => LlmResponse(
    data: {
      'lines': [
        _line('A quiet morning.', 'narrator'),
        _line('Alice said:', 'narrator', tag: true),
        _line('Hello!', 'Alice'),
        _line('Who are you?', 'Stranger'),
        _line('Author note.', 'narrator', nonStory: true),
      ],
    },
  );
  Map<String, Object?> _line(
    String text,
    String speaker, {
    bool tag = false,
    bool nonStory = false,
  }) => {
    'text': text,
    'speakerId': speaker,
    'emotion': 'calm',
    'intensity': 'mild',
    'note': '',
    'isDialogueTag': tag,
    'isNonStory': nonStory,
  };
}

class _Tts implements TtsAdapter {
  _Tts(this.provider);
  @override
  final String provider;
  final requests = <TtsRequest>[];
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) =>
      TtsCapabilities(supportsPronunciation: true, maxCharacters: 9999);
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    requests.add(request);
    return TtsAudio(
      audio: PcmAudio(samples: Int16List.fromList(List.filled(240, 1000))),
      characters: request.text.runes.length,
    );
  }
}
