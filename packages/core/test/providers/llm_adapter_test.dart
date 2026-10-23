import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

// Synthetic responses from official OpenAI documentation, not recorded traffic.
// https://developers.openai.com/api/docs/guides/structured-outputs
void main() {
  const request = LlmRequest(
    system: 'Return JSON.',
    user: 'Profile this chapter.',
    schemaName: 'profile',
    schema: {
      'type': 'object',
      'properties': {
        'characters': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
      'required': ['characters'],
      'additionalProperties': false,
    },
  );
  test(
    'Chat Completions preserves base path, schema and token usage',
    () async {
      final client = MockClient((http.Request incoming) async {
        expect(
          incoming.url.toString(),
          'https://example.invalid/custom/v1/chat/completions',
        );
        expect(incoming.headers['authorization'], 'Bearer test-key');
        final body = jsonDecode(incoming.body) as Map;
        expect(body['model'], 'profile-model');
        expect(body.containsKey('reasoning_effort'), false);
        expect((body['response_format'] as Map)['type'], 'json_schema');
        expect(
          ((body['response_format'] as Map)['json_schema'] as Map)['schema'],
          request.schema,
        );
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {
                  'content': '{"characters":["林舟"]}',
                  'refusal': null,
                },
              },
            ],
            'usage': {
              'prompt_tokens': 17,
              'completion_tokens': 5,
              'total_tokens': 22,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final adapter = OpenAiLlmAdapter(
        baseUrl: Uri.parse('https://example.invalid/custom/v1/'),
        apiKey: 'test-key',
        model: 'profile-model',
        api: LlmApi.chatCompletions,
        client: client,
      );
      final result = await adapter.complete(request);
      expect(result.data, {
        'characters': ['林舟'],
      });
      expect(result.usage.toJson(), {
        'inputTokens': 17,
        'outputTokens': 5,
        'totalTokens': 22,
      });
    },
  );
  test(
    'Responses parses output text after reasoning and uses its schema shape',
    () async {
      final adapter = OpenAiLlmAdapter(
        baseUrl: Uri.parse('https://example.invalid/v1'),
        apiKey: 'test-key',
        model: 'director-model',
        api: LlmApi.responses,
        client: MockClient((incoming) async {
          expect(incoming.url.path, '/v1/responses');
          final body = jsonDecode(incoming.body) as Map;
          expect(body['store'], false);
          expect(body.containsKey('reasoning'), false);
          expect(((body['text'] as Map)['format'] as Map)['name'], 'profile');
          expect(
            ((body['text'] as Map)['format'] as Map)['schema'],
            request.schema,
          );
          return http.Response(
            jsonEncode({
              'status': 'completed',
              'output': [
                {'type': 'reasoning', 'summary': []},
                {
                  'type': 'message',
                  'content': [
                    {'type': 'output_text', 'text': '{"characters":["Alice"]}'},
                  ],
                },
              ],
              'usage': {
                'input_tokens': 19,
                'output_tokens': 8,
                'total_tokens': 27,
              },
            }),
            200,
          );
        }),
      );
      final result = await adapter.complete(request);
      expect(result.data, {
        'characters': ['Alice'],
      });
      expect(result.usage.totalTokens, 27);
    },
  );
  test(
    'classifies invalid keys even for non-JSON error responses without leaking data',
    () async {
      final adapter = OpenAiLlmAdapter(
        baseUrl: Uri.parse('https://example.invalid/v1'),
        apiKey: 'secret-key',
        model: 'model',
        client: MockClient(
          (_) async => http.Response('proxy rejected secret-key', 401),
        ),
      );
      await expectLater(
        adapter.complete(request),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.kind, 'kind', ProviderErrorKind.invalidKey)
              .having(
                (e) => e.toString(),
                'safe message',
                isNot(contains('secret-key')),
              ),
        ),
      );
    },
  );
  for (final api in LlmApi.values) {
    test(
      '${api.name} sends an explicitly configured reasoning effort',
      () async {
        final settings = LlmSettings.fromConfiguration(
          await ProviderConfiguration.load(
            null,
            environment: {
              'LLM_KEY': 'test-key',
              'LLM_MODEL': 'model',
              'LLM_API': api == LlmApi.responses
                  ? 'responses'
                  : 'chat-completions',
              'LLM_REASONING_EFFORT': 'none',
            },
          ),
        );
        expect(settings.reasoningEffort, 'none');
        for (final adapter in [
          settings.createProfileAdapter(),
          settings.createDirectorAdapter(),
        ]) {
          expect(adapter.reasoningEffort, 'none');
          adapter.close();
        }
        final adapter = OpenAiLlmAdapter(
          baseUrl: Uri.parse('https://example.invalid'),
          apiKey: 'test-key',
          model: 'model',
          api: api,
          reasoningEffort: settings.reasoningEffort,
          client: MockClient((incoming) async {
            final body = jsonDecode(incoming.body) as Map;
            expect(
              api == LlmApi.responses
                  ? body['reasoning']
                  : body['reasoning_effort'],
              api == LlmApi.responses ? {'effort': 'none'} : 'none',
            );
            return http.Response(
              jsonEncode(
                api == LlmApi.responses
                    ? {
                        'status': 'completed',
                        'output': [
                          {
                            'type': 'message',
                            'content': [
                              {'type': 'output_text', 'text': '{}'},
                            ],
                          },
                        ],
                      }
                    : {
                        'choices': [
                          {
                            'finish_reason': 'stop',
                            'message': {'content': '{}'},
                          },
                        ],
                      },
              ),
              200,
            );
          }),
        );
        expect((await adapter.complete(request)).data, isEmpty);
      },
    );
    test('${api.name} classifies balance and rate limits', () async {
      for (final row in [
        (429, 'insufficient_quota', ProviderErrorKind.insufficientBalance),
        (429, 'rate_limit_exceeded', ProviderErrorKind.rateLimited),
      ]) {
        final adapter = OpenAiLlmAdapter(
          baseUrl: Uri.parse('https://example.invalid/v1'),
          apiKey: 'secret-key',
          model: 'model',
          api: api,
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {'code': row.$2, 'message': 'secret-key'},
              }),
              row.$1,
            ),
          ),
        );
        await expectLater(
          adapter.complete(request),
          throwsA(
            isA<ProviderException>()
                .having((e) => e.kind, 'kind', row.$3)
                .having(
                  (e) => e.toString(),
                  'safe message',
                  isNot(contains('secret-key')),
                ),
          ),
        );
      }
    });
    test('${api.name} rejects incomplete or refused output', () async {
      final responses = api == LlmApi.chatCompletions
          ? [
              {
                'choices': [
                  {
                    'finish_reason': 'length',
                    'message': {'content': '{}'},
                  },
                ],
              },
              {
                'choices': [
                  {
                    'finish_reason': 'stop',
                    'message': {'content': '{}', 'refusal': 'No'},
                  },
                ],
              },
            ]
          : [
              {'status': 'incomplete', 'output': []},
              {
                'status': 'completed',
                'output': [
                  {
                    'type': 'message',
                    'content': [
                      {'type': 'refusal', 'refusal': 'No'},
                    ],
                  },
                ],
              },
            ];
      for (final response in responses) {
        final adapter = OpenAiLlmAdapter(
          baseUrl: Uri.parse('https://example.invalid/v1'),
          apiKey: 'secret-key',
          model: 'model',
          api: api,
          client: MockClient(
            (_) async => http.Response(jsonEncode(response), 200),
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
      }
    });
  }
  test(
    'distinguishes connection failure and timeout without exposing details',
    () async {
      for (final row in [
        (
          MockClient(
            (_) async =>
                throw http.ClientException('secret-key: Connection closed'),
          ),
          const Duration(seconds: 1),
          'connection_error',
        ),
        (
          MockClient((_) => Completer<http.Response>().future),
          const Duration(milliseconds: 1),
          'timeout',
        ),
      ]) {
        final adapter = OpenAiLlmAdapter(
          baseUrl: Uri.parse('https://example.invalid'),
          apiKey: 'secret-key',
          model: 'model',
          client: row.$1,
          timeout: row.$2,
        );
        await expectLater(
          adapter.complete(request),
          throwsA(
            isA<ProviderException>()
                .having((e) => e.kind, 'kind', ProviderErrorKind.unavailable)
                .having((e) => e.code, 'code', row.$3)
                .having(
                  (e) => e.toString(),
                  'message',
                  isNot(contains('secret-key')),
                )
                .having(
                  (e) => e.toString(),
                  'message',
                  isNot(contains('The provider is unavailable')),
                ),
          ),
        );
      }
    },
  );
}
