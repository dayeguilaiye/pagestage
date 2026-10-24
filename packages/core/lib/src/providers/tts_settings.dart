import '../provider_configuration.dart';
import 'bailian_tts_adapter.dart';
import 'minimax_tts_adapter.dart';
import 'provider_exception.dart';
import 'tts_adapter.dart';
import 'usage_ledger.dart';
import 'request_recovery.dart';

/// Opens only the TTS providers needed by an operation; closes owned clients.
class TtsProviderSession {
  TtsProviderSession._(this.adapters, this._closers);
  final Map<String, TtsAdapter> adapters;
  final List<void Function()> _closers;

  factory TtsProviderSession.open(
    ProviderConfiguration config, {
    required Iterable<String> providers,
    Map<String, TtsAdapter> overrides = const {},
    UsageLedger? usageLedger,
    RequestRuntime? runtime,
    Map<String, ProviderRequestQueue>? queues,
  }) {
    final sharedQueues = queues ?? <String, ProviderRequestQueue>{};
    final adapters = <String, TtsAdapter>{};
    final closers = <void Function()>[];
    try {
      for (final provider in providers.toSet()) {
        final prefix = provider.toUpperCase();
        final limit = int.tryParse(
          config.value(
                provider,
                'requestsPerMinute',
                environmentVariable: '${prefix}_REQUESTS_PER_MINUTE',
              ) ??
              (provider == 'minimax' ? '12' : '60'),
        );
        if (limit == null || limit < 1 || limit > 60000) {
          throw ProviderException(
            provider: provider,
            kind: ProviderErrorKind.invalidConfiguration,
          );
        }
        final queue = sharedQueues.putIfAbsent(
          provider,
          () => ProviderRequestQueue(
            provider: provider,
            requestsPerMinute: limit,
            runtime: runtime,
          ),
        );
        final injected = overrides[provider];
        if (injected != null) {
          adapters[provider] = ScheduledTtsAdapter(injected, queue);
          continue;
        }
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
          final adapter = MiniMaxTtsAdapter(
            apiKey: key,
            baseUrl: baseUrl,
            usageLedger: usageLedger,
          );
          adapters[provider] = ScheduledTtsAdapter(adapter, queue);
          closers.add(adapter.close);
        } else {
          final adapter = BailianTtsAdapter(
            apiKey: key,
            baseUrl: baseUrl,
            region: BailianRegion.values.byName(region),
            usageLedger: usageLedger,
          );
          adapters[provider] = ScheduledTtsAdapter(adapter, queue);
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
