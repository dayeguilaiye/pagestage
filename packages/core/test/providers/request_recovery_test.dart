import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

import '../support/fake_request_clock.dart';

const request = LlmRequest(
  system: 'test',
  user: 'test',
  schemaName: 'test',
  schema: {},
);
const ttsRequest = TtsRequest(
  text: 'Hi',
  language: 'en',
  binding: VoiceBinding(
    provider: 'minimax',
    model: 'speech-2.8-hd',
    voiceId: 'fake',
  ),
  direction: Direction(speakerId: 'narrator'),
);

Map<String, Object?> chatResponse({String content = '{}', String? refusal}) => {
  'id': 'accepted',
  'choices': [
    {
      'finish_reason': 'stop',
      'message': {'content': content, 'refusal': ?refusal},
    },
  ],
  'usage': {'prompt_tokens': 4, 'completion_tokens': 2, 'total_tokens': 6},
};
String sse(Object event) => 'data: ${jsonEncode(event)}\n\n';

void main() {
  test(
    'LLM configuration enables streaming by default and accepts false',
    () async {
      for (final disabled in [false, true]) {
        final config = await ProviderConfiguration.load(
          null,
          environment: {
            'LLM_KEY': 'fake',
            'LLM_MODEL': 'fake',
            if (disabled) 'LLM_STREAM': 'false',
          },
        );
        final settings = LlmSettings.fromConfiguration(config);
        expect(settings.stream, !disabled);
        final adapter = settings.createProfileAdapter();
        expect(adapter.stream, !disabled);
        adapter.close();
      }
    },
  );

  for (final failures in [1, 2, 3]) {
    test(
      'LLM connection recovery is bounded after $failures failures',
      () async {
        final clock = FakeRequestClock();
        final ledger = MemoryLedger();
        var calls = 0;
        final adapter = OpenAiLlmAdapter(
          baseUrl: Uri.parse('https://example.invalid'),
          apiKey: 'fake',
          model: 'fake',
          stream: false,
          runtime: clock.runtime,
          usageLedger: ledger,
          client: MockClient((_) async {
            if (++calls <= failures) {
              throw http.ClientException('synthetic disconnect');
            }
            return http.Response(jsonEncode(chatResponse()), 200);
          }),
        );
        if (failures < 3) {
          final result = await adapter.complete(request);
          expect(result.data, isEmpty);
          expect(result.attempts, failures + 1);
          expect(ledger.records, hasLength(1));
        } else {
          await expectLater(
            adapter.complete(request),
            throwsA(isA<ProviderException>()),
          );
          expect(ledger.records, isEmpty);
        }
        expect(calls, failures < 3 ? failures + 1 : 3);
        expect(clock.waits, [
          const Duration(seconds: 1),
          if (failures >= 2) const Duration(seconds: 2),
        ]);
        expect(clock.events.join(), contains('retry'));
      },
    );
  }

  test('LLM timeout aborts each attempt before starting the next', () async {
    final client = HangingClient();
    final adapter = OpenAiLlmAdapter(
      baseUrl: Uri.parse('https://example.invalid'),
      apiKey: 'fake',
      model: 'fake',
      client: client,
      timeout: const Duration(milliseconds: 1),
      runtime: FakeRequestClock().runtime,
    );
    await expectLater(
      adapter.complete(request),
      throwsA(
        isA<ProviderException>().having((e) => e.code, 'code', 'timeout'),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(client.calls, 3);
    expect(client.aborted, 3);
    expect(client.maxActive, 1);
  });

  for (final api in LlmApi.values) {
    test(
      '${api.name} partial stream retries and preserves accepted usage',
      () async {
        final ledger = MemoryLedger();
        var calls = 0;
        final adapter = OpenAiLlmAdapter(
          baseUrl: Uri.parse('https://example.invalid'),
          apiKey: 'fake',
          model: 'fake',
          api: api,
          runtime: FakeRequestClock().runtime,
          usageLedger: ledger,
          client: MockClient((incoming) async {
            expect((jsonDecode(incoming.body) as Map)['stream'], true);
            calls++;
            if (api == LlmApi.chatCompletions) {
              return http.Response(
                sse({
                  'id': 'call-$calls',
                  'choices': [
                    {
                      'delta': {'content': calls == 1 ? '{' : '{}'},
                      'finish_reason': calls == 1 ? null : 'stop',
                    },
                  ],
                  'usage': {'total_tokens': calls},
                }),
                200,
              );
            }
            return http.Response(
              calls == 1
                  ? sse({
                      'type': 'response.created',
                      'response': {
                        'id': 'call-1',
                        'usage': {'total_tokens': 1},
                      },
                    })
                  : sse({
                      'type': 'response.completed',
                      'response': {
                        'id': 'call-2',
                        'status': 'completed',
                        'output': [
                          {
                            'type': 'message',
                            'content': [
                              {'type': 'output_text', 'text': '{}'},
                            ],
                          },
                        ],
                        'usage': {'total_tokens': 2},
                      },
                    }),
              200,
            );
          }),
        );
        expect((await adapter.complete(request)).attempts, 2);
        expect(calls, 2);
        expect(ledger.records.map((r) => r.usage['total_tokens']), [1, 2]);
        expect(ledger.records.map((r) => r.requestId), ['call-1', 'call-2']);
      },
    );
  }

  for (final body in [
    chatResponse(content: 'invalid JSON'),
    chatResponse(refusal: 'No'),
  ]) {
    test(
      'accepted ${((body['choices'] as List).first as Map)['message']} is not retried',
      () async {
        final ledger = MemoryLedger();
        var calls = 0;
        final adapter = OpenAiLlmAdapter(
          baseUrl: Uri.parse('https://example.invalid'),
          apiKey: 'fake',
          model: 'fake',
          stream: false,
          runtime: FakeRequestClock().runtime,
          usageLedger: ledger,
          client: MockClient((_) async {
            calls++;
            return http.Response(jsonEncode(body), 200);
          }),
        );
        await expectLater(
          adapter.complete(request),
          throwsA(
            isA<ProviderException>().having(
              (e) => e.kind,
              'kind',
              ProviderErrorKind.invalidResponse,
            ),
          ),
        );
        expect(calls, 1);
        expect(ledger.records.single.usage['total_tokens'], 6);
      },
    );
  }

  test(
    'refusal followed by stream disconnect never repeats a paid request',
    () async {
      var calls = 0;
      final client = MockClient.streaming((_, _) async {
        calls++;
        Stream<List<int>> events() async* {
          yield utf8.encode(
            sse({
              'id': 'refused',
              'choices': [
                {
                  'delta': {'refusal': 'No'},
                  'finish_reason': null,
                },
              ],
            }),
          );
          throw http.ClientException('synthetic');
        }

        return http.StreamedResponse(events(), 200);
      });
      final adapter = OpenAiLlmAdapter(
        baseUrl: Uri.parse('https://example.invalid'),
        apiKey: 'fake',
        model: 'fake',
        client: client,
        runtime: FakeRequestClock().runtime,
      );
      await expectLater(
        adapter.complete(request),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.kind,
            'kind',
            ProviderErrorKind.invalidResponse,
          ),
        ),
      );
      expect(calls, 1);
    },
  );

  test('Responses refusal delta ending early is never retried', () async {
    var calls = 0;
    final adapter = OpenAiLlmAdapter(
      baseUrl: Uri.parse('https://example.invalid'),
      apiKey: 'fake',
      model: 'fake',
      api: LlmApi.responses,
      runtime: FakeRequestClock().runtime,
      client: MockClient((_) async {
        calls++;
        return http.Response(
          sse({'type': 'response.refusal.delta', 'delta': 'No'}),
          200,
        );
      }),
    );
    await expectLater(
      adapter.complete(request),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.kind,
          'kind',
          ProviderErrorKind.invalidResponse,
        ),
      ),
    );
    expect(calls, 1);
  });

  test(
    'a JSON body returned instead of SSE is not repeatedly requested',
    () async {
      var calls = 0;
      final adapter = OpenAiLlmAdapter(
        baseUrl: Uri.parse('https://example.invalid'),
        apiKey: 'fake',
        model: 'fake',
        runtime: FakeRequestClock().runtime,
        client: MockClient((_) async {
          calls++;
          return http.Response(jsonEncode(chatResponse()), 200);
        }),
      );
      await expectLater(
        adapter.complete(request),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.kind,
            'kind',
            ProviderErrorKind.invalidResponse,
          ),
        ),
      );
      expect(calls, 1);
    },
  );

  test(
    'Bailian download throttling never repeats the accepted synthesis',
    () async {
      final clock = FakeRequestClock();
      final ledger = MemoryLedger();
      var posts = 0, downloads = 0;
      final raw = BailianTtsAdapter(
        apiKey: 'fake',
        usageLedger: ledger,
        client: MockClient((incoming) async {
          if (incoming.method == 'POST') {
            posts++;
            return http.Response(
              jsonEncode({
                'output': {
                  'finish_reason': 'stop',
                  'audio': {'url': 'https://audio.example.invalid/test.wav'},
                },
                'usage': {'characters': 2},
              }),
              200,
            );
          }
          downloads++;
          return http.Response('limited', 429);
        }),
      );
      final adapter = ScheduledTtsAdapter(
        raw,
        ProviderRequestQueue(
          provider: 'bailian',
          requestsPerMinute: 60,
          runtime: clock.runtime,
        ),
      );
      await expectLater(
        adapter.synthesize(
          const TtsRequest(
            text: 'Hi',
            language: 'en',
            binding: VoiceBinding(
              provider: 'bailian',
              model: 'qwen-audio-3.1-tts-flash',
              voiceId: 'Emily_v3.1',
            ),
            direction: Direction(speakerId: 'narrator'),
          ),
        ),
        throwsA(isA<ProviderException>()),
      );
      expect(posts, 1);
      expect(downloads, 1);
      expect(ledger.records, hasLength(1));
      expect(clock.waits, isEmpty);
    },
  );

  test(
    'TTS throttling waits then finishes a chapter and caches completed lines',
    () async {
      final temp = await Directory.systemTemp.createTemp('recovery-synthesis');
      addTearDown(() => temp.delete(recursive: true));
      final clock = FakeRequestClock();
      final ledger = MemoryLedger();
      final texts = <String>[];
      final raw = MiniMaxTtsAdapter(
        apiKey: 'fake',
        usageLedger: ledger,
        client: MockClient((incoming) async {
          texts.add((jsonDecode(incoming.body) as Map)['text'] as String);
          if (texts.length == 2) {
            return http.Response(
              jsonEncode({
                'base_resp': {'status_code': 1002},
              }),
              200,
            );
          }
          return miniMaxAudio();
        }),
      );
      final session = TtsProviderSession.open(
        await ProviderConfiguration.load(null, environment: {}),
        providers: ['minimax'],
        overrides: {'minimax': raw},
        runtime: clock.runtime,
      );
      addTearDown(session.close);
      const chapter = Chapter(number: 1, title: 'One', text: 'First.\nSecond.');
      final synthesizer = Synthesizer(adapters: session.adapters);
      Future<SynthesisResult> run() => synthesizer.synthesize(
        chapter: chapter,
        script: Script.narration(bookId: 'book', chapter: chapter),
        language: 'en',
        voices: {'narrator': ttsRequest.binding},
        outputPath: '${temp.path}/chapter.wav',
      );
      final first = await run();
      expect(texts, ['First.\n', 'Second.', 'Second.']);
      expect(first.requests, 2);
      expect(clock.waits, [
        const Duration(seconds: 5),
        const Duration(seconds: 60),
      ]);
      expect(ledger.records, hasLength(2));
      final replay = await run();
      expect(replay.cacheHits, 2);
      expect(texts, hasLength(3));
    },
  );

  test(
    'persistent TTS throttling ends after three attempts and releases queue',
    () async {
      final clock = FakeRequestClock();
      final queue = ProviderRequestQueue(
        provider: 'minimax',
        requestsPerMinute: 12,
        runtime: clock.runtime,
      );
      var calls = 0;
      await expectLater(
        queue.run<void>(() async {
          calls++;
          throw const ProviderException(
            provider: 'minimax',
            kind: ProviderErrorKind.rateLimited,
          );
        }),
        throwsA(isA<ProviderException>()),
      );
      expect(calls, 3);
      expect(clock.waits, [
        const Duration(seconds: 60),
        const Duration(seconds: 60),
      ]);
      expect(clock.events.last, contains('exhausted'));
      expect(await queue.run(() async => 42), 42);
      expect(clock.waits.last, const Duration(seconds: 60));
    },
  );

  test(
    'concurrent callers share pacing across sessions for one provider',
    () async {
      final clock = FakeRequestClock();
      final queues = <String, ProviderRequestQueue>{};
      final starts = <Duration>[];
      final raw = MiniMaxTtsAdapter(
        apiKey: 'fake',
        client: MockClient((_) async {
          starts.add(clock.now);
          return miniMaxAudio();
        }),
      );
      final config = await ProviderConfiguration.load(
        null,
        environment: {'MINIMAX_REQUESTS_PER_MINUTE': '30'},
      );
      TtsProviderSession open() => TtsProviderSession.open(
        config,
        providers: ['minimax'],
        overrides: {'minimax': raw},
        runtime: clock.runtime,
        queues: queues,
      );
      final a = open(), b = open();
      addTearDown(a.close);
      addTearDown(b.close);
      await Future.wait([
        a.adapters['minimax']!.synthesize(ttsRequest),
        b.adapters['minimax']!.synthesize(ttsRequest),
        a.adapters['minimax']!.synthesize(ttsRequest),
      ]);
      expect(starts, [
        Duration.zero,
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ]);
    },
  );

  for (final kind in [
    ProviderErrorKind.invalidKey,
    ProviderErrorKind.insufficientBalance,
    ProviderErrorKind.invalidResponse,
    ProviderErrorKind.unavailable,
  ]) {
    test('TTS $kind is never retried', () async {
      final clock = FakeRequestClock();
      var calls = 0;
      final queue = ProviderRequestQueue(
        provider: 'minimax',
        requestsPerMinute: 12,
        runtime: clock.runtime,
      );
      await expectLater(
        queue.run<void>(() async {
          calls++;
          throw ProviderException(provider: 'minimax', kind: kind);
        }),
        throwsA(isA<ProviderException>()),
      );
      expect(calls, 1);
      expect(clock.waits, isEmpty);
    });
  }

  for (final limit in ['0', '-1', 'no', '60001']) {
    test('invalid TTS request limit $limit fails before requests', () async {
      final config = await ProviderConfiguration.load(
        null,
        environment: {'MINIMAX_REQUESTS_PER_MINUTE': limit},
      );
      expect(
        () => TtsProviderSession.open(config, providers: ['minimax']),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.kind,
            'kind',
            ProviderErrorKind.invalidConfiguration,
          ),
        ),
      );
    });
  }
}

http.Response miniMaxAudio() {
  final wav = PcmAudio(samples: Int16List.fromList([1, 2])).toWav();
  return http.Response(
    jsonEncode({
      'base_resp': {'status_code': 0},
      'data': {
        'status': 2,
        'audio': wav.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      },
      'extra_info': {'usage_characters': 2},
    }),
    200,
  );
}

class MemoryLedger implements UsageLedger {
  final records = <UsageRecord>[];
  @override
  void record(UsageRecord record) => records.add(record);
}

class HangingClient extends http.BaseClient {
  int calls = 0, aborted = 0, active = 0, maxActive = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    calls++;
    active++;
    if (active > maxActive) maxActive = active;
    final result = Completer<http.StreamedResponse>();
    (request as http.Abortable).abortTrigger!.then((_) {
      aborted++;
      active--;
      result.completeError(http.RequestAbortedException(request.url));
    });
    return result.future;
  }
}
