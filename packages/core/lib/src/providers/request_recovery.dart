import 'dart:async';
import 'dart:developer' as developer;

import '../models/voice.dart';
import 'provider_exception.dart';
import 'tts_adapter.dart';
import 'voice_design_adapter.dart';

/// Injectable monotonic time and safe progress messages for request recovery.
class RequestRuntime {
  RequestRuntime({
    Duration Function()? elapsed,
    Future<void> Function(Duration)? sleep,
    void Function(String)? onEvent,
  }) : elapsed = elapsed ?? _stopwatchClock(),
       sleep = sleep ?? Future<void>.delayed,
       onEvent = onEvent ?? _log;

  final Duration Function() elapsed;
  final Future<void> Function(Duration) sleep;
  final void Function(String) onEvent;

  static Duration Function() _stopwatchClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

  static void _log(String message) =>
      developer.log(message, name: 'pagestage.requests');

  Future<void> wait(String provider, String reason, Duration delay) async {
    onEvent('$provider: $reason; waiting ${delay.inMilliseconds} ms.');
    await sleep(delay);
  }
}

/// A provider/account queue shared by synthesis, audition and voice design.
/// Every attempt occupies a slot. A persistent limit ends after three attempts.
class ProviderRequestQueue {
  ProviderRequestQueue({
    required this.provider,
    required int requestsPerMinute,
    RequestRuntime? runtime,
  }) : runtime = runtime ?? RequestRuntime() {
    if (requestsPerMinute < 1) {
      throw ArgumentError.value(requestsPerMinute, 'requestsPerMinute');
    }
    _spacing = Duration(
      microseconds: (Duration.microsecondsPerMinute / requestsPerMinute).ceil(),
    );
  }

  final String provider;
  final RequestRuntime runtime;
  late final Duration _spacing;
  Duration _nextStart = Duration.zero;
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => _run(operation));
    // A failed operation releases the queue for subsequent callers.
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    for (var attempt = 1; ; attempt++) {
      final delay = _nextStart - runtime.elapsed();
      if (delay > Duration.zero) {
        await runtime.wait(provider, 'request pacing', delay);
      }
      _nextStart = runtime.elapsed() + _spacing;
      try {
        return await operation();
      } on ProviderException catch (error) {
        if (error.kind != ProviderErrorKind.rateLimited) rethrow;
        final cooldown = runtime.elapsed() + const Duration(seconds: 60);
        if (cooldown > _nextStart) _nextStart = cooldown;
        if (attempt == 3) {
          runtime.onEvent(
            '$provider: rate limit retry budget exhausted (3 attempts).',
          );
          rethrow;
        }
        runtime.onEvent(
          '$provider: rate limited; retry ${attempt + 1}/3 queued.',
        );
      }
    }
  }
}

/// Applies the shared queue at the paid operation boundary, before HTTP work.
class ScheduledTtsAdapter implements TtsAdapter, VoiceDesignAdapter {
  ScheduledTtsAdapter(this.delegate, this.queue);
  final TtsAdapter delegate;
  final ProviderRequestQueue queue;

  @override
  String get provider => delegate.provider;

  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) =>
      delegate.capabilitiesFor(binding);

  @override
  Future<TtsAudio> synthesize(TtsRequest request) =>
      queue.run(() => delegate.synthesize(request));

  @override
  Future<DesignedVoice> design(VoiceDesignRequest request) {
    final adapter = delegate;
    if (adapter is! VoiceDesignAdapter) {
      throw ProviderException(
        provider: provider,
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    return queue.run(() => (adapter as VoiceDesignAdapter).design(request));
  }
}
