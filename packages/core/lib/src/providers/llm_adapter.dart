import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'provider_exception.dart';
import 'usage_ledger.dart';

enum LlmApi { chatCompletions, responses }

/// JSON generation boundary shared by profiling and directing.
abstract interface class LlmAdapter {
  String get model;
  Future<LlmResponse> complete(LlmRequest request);
}

class LlmRequest {
  const LlmRequest({
    required this.system,
    required this.user,
    required this.schemaName,
    required this.schema,
  });
  final String system;
  final String user;
  final String schemaName;
  final Map<String, Object?> schema;
}

class TokenUsage {
  const TokenUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
  });
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  TokenUsage operator +(TokenUsage other) => TokenUsage(
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
    totalTokens: totalTokens + other.totalTokens,
  );
  Map<String, Object?> toJson() => {
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'totalTokens': totalTokens,
  };
}

class LlmResponse {
  const LlmResponse({required this.data, this.usage = const TokenUsage()});
  final Map<String, Object?> data;
  final TokenUsage usage;
}

/// One explicitly selected OpenAI-compatible protocol. No paid retry/fallback.
class OpenAiLlmAdapter implements LlmAdapter {
  OpenAiLlmAdapter({
    required Uri baseUrl,
    required String apiKey,
    required this.model,
    this.api = LlmApi.chatCompletions,
    this.jsonSchema = true,
    this.reasoningEffort,
    this.stream = false,
    http.Client? client,
    UsageLedger? usageLedger,
    this.timeout = const Duration(minutes: 3),
  }) : _baseUrl = baseUrl,
       _apiKey = apiKey,
       _usageLedger = usageLedger,
       _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (!['https', 'http'].contains(baseUrl.scheme) ||
        baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        baseUrl.hasQuery ||
        baseUrl.hasFragment ||
        apiKey.isEmpty ||
        model.isEmpty) {
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
  }
  final Uri _baseUrl;
  final String _apiKey;
  final UsageLedger? _usageLedger;
  @override
  final String model;
  final LlmApi api;
  final bool jsonSchema;
  final String? reasoningEffort;

  /// Streams server-sent events so the connection never sits idle; proxies
  /// and mobile networks may drop a silent connection before a long answer.
  final bool stream;
  final Duration timeout;
  final http.Client _client;
  final bool _ownsClient;

