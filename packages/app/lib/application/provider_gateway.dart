import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';

import 'contracts.dart';
import 'provider_store.dart';

typedef LlmFactory = LlmAdapter Function(ProviderConfiguration configuration);
typedef TtsFactory =
    TtsAdapter Function(ProviderConfiguration configuration, String provider);

/// One credential/consent and request-queue boundary for cloud operations.
class ProviderGateway {
  ProviderGateway({
    required this.store,
    required this.providers,
    required this.consents,
    this.profileFactory,
    this.directorFactory,
    this.ttsFactory,
    RequestRuntime? runtime,
  }) : runtime = runtime ?? RequestRuntime();
  final LocalStore store;
  final ProviderStore providers;
  final ConsentBroker consents;
  final LlmFactory? profileFactory;
  final LlmFactory? directorFactory;
  final TtsFactory? ttsFactory;
  final RequestRuntime runtime;
  final queues = <String, ProviderRequestQueue>{};
  ScheduledTask? activeTask;
  VoiceBinding? failedBinding;
  Future<bool> Function(ScheduledTask task, VoiceBinding binding)? rebuild;
  final _rebuilt = <String>{};
  UsageLedger get usage =>
      JsonlUsageLedger(File('${File(store.path).parent.path}/usage.jsonl'));

  Future<void> beforeTask(ScheduledTask task) async {
    activeTask = task;
  }

  Future<bool> recover(ScheduledTask task, ProviderException error) async {
    final binding = failedBinding;
    failedBinding = null;
    if (binding == null || rebuild == null) return false;
    final cast = await Casting(store).getCasting(task.bookId);
    final ids =
        cast.voices.values
            .where(
              (v) =>
                  v.binding.provider == binding.provider &&
                  v.binding.voiceId == binding.voiceId,
            )
            .map((v) => v.id)
            .toSet()
            .toList()
          ..sort();
    final key = '${task.bookId}:${ids.join(',')}';
    if (ids.isEmpty || !_rebuilt.add(key)) return false;
    try {
      final recovered = await rebuild!(task, binding);
      if (!recovered) _rebuilt.remove(key);
      return recovered;
    } catch (_) {
      _rebuilt.remove(key);
      rethrow;
    }
  }

  void resetRecovery(String bookId) =>
      _rebuilt.removeWhere((key) => key.startsWith('$bookId:'));

  LlmAdapter llm({required bool profile}) => _GatewayLlm(this, profile);
  Map<String, TtsAdapter> tts(
    String Function() bookId, {
    String content = 'chapterTextAndCast',
  }) => {
    for (final provider in ['minimax', 'bailian', 'edge'])
      provider: _GatewayTts(this, bookId, provider, content),
  };

  Future<T> withTts<T>(
    String bookId,
    String provider,
    String content,
    Future<T> Function(TtsAdapter adapter) operation,
  ) async {
    final config = await providers.configuration();
    final book = await Library(store).getBook(bookId);
    final injected = ttsFactory?.call(config, provider);
    final session = injected == null
        ? TtsProviderSession.open(
            config,
            providers: {provider},
            runtime: runtime,
            queues: queues,
            usageLedger: usage,
          )
        : null;
    try {
      final endpoint = provider == 'edge'
          ? EdgeTtsAdapter.defaultEndpoint
          : provider == 'minimax'
          ? 'https://api.minimax.io/v1'
          : config.value('bailian', 'region') == 'singapore'
          ? 'https://dashscope-intl.aliyuncs.com/api/v1'
          : 'https://dashscope.aliyuncs.com/api/v1';
      if (!await consents.request(
        bookTitle: book.title,
        provider: provider,
        endpoint: endpoint,
        content: content,
      )) {
        await store.put('generationFailure', bookId, {
          'bookId': bookId,
          'provider': provider,
          'reason': 'consentDeclined',
        });
        throw ProviderException(
          provider: provider,
          kind: ProviderErrorKind.invalidConfiguration,
          code: 'consentDeclined',
        );
      }
      await store.delete('generationFailure', bookId);
      return await operation(injected ?? session!.adapters[provider]!);
    } finally {
      session?.close();
    }
  }
}

