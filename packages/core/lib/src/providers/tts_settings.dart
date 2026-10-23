import '../provider_configuration.dart';
import 'bailian_tts_adapter.dart';
import 'minimax_tts_adapter.dart';
import 'provider_exception.dart';
import 'tts_adapter.dart';

/// Opens only the TTS providers needed by an operation; closes owned clients.
class TtsProviderSession {
  TtsProviderSession._(this.adapters, this._closers);
  final Map<String, TtsAdapter> adapters;
  final List<void Function()> _closers;

  factory TtsProviderSession.open(
    ProviderConfiguration config, {
    required Iterable<String> providers,
    Map<String, TtsAdapter> overrides = const {},
  }) {
    final adapters = <String, TtsAdapter>{};
    final closers = <void Function()>[];
    try {
      for (final provider in providers.toSet()) {
        final injected = overrides[provider];
        if (injected != null) {
          adapters[provider] = injected;
          continue;
        }
        final prefix = provider.toUpperCase();
        final key = config.value(
          provider,
          'key',
          environmentVariable: '${prefix}_API_KEY',
        );
        final region =
            config.value(
              'bailian',
              'region',
              environmentVariable: 'BAILIAN_REGION',
            ) ??
            'beijing';
        final endpoint = config.value(
          provider,
          'baseUrl',
          environmentVariable: '${prefix}_BASE_URL',
        );
        final baseUrl = endpoint == null ? null : Uri.tryParse(endpoint);
        if (key == null ||
            key.isEmpty ||
            (endpoint != null && baseUrl == null) ||
            !['minimax', 'bailian'].contains(provider) ||
            (provider == 'bailian' &&
                !['beijing', 'singapore'].contains(region))) {
          throw ProviderException(
            provider: provider,
            kind: ProviderErrorKind.invalidConfiguration,
          );
        }
        if (provider == 'minimax') {
          final adapter = MiniMaxTtsAdapter(apiKey: key, baseUrl: baseUrl);
          adapters[provider] = adapter;
          closers.add(adapter.close);
        } else {
          final adapter = BailianTtsAdapter(
            apiKey: key,
            baseUrl: baseUrl,
            region: BailianRegion.values.byName(region),
          );
          adapters[provider] = adapter;
          closers.add(adapter.close);
        }
      }
      return TtsProviderSession._(Map.unmodifiable(adapters), closers);
    } catch (_) {
      for (final close in closers) {
        close();
      }
      rethrow;
    }
  }

  void close() {
    for (final close in _closers) {
      close();
    }
    _closers.clear();
  }
}
