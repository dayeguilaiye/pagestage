import '../engines/standard_engines.dart';
import '../engines/tts_engine.dart';
import '../provider_configuration.dart';
import 'provider_exception.dart';
import 'tts_adapter.dart';
import 'usage_ledger.dart';
import 'request_recovery.dart';

/// Opens only the voice engines needed by an operation, each behind its
/// account's request queue; closes the clients it owns.
class TtsProviderSession {
  TtsProviderSession._(this.adapters, this._closers);
  final Map<String, TtsAdapter> adapters;
  final List<void Function()> _closers;

  factory TtsProviderSession.open(
    ProviderConfiguration config, {
    required Iterable<String> providers,
    TtsEngines? engines,
    Map<String, TtsAdapter> overrides = const {},
    UsageLedger? usageLedger,
    RequestRuntime? runtime,
    Map<String, ProviderRequestQueue>? queues,
  }) {
    final registry = engines ?? standardTtsEngines;
    final sharedQueues = queues ?? <String, ProviderRequestQueue>{};
    final adapters = <String, TtsAdapter>{};
    final closers = <void Function()>[];
    try {
      for (final provider in providers.toSet()) {
        final engine = registry[provider];
        final limit = int.tryParse(
          config.value(
                provider,
                'requestsPerMinute',
                environmentVariable:
                    '${provider.toUpperCase()}_REQUESTS_PER_MINUTE',
              ) ??
              '${engine?.requestsPerMinute ?? 60}',
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
        if (engine == null) {
          throw ProviderException(
            provider: provider,
            kind: ProviderErrorKind.invalidConfiguration,
          );
        }
        final opened = engine.open(config, usageLedger: usageLedger);
        adapters[provider] = ScheduledTtsAdapter(opened.adapter, queue);
        closers.add(opened.close);
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
