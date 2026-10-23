import 'dart:convert';
import 'dart:io';

/// Billing fields of one accepted provider response, copied verbatim so costs
/// can be reconciled in each provider's own units (tokens, characters, ...).
class UsageRecord {
  const UsageRecord({
    required this.provider,
    required this.endpoint,
    required this.model,
    required this.usage,
    this.requestId,
  });
  final String provider;

  /// Request URL without credentials; identifies the vendor and operation.
  final String endpoint;
  final String? model;
  final Map<String, Object?> usage;
  final String? requestId;
}

/// Receives one record for every provider response that may be billed.
abstract interface class UsageLedger {
  void record(UsageRecord record);
}

/// Appends records as JSON lines, flushed before returning so a later crash
/// cannot lose spending that already happened.
class JsonlUsageLedger implements UsageLedger {
  JsonlUsageLedger(
    this.file, {
    Map<String, Object?> labels = const {},
    DateTime Function()? clock,
  }) : _labels = Map.unmodifiable(labels),
       _clock = clock ?? DateTime.now;
  final File file;
  final Map<String, Object?> _labels;
  final DateTime Function() _clock;

  @override
  void record(UsageRecord record) {
    file.parent.createSync(recursive: true);
    final line = jsonEncode({
      'time': _clock().toUtc().toIso8601String(),
      ..._labels,
      'provider': record.provider,
      'endpoint': record.endpoint,
      'model': record.model,
      if (record.requestId != null) 'requestId': record.requestId,
      'usage': record.usage,
    });
    file.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  }
}

/// The decoded usage object of a response, or empty when the provider omits it.
Map<String, Object?> usageFields(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : {};