class _GatewayLlm implements LlmAdapter {
  _GatewayLlm(this.gateway, this.profile);
  final ProviderGateway gateway;
  final bool profile;
  @override
  String get model => profile || gateway.providers.value.directorModel.isEmpty
      ? gateway.providers.value.profileModel
      : gateway.providers.value.directorModel;
  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final bookId = gateway.activeTask!.bookId;
    final config = await gateway.providers.configuration();
    final settings = LlmSettings.fromConfiguration(config);
    final book = await Library(gateway.store).getBook(bookId);
    final failure = profile ? 'profileFailure' : 'generationFailure';
    if (!await gateway.consents.request(
      bookTitle: book.title,
      provider: 'llm',
      endpoint: settings.baseUrl.toString(),
      content: 'chapterTextAndCast',
    )) {
      await gateway.store.put(failure, bookId, {
        'bookId': bookId,
        'provider': 'llm',
        'reason': 'consentDeclined',
      });
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidConfiguration,
        code: 'consentDeclined',
      );
    }
    await gateway.store.delete(failure, bookId);
    final adapter =
        (profile ? gateway.profileFactory : gateway.directorFactory)?.call(
          config,
        ) ??
        (profile
            ? settings.createProfileAdapter(
                runtime: gateway.runtime,
                usageLedger: gateway.usage,
              )
            : settings.createDirectorAdapter(
                runtime: gateway.runtime,
                usageLedger: gateway.usage,
              ));
    try {
      return await adapter.complete(request);
    } finally {
      if (adapter is OpenAiLlmAdapter) adapter.close();
    }
  }
}

class _GatewayTts implements TtsAdapter, VoiceDesignAdapter {
  _GatewayTts(this.gateway, this.bookId, this.provider, this.content);
  final ProviderGateway gateway;
  final String Function() bookId;
  @override
  final String provider;
  final String content;
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) {
    if (provider == 'edge') {
      final adapter = EdgeTtsAdapter();
      try {
        return adapter.capabilitiesFor(binding);
      } finally {
        adapter.close();
      }
    }
    // Capabilities are local; constructing an adapter with a sentinel credential
    // opens no request. The real credential is read only at the paid boundary.
    if (provider == 'minimax') {
      final adapter = MiniMaxTtsAdapter(apiKey: 'capability-only');
      try {
        return adapter.capabilitiesFor(binding);
      } finally {
        adapter.close();
      }
    }
    final adapter = BailianTtsAdapter(
      apiKey: 'capability-only',
      region: gateway.providers.value.region == ProviderRegion.beijing
          ? BailianRegion.beijing
          : BailianRegion.singapore,
    );
    try {
      return adapter.capabilitiesFor(binding);
    } finally {
      adapter.close();
    }
  }

  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    try {
      return await gateway.withTts(
        bookId(),
        provider,
        content,
        (a) => a.synthesize(request),
      );
    } on ProviderException catch (error) {
      if (error.kind == ProviderErrorKind.invalidVoice) {
        gateway.failedBinding = request.binding;
      }
      rethrow;
    }
  }

  @override
  Future<DesignedVoice> design(VoiceDesignRequest request) =>
      gateway.withTts(bookId(), provider, 'voiceSample', (a) {
        if (a is! VoiceDesignAdapter) {
          throw ProviderException(
            provider: provider,
            kind: ProviderErrorKind.invalidConfiguration,
          );
        }
        return (a as VoiceDesignAdapter).design(request);
      });
}

String providerReason(ProviderErrorKind? reason, [String? code]) =>
    switch (reason) {
      ProviderErrorKind.invalidKey => 'unauthorized',
      ProviderErrorKind.insufficientBalance => 'quotaExceeded',
      ProviderErrorKind.rateLimited => 'rateLimited',
      ProviderErrorKind.unavailable => 'network',
      ProviderErrorKind.invalidResponse => invalidResponseReason(code),
      ProviderErrorKind.invalidVoice => 'voiceUnavailable',
      ProviderErrorKind.invalidConfiguration => 'missingKey',
      null => 'interrupted',
    };

/// Distinguishes a request the model setting cannot serve from content that
/// failed after the automatic retry.
String invalidResponseReason(String? code) => switch (code) {
  LlmFailure.requestRejected => 'requestRejected',
  LlmFailure.schemaUnsupported => 'schemaUnsupported',
  LlmFailure.contentFilter || LlmFailure.refusal => 'contentRejected',
  LlmFailure.truncated => 'truncated',
  _ => 'invalidResponse',
};
