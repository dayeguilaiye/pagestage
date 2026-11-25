import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';

import 'contracts.dart';
import 'provider_store.dart';

typedef LlmFactory = LlmAdapter Function(ProviderConfiguration configuration);
typedef TtsFactory =
    TtsAdapter Function(ProviderConfiguration configuration, String provider);

/// One credential, consent and request-queue boundary for every engine. A
/// device engine passes through the same gate; it simply has no endpoint to
/// ask consent for and no key to read.
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
  AppEngines get engines => providers.engines;
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

  /// The ledger of what providers report spending, each line labelled with
  /// the book it was spent on so the reader can see it per book.
  UsageLedger usageFor(String bookId) => JsonlUsageLedger(
    File('${File(store.path).parent.path}/usage.jsonl'),
    labels: {'bookId': bookId},
  );

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

  /// One adapter per voice engine of this build, each opened and gated only
  /// when it is asked to speak.
  Map<String, TtsAdapter> tts(
    String Function() bookId, {
    String content = 'chapterTextAndCast',
  }) => {
    for (final provider in engines.voice.ids)
      provider: _GatewayTts(this, bookId, provider, content),
  };

  /// The presets of the voice engines in use, under their current settings.
  List<VoicePreset> catalog() => engines.voice.catalog(
    providers.settings,
    only: providers.value.voiceProviders,
  );

  /// Book text goes to [endpoint] only with the reader's agreement; an
  /// engine without one keeps everything on the device. Work in the
  /// background never asks: it pauses until the reader agrees from the
  /// banner. Only what the reader just tapped, such as a voice sample, may
  /// ask on the spot.
  Future<void> _consent(
    String bookId,
    String provider,
    Uri? endpoint,
    String content,
    String failure, {
    bool interactive = false,
  }) async {
    if (endpoint != null) {
      final granted = await consents.granted(provider, endpoint.toString());
      var accepted = granted;
      if (!granted && interactive) {
        final book = await Library(store).getBook(bookId);
        accepted = await consents.request(
          bookTitle: book.title,
          provider: provider,
          endpoint: endpoint.toString(),
          content: content,
        );
      }
      if (!accepted) {
        final reason = interactive ? 'consentDeclined' : 'consentNeeded';
        await store.put(failure, bookId, {
          'bookId': bookId,
          'provider': provider,
          'reason': reason,
        });
        throw ProviderException(
          provider: provider,
          kind: ProviderErrorKind.invalidConfiguration,
          code: reason,
        );
      }
    }
    await store.delete(failure, bookId);
  }

  /// Asks the reader to agree to sending [bookId]'s text to [provider],
  /// as configured now; true when it needs no agreement or they agree.
  Future<bool> ask(String bookId, String provider) async {
    final config = await providers.configuration();
    final Uri? endpoint;
    try {
      endpoint = provider == 'llm'
          ? engines.language.active(config).endpoint(config)
          : engines.voice.require(provider).endpoint(config);
    } on Object {
      return true;
    }
    if (endpoint == null) return true;
    final book = await Library(store).getBook(bookId);
    return consents.request(
      bookTitle: book.title,
      provider: provider,
      endpoint: endpoint.toString(),
      content: 'chapterTextAndCast',
    );
  }

  Future<T> withTts<T>(
    String bookId,
    String provider,
    String content,
    Future<T> Function(TtsAdapter adapter) operation,
  ) async {
    // An engine switched off, or one missing its key or its model, is never
    // called; the reason names which, so the reader knows what to change.
    final view = providers.value.engine(provider);
    if (view == null || !view.on || !view.ready) {
      final reason = switch (view?.status) {
        EngineStatus.ready => 'providerDisabled',
        EngineStatus.needsSetup => 'missingKey',
        EngineStatus.notInstalled => 'engineNotInstalled',
        EngineStatus.unavailable || null => 'engineUnavailable',
      };
      await store.put('generationFailure', bookId, {
        'bookId': bookId,
        'provider': provider,
        'reason': reason,
      });
      throw ProviderException(
        provider: provider,
        kind: ProviderErrorKind.invalidConfiguration,
        code: reason,
      );
    }
    final config = await providers.configuration();
    final injected = ttsFactory?.call(config, provider);
    final session = injected == null
        ? TtsProviderSession.open(
            config,
            providers: {provider},
            engines: engines.voice,
            runtime: runtime,
            queues: queues,
            usageLedger: usageFor(bookId),
          )
        : null;
    try {
      await _consent(
        bookId,
        provider,
        engines.voice.require(provider).endpoint(config),
        content,
        'generationFailure',
        interactive: content == 'voiceSample',
      );
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
  LlmRole get _role => profile ? LlmRole.profile : LlmRole.director;
  @override
  String get model {
    final settings = gateway.providers.settings;
    try {
      return gateway.engines.language.active(settings).model(settings, _role);
    } on ProviderException {
      return '';
    }
  }

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final bookId = gateway.activeTask!.bookId;
    final config = await gateway.providers.configuration();
    final engine = gateway.engines.language.active(config);
    await gateway._consent(
      bookId,
      'llm',
      engine.endpoint(config),
      'chapterTextAndCast',
      profile ? 'profileFailure' : 'generationFailure',
    );
    final adapter =
        (profile ? gateway.profileFactory : gateway.directorFactory)?.call(
          config,
        ) ??
        engine.open(
          config,
          _role,
          runtime: gateway.runtime,
          usageLedger: gateway.usageFor(bookId),
        );
    try {
      return await adapter.complete(request);
    } finally {
      closeLlm(adapter);
    }
  }
}

class _GatewayTts implements PairedTtsAdapter, VoiceDesignAdapter {
  _GatewayTts(this.gateway, this.bookId, this.provider, this.content);
  final ProviderGateway gateway;
  final String Function() bookId;
  @override
  final String provider;
  final String content;

  // Capabilities are local to the engine and need no credential.
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) => gateway.engines.voice
      .require(provider)
      .capabilitiesFor(binding, gateway.providers.settings);

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
  Future<(TtsAudio, TtsAudio)> synthesizePair(
    TtsRequest first,
    TtsRequest second,
  ) => gateway.withTts(
    bookId(),
    provider,
    content,
    (a) => (a as PairedTtsAdapter).synthesizePair(first, second),
  );

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
      ProviderErrorKind.unavailable
          when code == 'ming_unavailable' || code == 'ming_synthesis' =>
        'localSynthesisFailed',
      ProviderErrorKind.unavailable => 'network',
      ProviderErrorKind.invalidResponse => invalidResponseReason(code),
      ProviderErrorKind.invalidVoice => 'voiceUnavailable',
      ProviderErrorKind.invalidConfiguration => configurationReason(code),
      null => 'interrupted',
    };

/// Why an engine could not be used at all: the gateway's own reasons pass
/// through; anything else is a missing or wrong setting.
String configurationReason(String? code) => switch (code) {
  'providerDisabled' ||
  'engineNotInstalled' ||
  'engineUnavailable' ||
  'consentNeeded' ||
  'consentDeclined' => code!,
  _ => 'missingKey',
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
