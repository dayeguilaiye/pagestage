import '../provider_configuration.dart';
import 'llm_adapter.dart';
import 'provider_exception.dart';

/// Two model slots sharing one explicit endpoint and API protocol.
class LlmSettings {
  LlmSettings._({
    required this.baseUrl,
    required this.api,
    required String key,
    required this.profileModel,
    required this.directorModel,
    required this.jsonSchema,
  }) : _key = key;
  final Uri baseUrl;
  final LlmApi api;
  final String _key;
  final String profileModel;
  final String directorModel;
  final bool jsonSchema;

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
        !['schema', 'object'].contains(mode)) {
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
    );
  }

  OpenAiLlmAdapter createProfileAdapter() => OpenAiLlmAdapter(
    baseUrl: baseUrl,
    apiKey: _key,
    model: profileModel,
    api: api,
    jsonSchema: jsonSchema,
  );
  OpenAiLlmAdapter createDirectorAdapter() => OpenAiLlmAdapter(
    baseUrl: baseUrl,
    apiKey: _key,
    model: directorModel,
    api: api,
    jsonSchema: jsonSchema,
  );
}
