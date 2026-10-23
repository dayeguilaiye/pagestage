import '../provider_configuration.dart';
import 'llm_adapter.dart';
import 'provider_exception.dart';
import 'usage_ledger.dart';

/// Two model slots sharing one explicit endpoint and API protocol.
class LlmSettings {
  LlmSettings._({
    required this.baseUrl,
    required this.api,
    required String key,
    required this.profileModel,
    required this.directorModel,
    required this.jsonSchema,
    required this.reasoningEffort,
    required this.stream,
  }) : _key = key;
  final Uri baseUrl;
  final LlmApi api;
  final String _key;
  final String profileModel;
  final String directorModel;
  final bool jsonSchema;
  final String? reasoningEffort;
  final bool stream;

  factory LlmSettings.fromConfiguration(ProviderConfiguration config) {
    final common = config.value(
      'llm',
      'model',
      environmentVariable: 'LLM_MODEL',
    );
    final profile =
        config.value(
          'llm',
          'profileModel',
          environmentVariable: 'LLM_PROFILE_MODEL',
        ) ??
        common;
    final director =
        config.value(
          'llm',
          'directorModel',
          environmentVariable: 'LLM_DIRECTOR_MODEL',
        ) ??
        profile;
    final key = config.value('llm', 'key', environmentVariable: 'LLM_KEY');
    final endpoint =
        config.value('llm', 'baseUrl', environmentVariable: 'LLM_BASE_URL') ??
        'https://api.openai.com/v1';
    final api =
        config.value('llm', 'api', environmentVariable: 'LLM_API') ??
        'chat-completions';
    final mode =
        config.value('llm', 'jsonMode', environmentVariable: 'LLM_JSON_MODE') ??
        'schema';
    final stream =
        config.value('llm', 'stream', environmentVariable: 'LLM_STREAM') ??
        'false';
    final url = Uri.tryParse(endpoint);
    if (profile == null ||
        director == null ||
        key == null ||
        url == null ||
        !['http', 'https'].contains(url.scheme) ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment ||
        !['chat-completions', 'responses'].contains(api) ||
        !['schema', 'object'].contains(mode) ||
        !['true', 'false'].contains(stream)) {
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    return LlmSettings._(
      baseUrl: url,
      api: api == 'responses' ? LlmApi.responses : LlmApi.chatCompletions,
      key: key,
      profileModel: profile,
      directorModel: director,
      jsonSchema: mode == 'schema',
      reasoningEffort: config.value(
        'llm',
        'reasoningEffort',
        environmentVariable: 'LLM_REASONING_EFFORT',
      ),
      stream: stream == 'true',
    );
  }

  OpenAiLlmAdapter createProfileAdapter({UsageLedger? usageLedger}) =>
      OpenAiLlmAdapter(
        baseUrl: baseUrl,
        apiKey: _key,
        model: profileModel,
        api: api,
        jsonSchema: jsonSchema,
        reasoningEffort: reasoningEffort,
        stream: stream,
        usageLedger: usageLedger,
      );
  OpenAiLlmAdapter createDirectorAdapter({UsageLedger? usageLedger}) =>
      OpenAiLlmAdapter(
        baseUrl: baseUrl,
        apiKey: _key,
        model: directorModel,
        api: api,
        jsonSchema: jsonSchema,
        reasoningEffort: reasoningEffort,
        stream: stream,
        usageLedger: usageLedger,
      );
}
