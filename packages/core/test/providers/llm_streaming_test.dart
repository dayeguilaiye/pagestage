import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

// Synthetic server-sent events shaped after the OpenAI streaming references:
// https://platform.openai.com/docs/api-reference/responses-streaming
// https://platform.openai.com/docs/api-reference/chat-streaming
void main() {
  const request = LlmRequest(
    system: 'Return JSON.',
    user: 'Direct this chapter.',
    schemaName: 'script',
    schema: {'type': 'object'},
  );
  String sse(List<Object> events) => [
    for (final event in events)
      'data: ${event is String ? event : jsonEncode(event)}\n\n',
  ].join();

  test('Responses streaming uses the completed response object', () async {
    late Map body;
    final adapter = OpenAiLlmAdapter(
      baseUrl: Uri.parse('https://example.invalid/v1'),
      apiKey: 'test-key',
      model: 'director-model',
      api: LlmApi.responses,
      stream: true,
      client: MockClient((incoming) async {
        body = jsonDecode(incoming.body) as Map;
        return http.Response(
          sse([
            {
              'type': 'response.created',
              'response': {'status': 'in_progress'},
            },
            {'type': 'response.output_text.delta', 'delta': '{"lines"'},
            {'type': 'response.output_text.delta', 'delta': ':[]}'},
            {
              'type': 'response.completed',
              'response': {
                'id': 'resp-1',
                'status': 'completed',
                'output': [
                  {
                    'type': 'message',
                    'content': [
                      {'type': 'output_text', 'text': '{"lines":[]}'},
                    ],
                  },
                ],
                'usage': {
                  'input_tokens': 10,
                  'output_tokens': 4,
                  'total_tokens': 14,
                },
              },
            },
          ]),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );
    final result = await adapter.complete(request);
    expect(body['stream'], true);
    expect(result.data, {'lines': []});
    expect(result.usage.totalTokens, 14);
  });

  test('Chat streaming joins deltas and reads the final usage chunk', () async {
    late Map body;
    final temp = await Directory.systemTemp.createTemp('pagestage-stream');
    addTearDown(() => temp.delete(recursive: true));
    final ledger = File('${temp.path}/usage.jsonl');
    final adapter = OpenAiLlmAdapter(
      baseUrl: Uri.parse('https://example.invalid/v1'),
      apiKey: 'test-key',
      model: 'director-model',
      stream: true,
      usageLedger: JsonlUsageLedger(ledger),
      client: MockClient((incoming) async {
        body = jsonDecode(incoming.body) as Map;
        return http.Response(
          sse([
            {
              'id': 'chatcmpl-1',
              'choices': [
                {
                  'delta': {'role': 'assistant', 'content': '{"lines"'},
                  'finish_reason': null,
                },
              ],
            },
            {
              'id': 'chatcmpl-1',
              'choices': [
                {
                  'delta': {'content': ':[]}'},
                  'finish_reason': 'stop',
                },
              ],
            },
            {
              'id': 'chatcmpl-1',
              'choices': [],
              'usage': {
                'prompt_tokens': 12,
                'completion_tokens': 5,
                'total_tokens': 17,
              },
            },
            '[DONE]',
          ]),
          200,
        );
      }),
    );
    final result = await adapter.complete(request);
    expect(body['stream'], true);
    expect(body['stream_options'], {'include_usage': true});
    expect(result.data, {'lines': []});
    expect(result.usage.inputTokens, 12);
    expect(result.usage.totalTokens, 17);
    final record = jsonDecode(ledger.readAsLinesSync().single) as Map;
    expect(record['requestId'], 'chatcmpl-1');
    expect(record['usage'], {
      'prompt_tokens': 12,
      'completion_tokens': 5,
      'total_tokens': 17,
    });
  });

  for (final api in LlmApi.values) {
    test('${api.name} streams that end early are invalid responses', () async {
      final adapter = OpenAiLlmAdapter(
        baseUrl: Uri.parse('https://example.invalid/v1'),
        apiKey: 'test-key',
        model: 'director-model',
        api: api,
        stream: true,
        client: MockClient(
          (_) async => http.Response(
            sse([
              api == LlmApi.responses
                  ? {'type': 'response.output_text.delta', 'delta': '{'}
                  : {
                      'id': 'chatcmpl-1',
                      'choices': [
                        {
                          'delta': {'content': '{'},
                          'finish_reason': null,
                        },
                      ],
                    },
            ]),
            200,
          ),
        ),
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
    });
  }

  test('stream setting comes from configuration or LLM_STREAM', () async {
    final temp = await Directory.systemTemp.createTemp('pagestage-stream');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}/providers.json')
      ..writeAsStringSync(
        jsonEncode({
          'llm': {'key': 'k', 'model': 'm', 'stream': 'true'},
        }),
      );
    final fromFile = LlmSettings.fromConfiguration(
      await ProviderConfiguration.load(file.path, environment: const {}),
    );
    expect(fromFile.stream, isTrue);
    final fromEnvironment = LlmSettings.fromConfiguration(
      await ProviderConfiguration.load(
        file.path,
        environment: const {'LLM_STREAM': 'false'},
      ),
    );
    expect(fromEnvironment.stream, isFalse);
    expect(
      () async => LlmSettings.fromConfiguration(
        await ProviderConfiguration.load(
          null,
          environment: const {
            'LLM_KEY': 'k',
            'LLM_MODEL': 'm',
            'LLM_STREAM': 'yes',
          },
        ),
      ),
      throwsA(isA<ProviderException>()),
    );
  });
}
