import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'provider_exception.dart';
import 'usage_ledger.dart';
import 'request_recovery.dart';

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
    this.maxAttempts = 3,
  });
  final String system;
  final String user;
  final String schemaName;
  final Map<String, Object?> schema;

  /// Total HTTP attempts, including transport and caller-level retries (1–3).
  final int maxAttempts;
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
  const LlmResponse({
    required this.data,
    this.usage = const TokenUsage(),
    this.attempts = 1,
  });
  final Map<String, Object?> data;
  final TokenUsage usage;
  final int attempts;
}

/// One explicitly selected protocol with at most three transport attempts.
class OpenAiLlmAdapter implements LlmAdapter {
  OpenAiLlmAdapter({
    required Uri baseUrl,
    required String apiKey,
    required this.model,
    this.api = LlmApi.chatCompletions,
    this.jsonSchema = true,
    this.reasoningEffort,
    this.stream = true,
    RequestRuntime? runtime,
    http.Client? client,
    UsageLedger? usageLedger,
    this.timeout = const Duration(minutes: 3),
  }) : runtime = runtime ?? RequestRuntime(),
       _baseUrl = baseUrl,
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
  final RequestRuntime runtime;
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

  /// Chat Completions endpoints that answered strict JSON Schema through
  /// Responses instead, by base URL and model, for this process.
  static final _responsesForSchema = <String>{};