  void close() {
    if (_ownsClient) _client.close();
  }

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final path = _baseUrl.path.replaceFirst(RegExp(r'/$'), '');
    final isChat = api == LlmApi.chatCompletions;
    final endpoint = _baseUrl.replace(
      path: '$path/${isChat ? 'chat/completions' : 'responses'}',
    );
    final body = <String, Object?>{
      'model': model,
      if (reasoningEffort != null)
        if (isChat)
          'reasoning_effort': reasoningEffort
        else
          'reasoning': {'effort': reasoningEffort},
      isChat ? 'messages' : 'input': [
        {'role': 'system', 'content': request.system},
        {'role': 'user', 'content': request.user},
      ],
      if (isChat)
        'response_format': jsonSchema
            ? {
                'type': 'json_schema',
                'json_schema': {
                  'name': request.schemaName,
                  'strict': true,
                  'schema': request.schema,
                },
              }
            : {'type': 'json_object'},
      if (!isChat)
        'text': {
          'format': jsonSchema
              ? {
                  'type': 'json_schema',
                  'name': request.schemaName,
                  'strict': true,
                  'schema': request.schema,
                }
              : {'type': 'json_object'},
        },
      if (!isChat) 'store': false,
      if (stream) 'stream': true,
      if (stream && isChat) 'stream_options': {'include_usage': true},
    };
    try {
      final data = await _send(endpoint, body, isChat).timeout(timeout);
      // Record before validating content: a rejected answer is still billed.
      _usageLedger?.record(
        UsageRecord(
          provider: 'llm',
          endpoint: endpoint.toString(),
          model: model,
          requestId: data['id']?.toString(),
          usage: usageFields(data['usage']),
        ),
      );
      String content;
      if (isChat) {
        final choice = (data['choices'] as List).first as Map;
        final message = choice['message'] as Map;
        if (choice['finish_reason'] != 'stop' || message['refusal'] != null) {
          throw const ProviderException(
            provider: 'llm',
            kind: ProviderErrorKind.invalidResponse,
          );
        }
        content = message['content'] as String;
      } else {
        if (data['status'] != 'completed' || data['error'] != null) {
          throw const ProviderException(
            provider: 'llm',
            kind: ProviderErrorKind.invalidResponse,
          );
        }
        final parts = <String>[];
        for (final item in data['output'] as List) {
          if ((item as Map)['type'] != 'message') continue;
          for (final part in item['content'] as List) {
            if ((part as Map)['type'] == 'refusal') {
              throw const ProviderException(
                provider: 'llm',
                kind: ProviderErrorKind.invalidResponse,
              );
            }
            if (part['type'] == 'output_text') {
              parts.add(part['text'] as String);
            }
          }
        }
        content = parts.join();
      }
      final result = Map<String, Object?>.from(jsonDecode(content) as Map);
      final usage = data['usage'] as Map? ?? {};
      final input =
          usage[isChat ? 'prompt_tokens' : 'input_tokens'] as int? ?? 0;
      final output =
          usage[isChat ? 'completion_tokens' : 'output_tokens'] as int? ?? 0;
      return LlmResponse(
        data: result,
        usage: TokenUsage(
          inputTokens: input,
          outputTokens: output,
          totalTokens: usage['total_tokens'] as int? ?? input + output,
        ),
      );
    } on ProviderException {
      rethrow;
    } on TimeoutException {
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.unavailable,
        code: 'timeout',
      );
    } on http.ClientException {
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.unavailable,
        code: 'connection_error',
      );
    } catch (_) {
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidResponse,
      );
    }
  }

  Future<Map<String, Object?>> _send(
    Uri endpoint,
    Map<String, Object?> body,
    bool isChat,
  ) async {
    final response = await _client.send(
      http.Request('POST', endpoint)
        ..headers.addAll({
          'authorization': 'Bearer $_apiKey',
          'content-type': 'application/json',
        })
        ..body = jsonEncode(body),
    );
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok && stream) return _readEvents(response.stream, isChat);
    final bytes = await response.stream.toBytes();
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      if (ok) rethrow;
    }
    if (!ok) throw _error(response.statusCode, decoded);
    return Map<String, Object?>.from(decoded as Map);
  }

  /// Rebuilds the non-streaming response shape so one parser serves both.
  Future<Map<String, Object?>> _readEvents(
    Stream<List<int>> bytes,
    bool isChat,
  ) async {
    Map<String, Object?>? completed;
    final content = StringBuffer();
    Object? id, finishReason, refusal, usage;
    final lines = bytes.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;
      final event = jsonDecode(payload) as Map;
      if (isChat) {
        id ??= event['id'];
        usage = event['usage'] ?? usage;
        for (final choice in event['choices'] as List? ?? const []) {
          final delta = (choice as Map)['delta'] as Map? ?? const {};
          if (delta['content'] case final String text) content.write(text);
          refusal = delta['refusal'] ?? refusal;
          finishReason = choice['finish_reason'] ?? finishReason;
        }
      } else if (const [
        'response.completed',
        'response.incomplete',
        'response.failed',
      ].contains(event['type'])) {
        completed = Map<String, Object?>.from(event['response'] as Map);
      }
    }
    if (isChat) {
      if (finishReason == null) throw const FormatException('Stream ended.');
      return {
        'id': id,
        'choices': [
          {
            'finish_reason': finishReason,
            'message': {'content': content.toString(), 'refusal': refusal},
          },
        ],
        'usage': usage,
      };
    }
    if (completed == null) throw const FormatException('Stream ended.');
    return completed;
  }

  ProviderException _error(int status, Object? body) {
    final error = body is Map ? body['error'] : null;
    final code = error is Map ? error['code'] : null;
    final type = error is Map ? error['type'] : null;
    final kind = status == 401 || code == 'invalid_api_key'
        ? ProviderErrorKind.invalidKey
        : code == 'insufficient_quota' ||
              type == 'insufficient_quota' ||
              code == 'billing_hard_limit_reached'
        ? ProviderErrorKind.insufficientBalance
        : status == 429
        ? ProviderErrorKind.rateLimited
        : status >= 500
        ? ProviderErrorKind.unavailable
        : ProviderErrorKind.invalidResponse;
    return ProviderException(provider: 'llm', kind: kind);
  }
}
