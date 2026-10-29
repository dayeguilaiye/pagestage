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

class ProviderStore extends ValueNotifier<ProviderPreferences>
    implements Providers {
  ProviderStore._(this.store, this.secrets, super.value);
  final LocalStore store;
  final SecretStore secrets;
  Future<void> _writes = Future.value();

  static Future<ProviderStore> open(
    LocalStore store,
    SecretStore secrets,
  ) async {
    final p = await store.get('settings', 'providers') ?? {};
    return ProviderStore._(
      store,
      secrets,
      ProviderPreferences(
        baseUrl: p['baseUrl'] as String? ?? 'https://api.openai.com/v1',
        protocol: LlmProtocol.values.byName(
          p['protocol'] as String? ?? 'chatCompletions',
        ),
        profileModel: p['profileModel'] as String? ?? '',
        directorModel: p['directorModel'] as String? ?? '',
        region: ProviderRegion.values.byName(
          p['region'] as String? ?? 'beijing',
        ),
        hasLlmKey: (await secrets.read('llm'))?.isNotEmpty ?? false,
        hasMinimaxKey: (await secrets.read('minimax'))?.isNotEmpty ?? false,
        hasBailianKey: (await secrets.read('bailian'))?.isNotEmpty ?? false,
        minimaxOn: p['minimaxOn'] as bool? ?? true,
        bailianOn: p['bailianOn'] as bool? ?? true,
        edgeOn: p['edgeOn'] as bool? ?? false,
      ),
    );
  }

  @override
  Future<void> save(
    ProviderPreferences preferences, {
    String? llmKey,
    String? minimaxKey,
    String? bailianKey,
  }) {
    final url = Uri.tryParse(preferences.baseUrl.trim());
    if (url == null ||
        !['http', 'https'].contains(url.scheme) ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        url.hasQuery ||
        url.hasFragment) {
      throw const ProviderException(
        provider: 'llm',
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    // A key typed in now means the reader wants that provider used.
    bool on(bool current, String? key) =>
        key != null && key.trim().isNotEmpty || current;
    final minimaxOn = on(preferences.minimaxOn, minimaxKey);
    final bailianOn = on(preferences.bailianOn, bailianKey);
    final operation = _writes.then((_) async {
      for (final entry in {
        'llm': llmKey,
        'minimax': minimaxKey,
        'bailian': bailianKey,
      }.entries) {
        if (entry.value != null) {
          final text = entry.value!.trim();
          await secrets.write(entry.key, text.isEmpty ? null : text);
        }
      }
      final json = <String, Object?>{
        'baseUrl': url.toString(),
        'protocol': preferences.protocol.name,
        'profileModel': preferences.profileModel.trim(),
        'directorModel': preferences.directorModel.trim(),
        'region': preferences.region.name,
        'minimaxOn': minimaxOn,
        'bailianOn': bailianOn,
        'edgeOn': preferences.edgeOn,
      };
      await store.put('settings', 'providers', json);
      value = ProviderPreferences(
        baseUrl: url.toString(),
        protocol: preferences.protocol,
        profileModel: preferences.profileModel.trim(),
        directorModel: preferences.directorModel.trim(),
        region: preferences.region,
        hasLlmKey: (await secrets.read('llm'))?.isNotEmpty ?? false,
        hasMinimaxKey: (await secrets.read('minimax'))?.isNotEmpty ?? false,
        hasBailianKey: (await secrets.read('bailian'))?.isNotEmpty ?? false,
        minimaxOn: minimaxOn,
        bailianOn: bailianOn,
        edgeOn: preferences.edgeOn,
      );
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  /// Captures credentials and non-secret preferences under the same write queue.
  Future<ProviderConfiguration> configuration() {
    final result = _writes.then((_) async {
      final p = value;
      final keys = <String, String>{};
      for (final name in ['llm', 'minimax', 'bailian']) {
        keys[name] = await secrets.read(name) ?? '';
      }
      return ProviderConfiguration.fromValues({
        'llm': {
          'baseUrl': p.baseUrl,
          'api': p.protocol == LlmProtocol.responses
              ? 'responses'
              : 'chat-completions',
          'profileModel': p.profileModel,
          'directorModel': p.directorModel.isEmpty
              ? p.profileModel
              : p.directorModel,
          'key': keys['llm']!,
        },
        'minimax': {'key': keys['minimax']!},
        'bailian': {'key': keys['bailian']!, 'region': p.region.name},
      });
    });
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
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

  Future<bool> request({
    required String bookTitle,
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