  static void forgetSchemaFallbacks() => _responsesForSchema.clear();

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    if (request.maxAttempts < 1 || request.maxAttempts > 3) {
      throw ArgumentError.value(request.maxAttempts, 'maxAttempts');
    }
    final endpoint = '$_baseUrl $model';
    var api = jsonSchema && _responsesForSchema.contains(endpoint)
        ? LlmApi.responses
        : this.api;
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _completeOnce(request, attempt, api);
        if (api != this.api) _responsesForSchema.add(endpoint);
        return response;
      } on ProviderException catch (error) {
        // Some Chat Completions endpoints, such as DeepSeek, only offer JSON
        // object mode. Strict JSON Schema may still be served by Responses at
        // the same base URL; the refused request was not billed.
        if (jsonSchema &&
            error.code == LlmFailure.schemaUnsupported &&
            api == LlmApi.chatCompletions) {
          api = LlmApi.responses;
          attempt--;
          runtime.onEvent('llm: JSON Schema refused; retrying via Responses.');
          continue;
        }
        if (api != this.api && error.code == LlmFailure.requestRejected) {
          _responsesForSchema.remove(endpoint);
          throw _invalid(LlmFailure.schemaUnsupported);
        }
        final retryable =
            error.kind == ProviderErrorKind.unavailable &&
            const {
              'connection_error',
              'timeout',
              'interrupted_stream',
            }.contains(error.code);
        if (!retryable) rethrow;
        if (attempt == request.maxAttempts) {
          runtime.onEvent('llm: retry budget exhausted ($attempt attempts).');
          rethrow;
        }
        await runtime.wait(
          'llm',
          '${error.code}; retry ${attempt + 1}/${request.maxAttempts}',
          Duration(seconds: attempt),
        );
      }
    }
  }

  Future<LlmResponse> _completeOnce(
    LlmRequest request,
    int attempt,
    LlmApi api,
  ) async {
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
    final progress = _ResponseProgress();
    final abort = Completer<void>();
    try {
      final data = await _send(endpoint, body, isChat, progress, abort.future)
          .timeout(
            timeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('Provider request timeout.');
            },
          );
      String content;
      if (isChat) {
        final choice = (data['choices'] as List).first as Map;
        final message = choice['message'] as Map;
        if (message['refusal'] != null) throw _invalid(LlmFailure.refusal);
        final finish = choice['finish_reason'];
        if (finish != 'stop') {
          throw _invalid(switch (finish) {
            'length' => LlmFailure.truncated,
            'content_filter' || 'sensitive' => LlmFailure.contentFilter,
            _ => LlmFailure.malformed,
          });
        }
        content = message['content'] as String;
      } else {
        if (data['status'] != 'completed' || data['error'] != null) {
          final details = data['incomplete_details'];
          final reason = details is Map ? details['reason'] : null;
          throw _invalid(
            reason == 'max_output_tokens'
                ? LlmFailure.truncated
                : reason == 'content_filter' || _moderated(data['error'])
                ? LlmFailure.contentFilter
                : LlmFailure.malformed,
          );
        }
        final parts = <String>[];
        for (final item in data['output'] as List) {
          if ((item as Map)['type'] != 'message') continue;
          for (final part in item['content'] as List) {
            if ((part as Map)['type'] == 'refusal') {
              throw _invalid(LlmFailure.refusal);
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
        attempts: attempt,
        usage: TokenUsage(
          inputTokens: input,
          outputTokens: output,
          totalTokens: usage['total_tokens'] as int? ?? input + output,
        ),
      );
    } on ProviderException {
      rethrow;
    } on TimeoutException {
      if (progress.terminal) throw _invalid(LlmFailure.malformed);
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.unavailable,
        code: 'timeout',
      );
    } on http.ClientException {
      if (progress.terminal) throw _invalid(LlmFailure.malformed);
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.unavailable,
        code: 'connection_error',
      );
    } catch (_) {
      throw _invalid(LlmFailure.malformed);
    } finally {
      if (!abort.isCompleted) abort.complete();
      // A partial stream can have incurred cost. Record known fields once,
      // even when transport recovery needs another request.
      if (progress.accepted) {
        _usageLedger?.record(
          UsageRecord(
            provider: 'llm',
            endpoint: endpoint.toString(),
            model: model,
            requestId: progress.id,
            usage: progress.usage,
          ),
        );
      }
    }
  }

  Future<Map<String, Object?>> _send(
    Uri endpoint,
    Map<String, Object?> body,
    bool isChat,
    _ResponseProgress progress,
    Future<void> abortTrigger,
  ) async {
    final response = await _client.send(
      http.AbortableRequest('POST', endpoint, abortTrigger: abortTrigger)
        ..headers.addAll({
          'authorization': 'Bearer $_apiKey',
          'content-type': 'application/json',
        })
        ..body = jsonEncode(body),
    );
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok && stream) return _readEvents(response.stream, isChat, progress);
    final bytes = await response.stream.toBytes();
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      if (ok) rethrow;
    }
    if (!ok) throw _error(response.statusCode, decoded);
    final data = Map<String, Object?>.from(decoded as Map);
    progress.update(data);
    return data;
  }

  /// Rebuilds the non-streaming response shape so one parser serves both.
  Future<Map<String, Object?>> _readEvents(
    Stream<List<int>> bytes,
    bool isChat,
    _ResponseProgress progress,
  ) async {
    Map<String, Object?>? completed;
    final content = StringBuffer();
    Object? id, finishReason, refusal, usage;
    final lines = bytes.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      // A JSON reply is a protocol mismatch, not an empty connection worth
      // paying for again when a compatible endpoint ignores stream=true.
      if (line.trimLeft().startsWith('{')) {
        final data = jsonDecode(line);
        if (data is Map && data['error'] == null) progress.update(data);
        throw const FormatException('Expected an event stream.');
      }
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;
      if (payload == '[DONE]') break;
      final event = jsonDecode(payload) as Map;
      if (event['error'] != null || event['type'] == 'error') {
        throw _invalid(
          _moderated(event['error'] ?? event)
              ? LlmFailure.contentFilter
              : LlmFailure.malformed,
        );
      }
      if (isChat) {
        if (event['choices'] is List) progress.update(event);
        id ??= event['id'];
        usage = event['usage'] ?? usage;
        for (final choice in event['choices'] as List? ?? const []) {
          final delta = (choice as Map)['delta'] as Map? ?? const {};
          if (delta['content'] case final String text) content.write(text);
          refusal = delta['refusal'] ?? refusal;
          finishReason = choice['finish_reason'] ?? finishReason;
        }
        progress.terminal = finishReason != null || refusal != null;
        if (finishReason != null && usage != null) break;
      } else {
        if (event['response'] case final Map response) {
          progress.update(response);
        }
        if (event['type'] == 'response.output_text.delta') {
          progress.accepted = true;
        }
        if (event['type'] == 'response.refusal.delta' ||
            event['type'] == 'response.refusal.done') {
          progress.accepted = true;
          progress.terminal = true;
        }
        if (const [
          'response.completed',
          'response.incomplete',
          'response.failed',
        ].contains(event['type'])) {
          completed = Map<String, Object?>.from(event['response'] as Map);
          break;
        }
      }
    }
    if (isChat) {
      if (refusal != null) throw _invalid(LlmFailure.refusal);
      if (finishReason == null) {
        throw const ProviderException(
          provider: 'llm',
          kind: ProviderErrorKind.unavailable,
          code: 'interrupted_stream',
        );
      }
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
    // Only refusal events mark a Responses stream terminal before completion.
    if (completed == null && progress.terminal) {
      throw _invalid(LlmFailure.refusal);
    }
    if (completed == null) {
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.unavailable,
        code: 'interrupted_stream',
      );
    }
    return completed;
  }

  ProviderException _error(int status, Object? body) {
    final error = body is Map ? body['error'] : null;
    final code = error is Map ? error['code'] : null;
    final type = error is Map ? error['type'] : null;
    if (status == 401 || code == 'invalid_api_key') {
      return const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidKey,
      );
    }
    if (code == 'insufficient_quota' ||
        type == 'insufficient_quota' ||
        code == 'billing_hard_limit_reached') {
      return const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.insufficientBalance,
      );
    }
    if (_moderated(error)) return _invalid(LlmFailure.contentFilter);
    final param = error is Map ? '${error['param']}' : '';
    final message = error is Map ? '${error['message']}' : '';
    if (status < 500 &&
        (param.contains('response_format') ||
            message.contains('response_format'))) {
      return _invalid(LlmFailure.schemaUnsupported);
    }
    if (status == 429) {
      return const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.rateLimited,
      );
    }
    if (status >= 500) {
      return const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.unavailable,
      );
    }
    return _invalid(LlmFailure.requestRejected);
  }

  static ProviderException _invalid(String code) => ProviderException(
    provider: 'llm',
    kind: ProviderErrorKind.invalidResponse,
    code: code,
  );

  /// Compatible endpoints report moderation with their own codes. Provider
  /// messages are only compared with known fixed phrases, never kept.
  static bool _moderated(Object? error) {
    if (error is! Map) return false;
    final tags = '${error['code']} ${error['type']}'.toLowerCase();
    final message = '${error['message']}'.toLowerCase();
    return const [
          'content_filter',
          'data_inspection',
          'sensitive',
          'moderation',
        ].any(tags.contains) ||
        '${error['code']}' == '1301' ||
        message.contains('content exists risk') ||
        message.contains('high risk');
  }
}

class _ResponseProgress {
  bool accepted = false;
  bool terminal = false;
  String? id;
  Map<String, Object?> usage = {};

  void update(Map data) {
    accepted = true;
    id = data['id']?.toString() ?? id;
    if (data['usage'] is Map) usage = usageFields(data['usage']);
  }
}
