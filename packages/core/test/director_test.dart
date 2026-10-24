import 'dart:io';
import 'dart:convert';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_request_clock.dart';

class FakeDirectorLlm implements LlmAdapter {
  FakeDirectorLlm(this.responses);
  final List<Object> responses;
  final requests = <LlmRequest>[];
  @override
  String get model => 'fake-director';
  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    requests.add(request);
    final value = responses.removeAt(0);
    if (value is Exception) throw value;
    return LlmResponse(
      data: value as Map<String, Object?>,
      usage: const TokenUsage(
        inputTokens: 10,
        outputTokens: 4,
        totalTokens: 14,
      ),
    );
  }
}

class ContextLlm implements LlmAdapter {
  @override
  String get model => 'context-fake';
  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final input = jsonDecode(request.user) as Map;
    final previous = input['previousLines'] as List? ?? [];
    final speaker = previous.isEmpty
        ? 'narrator'
        : ((previous.last as Map)['direction'] as Map)['speakerId'] as String;
    return LlmResponse(
      data: response([line(input['source'] as String, speaker)]),
    );
  }
}

Map<String, Object?> line(
  String text,
  String speaker, {
  String emotion = 'calm',
  String intensity = 'mild',
  bool tag = false,
  bool nonStory = false,
}) => {
  'text': text,
  'speakerId': speaker,
  'emotion': emotion,
  'intensity': intensity,
  'note': '自然朗读',
  'isDialogueTag': tag,
  'isNonStory': nonStory,
};
Map<String, Object?> response(List<Map<String, Object?>> lines) => {
  'lines': lines,
};
Book novel(String text) => Book(
  id: 'novel',
  title: 'Novel',
  language: 'zh',
  sourcePath: '',
  chapters: [Chapter(number: 1, title: '第1章', text: text)],
);
void main() {
  late Directory temp;
  late LocalStore store;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('director-');
    store = LocalStore('${temp.path}/db.sqlite');
    await CastRepository(store).save(
      Cast(
        bookId: 'novel',
        profiledThrough: 1,
        speakers: [
          Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
          Speaker(id: 'lin', name: '林舟', chapters: [1]),
        ],
      ),
    );
  });
  tearDown(() async {
    await store.close();
    await temp.delete(recursive: true);
  });
  for (final plan in [
    ['disconnect', 'invalid', 'valid'],
    ['disconnect', 'disconnect', 'invalid'],
    ['invalid', 'disconnect', 'disconnect'],
  ]) {
    test('network and alignment retries share three attempts: $plan', () async {
      var calls = 0;
      final clock = FakeRequestClock();
      final llm = OpenAiLlmAdapter(
        baseUrl: Uri.parse('https://example.invalid'),
        apiKey: 'fake',
        model: 'fake',
        stream: false,
        runtime: clock.runtime,
        client: MockClient((_) async {
          final step = plan[calls++];
          if (step == 'disconnect') throw http.ClientException('synthetic');
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'finish_reason': 'stop',
                  'message': {
                    'content': jsonEncode(
                      response([line(step == 'valid' ? '甲说。' : '错误正文', 'lin')]),
                    ),
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final result = Director(
        store,
        llm,
        runtime: clock.runtime,
      ).direct(novel('甲说。'), 1);
      if (plan.last == 'disconnect') {
        await expectLater(result, throwsA(isA<ProviderException>()));
      } else {
        final directed = await result;
        expect(directed.requests, 3);
        expect(directed.script.lines.map((l) => l.direction.speakerId), [
          plan.last == 'valid' ? 'lin' : 'narrator',
        ]);
      }
      expect(calls, 3);
    });
  }
  test(
    'directs source ranges and persists model, prompt and performance flags',
    () async {
      final book = novel('他说：\n“你好！”\n作者的话。');
      final llm = FakeDirectorLlm([
        response([
          line('他说：', 'narrator', tag: true),
          line('“你好！”', 'lin', emotion: 'happy'),
          line('作者的话。', 'narrator', nonStory: true),
        ]),
      ]);
      final result = await Director(store, llm).direct(book, 1);
      expect(
        result.script.lines.map((l) => l.textIn(book.chapter(1).text)).join(),
        book.chapter(1).text,
      );
      expect(result.script.lines.map((l) => l.direction.speakerId), [
        'narrator',
        'lin',
        'narrator',
      ]);
      expect(result.script.lines[1].direction.emotion, Emotion.happy);
      expect(result.script.lines.first.isDialogueTag, true);
      expect(result.script.lines.last.isNonStory, true);
      expect(result.script.model, 'fake-director');
      expect(result.script.promptVersion, 'director-v5');
      expect(result.usage.totalTokens, 14);
      expect(
        (await ScriptRepository(store).get(book.id, 1))!.toJson(),
        result.script.toJson(),
      );
    },
  );
  test(
    'tolerates punctuation, whitespace and fullwidth forms while reading original text',
    () async {
      final book = novel('　ＡＱ说：“你 好，世界！”\r\n');
      final llm = FakeDirectorLlm([
        response([line('AQ说: "你好,世界!"', 'lin')]),
      ]);
      final result = await Director(store, llm).direct(book, 1);
      expect(result.script.lines, hasLength(1));
      expect(result.script.lines.single.direction.speakerId, 'lin');
      expect(
        result.script.lines.single.textIn(book.chapter(1).text),
        '　ＡＱ说：“你 好，世界！”\r\n',
      );
      expect(result.requests, 1);
    },
  );
  test(
    'retries twice then fills omitted paragraphs and discards invented dialogue',
    () async {
      final book = novel('甲说。\n漏掉的一段。\n乙说。');
      final bad = response([
        line('甲说。', 'lin'),
        line('不存在的长篇台词。', 'ghost'),
        line('乙说。', 'lin'),
      ]);
      final result = await Director(
        store,
        FakeDirectorLlm([bad, bad, bad]),
      ).direct(book, 1);
      expect(result.requests, 3);
      expect(result.usage.totalTokens, 42);
      expect(result.script.lines.map((l) => l.textIn(book.chapter(1).text)), [
        '甲说。',
        '\n漏掉的一段。\n',
        '乙说。',
      ]);
      expect(result.script.lines.map((l) => l.direction.speakerId), [
        'lin',
        'narrator',
        'lin',
      ]);
      expect(result.script.lines.first.start, 0);
      expect(result.script.lines.last.end, book.chapter(1).text.length);
    },
  );
  test(
    'paragraph chunks preserve UTF16 ranges and speaker context across chapters and blocks',
    () async {
      final book = Book(
        id: 'novel',
        title: 'Novel',
        language: 'zh',
        sourcePath: '',
        chapters: [
          const Chapter(number: 1, title: '前章', text: '他先说。'),
          const Chapter(number: 2, title: '本章', text: '第一段。\n\n第二段𠀀。'),
        ],
      );
      final cast = await CastRepository(store).get(book.id);
      await CastRepository(store).save(cast.copyWith(profiledThrough: 2));
      await ScriptRepository(store).save(
        Script(
          bookId: book.id,
          chapterNumber: 1,
          sourceTextHash: book.chapter(1).textHash,
          model: 'previous',
          promptVersion: 'v1',
          lines: [
            const ScriptLine(
              start: 0,
              end: 4,
              direction: Direction(speakerId: 'lin'),
            ),
          ],
        ),
      );
      final result = await Director(
        store,
        ContextLlm(),
        chunkCharacters: 6,
      ).direct(book, 2);
      expect(result.chunks, 2);
      expect(result.script.lines.map((l) => l.direction.speakerId), [
        'lin',
        'lin',
      ]);
      expect(result.script.lines.map((l) => l.textIn(book.chapter(2).text)), [
        '第一段。\n\n',
        '第二段𠀀。',
      ]);
      expect(result.script.lines.last.end, 12);
    },
  );
  test(
    'keeps concealed personas independent and excludes future owner relationships from context',
    () async {
      final book = Book(
        id: 'novel',
        title: 'Novel',
        language: 'zh',
        sourcePath: '',
        chapters: [
          const Chapter(number: 1, title: '初见', text: '“站住！”'),
          const Chapter(number: 2, title: '等待', text: '等待。'),
          const Chapter(number: 3, title: '揭晓', text: '“是我。”'),
        ],
      );
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 3,
          speakers: [
            Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
            Speaker(id: 'father', name: '父亲', chapters: [3]),
            Speaker(
              id: 'masked',
              name: '黑袍人',
              kind: SpeakerKind.persona,
              characterId: 'father',
              revealChapter: 3,
              chapters: [1, 2],
            ),
          ],
        ),
      );
      final llm = FakeDirectorLlm([
        response([line('“站住！”', 'father')]),
      ]);
      final result = await Director(store, llm).direct(book, 1);
      expect(result.script.lines.single.direction.speakerId, 'masked');
      final visible =
          (jsonDecode(llm.requests.single.user) as Map)['cast'] as List;
      expect(visible.map((s) => (s as Map)['id']), ['narrator', 'masked']);
      expect((visible.last as Map).containsKey('characterId'), false);
      expect((visible.last as Map).containsKey('revealChapter'), false);
    },
  );
  test(
    'unquoted letter authors and system speakers persist alongside unified narration',
    () async {
      final book = novel(
        '我拆开小雨寄来的信。\n明天我就回来。\n请在车站等我。\n'
        '读完信，我又打开一封来历不明、没有署名的信。\n今晚别出门。\n系统提示：成功。',
      );
      final data = response([
        line('我拆开小雨寄来的信。', 'narrator'),
        line('明天我就回来。\n请在车站等我。', '小雨'),
        line('读完信，我又打开一封来历不明、没有署名的信。', 'narrator'),
        line('今晚别出门。', 'narrator'),
        line('系统提示：成功。', '系统'),
      ]);
      final first = await Director(
        store,
        FakeDirectorLlm([data]),
      ).direct(book, 1);
      final saved = await CastRepository(store).get(book.id);
      final provisional = saved.speakers
          .where((s) => s.kind == SpeakerKind.provisional)
          .toList();
      expect(provisional.map((s) => s.name), ['小雨', '系统']);
      expect(first.script.lines.map((l) => l.direction.speakerId), [
        'narrator',
        provisional[0].id,
        'narrator',
        'narrator',
        provisional[1].id,
      ]);
      expect(
        first.script.lines.map((l) => l.textIn(book.chapter(1).text)).join(),
        book.chapter(1).text,
      );
      expect(
        first.script.lines.every((l) => !l.isDialogueTag && !l.isNonStory),
        true,
      );
      final second = await Director(
        store,
        FakeDirectorLlm([data]),
      ).direct(book, 1);
      expect(
        second.script.lines.map((l) => l.direction.speakerId),
        first.script.lines.map((l) => l.direction.speakerId),
      );
      expect(
        (await CastRepository(store).get(book.id)).speakers
            .where((s) => s.kind == SpeakerKind.provisional)
            .map((s) => s.dialogueCount),
        [1, 1],
      );
    },
  );
  test('revealed persona dialogue uses its owner speaker ID', () async {
    final book = Book(
      id: 'novel',
      title: 'Novel',
      language: 'zh',
      sourcePath: '',
      chapters: [
        const Chapter(number: 1, title: '初见', text: '“站住！”'),
        const Chapter(number: 2, title: '等待', text: '等待。'),
        const Chapter(number: 3, title: '揭晓', text: '“是我。”'),
      ],
    );
    await CastRepository(store).save(
      Cast(
        bookId: book.id,
        profiledThrough: 3,
        speakers: [
          Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
          Speaker(
            id: 'father',
            name: '父亲',
            chapters: [3],
            voiceId: 'unused-parent-voice',
          ),
          Speaker(
            id: 'masked',
            name: '黑袍人',
            kind: SpeakerKind.persona,
            characterId: 'father',
            revealChapter: 3,
            chapters: [1, 2],
            voiceId: 'masked-voice',
          ),
        ],
      ),
    );
    final result = await Director(
      store,
      FakeDirectorLlm([
        response([line('“是我。”', 'masked')]),
      ]),
    ).direct(book, 3);
    expect(result.script.lines.single.direction.speakerId, 'father');
  });
  test(
    'whitespace-only source is preserved without a paid directing request',
    () async {
      final book = novel('  \r\n\n');
      final result = await Director(store, FakeDirectorLlm([])).direct(book, 1);
      expect(result.requests, 0);
      expect(
        result.script.lines.single.textIn(book.chapter(1).text),
        '  \r\n\n',
      );
    },
  );
  test('a successful retry replaces the incomplete attempt', () async {
    final book = novel('甲。乙。');
    final result = await Director(
      store,
      FakeDirectorLlm([
        response([line('甲。', 'lin')]),
        response([line('甲。', 'lin'), line('乙。', 'lin')]),
      ]),
    ).direct(book, 1);
    expect(result.requests, 2);
    expect(result.script.lines.map((l) => l.direction.speakerId), [
      'lin',
      'lin',
    ]);
  });
  test('unprofiled chapters never reach the provider', () async {
    await CastRepository(store).save(Cast(bookId: 'novel'));
    await expectLater(
      Director(store, FakeDirectorLlm([])).direct(novel('正文。'), 1),
      throwsStateError,
    );
  });
  test(
    'provider failure in a later block leaves cast and script unchanged',
    () async {
      final book = novel('第一段。\n\n第二段。');
      final before = (await CastRepository(store).get(book.id)).toJson();
      await expectLater(
        Director(
          store,
          FakeDirectorLlm([
            response([line('第一段。', '新角色')]),
            const ProviderException(
              provider: 'llm',
              kind: ProviderErrorKind.rateLimited,
            ),
          ]),
          chunkCharacters: 6,
        ).direct(book, 1),
        throwsA(isA<ProviderException>()),
      );
      expect((await CastRepository(store).get(book.id)).toJson(), before);
      expect(await ScriptRepository(store).get(book.id, 1), isNull);
    },
  );
  test(
    'malformed speaker labels fall back to narration without invalid cast entries',
    () async {
      final book = novel('正文。');
      final bad = response([line('正文。', '')]);
      final result = await Director(
        store,
        FakeDirectorLlm([bad, bad, bad]),
      ).direct(book, 1);
      expect(result.requests, 3);
      expect(result.script.lines.single.direction.speakerId, 'narrator');
      expect(
        (await CastRepository(
          store,
        ).get(book.id)).speakers.any((s) => s.name.isEmpty),
        false,
      );
    },
  );

  test(
    'hidden owner without appearances resolves to persona before reveal',
    () async {
      final book = novel('你好。旁白。');
      await CastRepository(store).save(
        Cast(
          bookId: book.id,
          profiledThrough: 1,
          speakers: [
            Speaker(id: 'narrator', name: '旁白', kind: SpeakerKind.narrator),
            Speaker(id: 'owner', name: '真实身份', chapters: []),
            Speaker(
              id: 'mask',
              name: '黑袍人',
              kind: SpeakerKind.persona,
              characterId: 'owner',
              revealChapter: 3,
              chapters: [1],
            ),
          ],
        ),
      );
      final llm = FakeDirectorLlm([
        response([line('你好。', 'owner'), line('旁白。', 'narrator')]),
      ]);
      final result = await Director(store, llm).direct(book, 1);
      expect(result.script.lines.map((line) => line.direction.speakerId), [
        'mask',
        'narrator',
      ]);
    },
  );
}
