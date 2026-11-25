import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pagestage_core/pagestage_core.dart';

import 'contracts.dart';

abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class PlatformSecretStore implements SecretStore {
  const PlatformSecretStore();
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  @override
  Future<String?> read(String key) => _storage.read(key: 'pagestage.$key');
  @override
  Future<void> write(String key, String? value) => value == null
      ? _storage.delete(key: 'pagestage.$key')
      : _storage.write(key: 'pagestage.$key', value: value);
}

/// The language and voice engines of this build. The app adds its device
/// engines here; everything else finds them through these registries.
class AppEngines {
  AppEngines({TtsEngines? voice, LlmEngines? language})
    : voice = voice ?? standardTtsEngines,
      language = language ?? standardLlmEngines;
  final TtsEngines voice;
  final LlmEngines language;
}

/// The reader's engine settings. Values that are not secret live in the
/// local store; secrets live in the platform's secure storage under
/// `<engine>.<setting>` and are only ever read into a [ProviderConfiguration].
class ProviderStore extends ValueNotifier<ProviderPreferences>
    implements Providers {
  ProviderStore._(this.store, this.secrets, this.engines)
    : super(const ProviderPreferences());
  final LocalStore store;
  final SecretStore secrets;
  final AppEngines engines;
  Future<void> _writes = Future.value();

  /// The language engine in use.
  String _language = '';
  final _on = <String, bool>{};
  final _values = <String, Map<String, String>>{};

  /// Settings without their secrets: enough for presets, capabilities and
  /// endpoints, which need no credential.
  ProviderConfiguration get settings => _settings;
  ProviderConfiguration _settings = ProviderConfiguration.fromValues(const {});

  Iterable<Engine> get _all => [...engines.language.all, ...engines.voice.all];

  static Future<ProviderStore> open(
    LocalStore store,
    SecretStore secrets, {
    AppEngines? engines,
  }) async {
    final service = ProviderStore._(store, secrets, engines ?? AppEngines());
    final saved = await store.get('settings', 'engines');
    if (saved != null) {
      service._language = saved['language'] as String? ?? '';
      for (final entry in (saved['engines'] as Map).entries) {
        final engine = Map<String, Object?>.from(entry.value as Map);
        service._on[entry.key as String] = engine['on'] as bool? ?? false;
        service._values[entry.key as String] = Map<String, String>.from(
          engine['values'] as Map? ?? const {},
        );
      }
    } else if (await store.get('settings', 'providers') case final old?) {
      // Settings saved before engines were registered by name.
      service._values['llm'] = {
        'baseUrl': ?(old['baseUrl'] as String?),
        'api': old['protocol'] == 'responses'
            ? 'responses'
            : 'chat-completions',
        'profileModel': ?(old['profileModel'] as String?),
        'directorModel': ?(old['directorModel'] as String?),
      };
      service._values['bailian'] = {'region': ?(old['region'] as String?)};
      service._on.addAll({
        'minimax': old['minimaxOn'] as bool? ?? true,
        'bailian': old['bailianOn'] as bool? ?? true,
        'edge': old['edgeOn'] as bool? ?? false,
      });
    }
    if (service.engines.language[service._language] == null) {
      service._language = service.engines.language.all.firstOrNull?.id ?? '';
    }
    await service._publish();
    return service;
  }

  /// A voice engine that asks for a secret is on from the start: nothing is
  /// sent until its key is stored, and storing it is the reader's choice.
  /// The others wait for their switch.
  bool _isOn(TtsEngine engine) =>
      _on[engine.id] ??
      engine.fields.any((field) => field.kind == EngineFieldKind.secret);

  /// Set when the platform's secure storage would not answer, so the app
  /// still opens and says why the keys are missing.
  bool _secretsUnavailable = false;

  Future<String?> _secret(String engineId, String field) async {
    try {
      final value = await secrets.read('$engineId.$field');
      if (value != null && value.isNotEmpty) return value;
      // Keys stored before engines had settings by name.
      if (field != 'key') return null;
      final legacy = await secrets.read(engineId);
      return legacy == null || legacy.isEmpty ? null : legacy;
    } catch (_) {
      _secretsUnavailable = true;
      return null;
    }
  }

  Future<ProviderConfiguration> _configuration({required bool secret}) async {
    final sections = <String, Map<String, String>>{};
    for (final engine in _all) {
      final section = {...?_values[engine.id]};
      if (secret) {
        for (final field in engine.fields) {
          if (field.kind != EngineFieldKind.secret) continue;
          final value = await _secret(engine.id, field.name);
          if (value != null) section[field.name] = value;
        }
      }
      sections[engine.id] = section;
    }
    (sections['llm'] ??= {})['engine'] = _language;
    return ProviderConfiguration.fromValues(sections);
  }

  /// Rebuilds what screens see from the stored settings and secrets.
  Future<void> _publish() async {
    final full = await _configuration(secret: true);
    _settings = await _configuration(secret: false);
    final views = <EngineView>[];
    for (final engine in _all) {
      final stored = <String>{};
      for (final field in engine.fields) {
        if (field.kind == EngineFieldKind.secret &&
            await _secret(engine.id, field.name) != null) {
          stored.add(field.name);
        }
      }
      var traits = const <EngineTrait>{};
      var voiceCount = 0;
      if (engine is TtsEngine) {
        try {
          final presets = engine.presets(_settings);
          voiceCount = presets.length;
          final capabilities = presets.isEmpty
              ? null
              : engine.capabilitiesFor(presets.first.binding, _settings);
          traits = {
            if (capabilities != null) ...{
              if (capabilities.emotions.length > 1) EngineTrait.emotion,
              if (capabilities.instruction) EngineTrait.instruction,
              if (capabilities.cues.isNotEmpty) EngineTrait.vocalCues,
              if (capabilities.prosody) EngineTrait.pacing,
            },
            if (engine.designModel(_settings) != null) EngineTrait.voiceDesign,
          };
        } on ProviderException {
          // An engine that cannot describe itself shows no traits.
        }
      }
      views.add(
        EngineView(
          id: engine.id,
          kind: engine is TtsEngine ? EngineKind.voice : EngineKind.language,
          site: engine.locality == EngineLocality.device
              ? EngineSite.device
              : EngineSite.cloud,
          status: EngineStatus.values.byName(engine.readiness(full).name),
          on: engine is TtsEngine ? _isOn(engine) : engine.id == _language,
          settings: [
            for (final field in engine.fields)
              if (!field.advanced)
                EngineSetting(
                  name: field.name,
                  kind: EngineSettingKind.values.byName(field.kind.name),
                  options: field.options,
                  fallback: field.fallback,
                  required: field.required,
                ),
          ],
          values: Map.unmodifiable({...?_values[engine.id]}),
          secrets: Set.unmodifiable(stored),
          traits: traits,
          voiceCount: voiceCount,
        ),
      );
    }
    value = ProviderPreferences(
      engines: List.unmodifiable(views),
      secretsUnavailable: _secretsUnavailable,
    );
  }

  Future<void> _save(Future<void> Function() change) {
    final operation = _writes.then((_) async {
      await change();
      await store.put('settings', 'engines', {
        'language': _language,
        'engines': {
          for (final engine in _all)
            engine.id: {
              if (engine is TtsEngine) 'on': _isOn(engine),
              'values': _values[engine.id] ?? const <String, String>{},
            },
        },
      });
      await _publish();
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Engine _engine(String id) =>
      _all.where((engine) => engine.id == id).firstOrNull ??
      (throw ProviderException(
        provider: id,
        kind: ProviderErrorKind.invalidConfiguration,
      ));

  @override
  Future<void> configure(
    String engineId, {
    Map<String, String> values = const {},
    Map<String, String> secrets = const {},
  }) {
    final engine = _engine(engineId);
    for (final entry in {...values, ...secrets}.entries) {
      final field = engine.fields
          .where((field) => field.name == entry.key)
          .firstOrNull;
      final text = entry.value.trim();
      final secret = field?.kind == EngineFieldKind.secret;
      final valid =
          field != null &&
          secret == secrets.containsKey(entry.key) &&
          (field.kind != EngineFieldKind.choice ||
              field.options.contains(text)) &&
          (field.name != 'baseUrl' || text.isEmpty || _validUrl(text));
      if (!valid) {
        throw ProviderException(
          provider: engineId,
          kind: ProviderErrorKind.invalidConfiguration,
        );
      }
    }
    return _save(() async {
      for (final entry in secrets.entries) {
        final text = entry.value.trim();
        await this.secrets.write(
          '$engineId.${entry.key}',
          text.isEmpty ? null : text,
        );
        if (text.isEmpty && entry.key == 'key') {
          await this.secrets.write(engineId, null);
        }
        // A key typed in now means the reader wants that engine used.
        if (text.isNotEmpty && engine is TtsEngine) _on[engineId] = true;
      }
      final section = _values[engineId] ??= {};
      for (final entry in values.entries) {
        final text = entry.value.trim();
        if (text.isEmpty) {
          section.remove(entry.key);
        } else {
          section[entry.key] = text;
        }
      }
    });
  }

  static bool _validUrl(String text) {
    final url = Uri.tryParse(text);
    return url != null &&
        const ['http', 'https', 'ws', 'wss'].contains(url.scheme) &&
        url.host.isNotEmpty &&
        url.userInfo.isEmpty &&
        !url.hasQuery &&
        !url.hasFragment;
  }

  @override
  Future<void> switchVoice(String engineId, bool on) {
    if (_engine(engineId) is! TtsEngine) {
      throw ArgumentError.value(engineId, 'engineId');
    }
    return _save(() async => _on[engineId] = on);
  }

  @override
  Future<void> selectLanguage(String engineId) {
    if (engines.language[engineId] == null) {
      throw ArgumentError.value(engineId, 'engineId');
    }
    return _save(() async => _language = engineId);
  }

  @override
  Future<String?> endpoint(String engineId) async {
    final config = await configuration();
    final Engine? engine =
        engines.language[engineId] ?? engines.voice[engineId];
    try {
      return engine?.endpoint(config)?.toString();
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> test(
    String engineId, {
    Map<String, String> values = const {},
    Map<String, String> secrets = const {},
  }) async {
    final engine = _engine(engineId);
    final stored = await configuration();
    final sections = <String, Map<String, String>>{};
    for (final other in _all) {
      final section = <String, String>{};
      for (final field in other.fields) {
        final value = stored.value(other.id, field.name);
        if (value != null) section[field.name] = value;
      }
      sections[other.id] = section;
    }
    final section = sections[engineId]!;
    for (final entry in {...values, ...secrets}.entries) {
      final text = entry.value.trim();
      text.isEmpty ? section.remove(entry.key) : section[entry.key] = text;
    }
    if (engine is LlmEngine) (sections['llm'] ??= {})['engine'] = engineId;
    final config = ProviderConfiguration.fromValues(sections);
    try {
      if (engine is LlmEngine) {
        final adapter = engine.open(
          config,
          LlmRole.profile,
          runtime: RequestRuntime(),
        );
        try {
          await adapter.complete(
            const LlmRequest(
              system: 'Answer with the JSON object the schema describes.',
              user: 'Connection check: answer ok true.',
              schemaName: 'check',
              schema: {
                'type': 'object',
                'properties': {
                  'ok': {'type': 'boolean'},
                },
                'required': ['ok'],
                'additionalProperties': false,
              },
              maxAttempts: 1,
            ),
          );
        } finally {
          closeLlm(adapter);
        }
      } else if (engine is TtsEngine) {
        final presets = engine.presets(config);
        if (presets.isEmpty) return 'engineUnavailable';
        final preset =
            presets.where((p) => p.languages.contains('zh')).firstOrNull ??
            presets.first;
        final opened = engine.open(config);
        try {
          await opened.adapter.synthesize(
            TtsRequest(
              text: preset.languages.contains('zh') ? '你好。' : 'Hello.',
              language: preset.languages.contains('zh') ? 'zh' : 'en',
              binding: preset.binding,
            ),
          );
        } finally {
          opened.close();
        }
      }
      return null;
    } on ProviderException catch (error) {
      return switch (error.kind) {
        ProviderErrorKind.invalidKey => 'unauthorized',
        ProviderErrorKind.insufficientBalance => 'quotaExceeded',
        ProviderErrorKind.rateLimited => 'rateLimited',
        ProviderErrorKind.unavailable => 'network',
        ProviderErrorKind.invalidVoice => 'voiceUnavailable',
        ProviderErrorKind.invalidResponse => switch (error.code) {
          LlmFailure.requestRejected => 'requestRejected',
          LlmFailure.schemaUnsupported => 'schemaUnsupported',
          _ => 'invalidResponse',
        },
        ProviderErrorKind.invalidConfiguration => 'missingKey',
      };
    } catch (_) {
      return 'network';
    }
  }

  /// Captures credentials and settings under the same write queue.
  Future<ProviderConfiguration> configuration() {
    final result = _writes.then((_) => _configuration(secret: true));
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> refreshReadiness() {
    final operation = _writes.then((_) => _publish());
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> get saved => _writes;
}

/// Serializes consent prompts and persists grants for the actual destination.
class ConsentBroker extends ValueNotifier<ConsentRequest?> implements Consents {
  ConsentBroker(this.store) : super(null);
  final LocalStore store;
  int _sequence = 0;
  Future<void> _queue = Future.value();
  Completer<bool>? _pending;
  bool _closed = false;

  /// Whether the reader already agreed to sending book text to [endpoint].
  Future<bool> granted(String provider, String endpoint) =>
      store.exists('providerConsent', '$provider:$endpoint');

  @override
  Future<List<ConsentRecord>> records() async => [
    for (final json in await store.list('providerConsent'))
      ConsentRecord(
        provider: json['provider'] as String,
        endpoint: json['endpoint'] as String,
      ),
  ];

  @override
  Future<void> revoke(ConsentRecord record) =>
      store.delete('providerConsent', '${record.provider}:${record.endpoint}');

  @override
  Future<bool> request({
    String? bookTitle,
    required String provider,
    required String endpoint,
    required String content,
  }) {
    final key = '$provider:$endpoint';
    final result = _queue.then((_) async {
      if (_closed) return false;
      if (await store.get('providerConsent', key) != null) return true;
      if (_closed) return false;
      final answer = Completer<bool>();
      _pending = answer;
      value = ConsentRequest(
        id: ++_sequence,
        bookTitle: bookTitle,
        provider: provider,
        endpoint: endpoint,
        content: content,
      );
      final accepted = await answer.future;
      _pending = null;
      value = null;
      if (accepted) {
        await store.put('providerConsent', key, {
          'provider': provider,
          'endpoint': endpoint,
        });
      }
      return accepted;
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  void respond(int requestId, {required bool accepted}) {
    if (value?.id != requestId || _pending == null || _pending!.isCompleted) {
      return;
    }
    _pending!.complete(accepted);
  }

  Future<void> close() async {
    _closed = true;
    if (_pending != null && !_pending!.isCompleted) _pending!.complete(false);
    await _queue;
    dispose();
  }
}
