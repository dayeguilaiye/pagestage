import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pagestage_core/pagestage_core.dart';

import 'contracts.dart';

abstract interface class DiagnosticPlatform {
  Future<Map<String, Object?>> snapshot();
  Future<void> share(String path);
  Future<void> feedback();
}

class NativeDiagnostics implements DiagnosticPlatform {
  static const channel = MethodChannel('pagestage/diagnostics');
  @override
  Future<Map<String, Object?>> snapshot() async => Map<String, Object?>.from(
    await channel.invokeMapMethod<String, Object?>('snapshot') ?? {},
  );
  @override
  Future<void> share(String path) =>
      channel.invokeMethod<void>('share', {'path': path});
  @override
  Future<void> feedback() => channel.invokeMethod<void>('feedback');
}

/// Persist only fixed categories and source locations. Exception messages,
/// provider responses, paths, book data and arbitrary native strings never enter
/// the journal, so privacy does not depend on knowing every key or book text.
class DiagnosticLog implements Diagnostics {
  DiagnosticLog(
    this.directory, {
    DiagnosticPlatform? platform,
    this.maxBytes = 128 * 1024,
  }) : platform = platform ?? NativeDiagnostics();
  final Directory directory;
  final DiagnosticPlatform platform;
  final int maxBytes;
  Future<void> _writes = Future.value();
  File get _current => File('${directory.path}/events.jsonl');
  File get _previous => File('${directory.path}/events.previous.jsonl');
  Future<void> get flushed => _writes;

  void install() {
    FlutterError.onError = (details) => unawaited(
      record(
        details.exception,
        details.stack ?? StackTrace.empty,
        source: 'flutter',
      ),
    );
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(record(error, stack, source: 'platform'));
      return true;
    };
  }

  Future<void> record(
    Object error,
    StackTrace stack, {
    String source = 'application',
  }) {
    final kind = error is ProviderException
        ? 'provider_${error.kind.name}'
        : error is FormatException
        ? 'format'
        : error is FileSystemException
        ? 'filesystem'
        : error is TimeoutException
        ? 'timeout'
        : error is StateError
        ? 'state'
        : error is ArgumentError
        ? 'argument'
        : error is PlatformException
        ? 'platform'
        : error is FlutterError
        ? 'flutter'
        : 'exception';
    final raw = stack.toString();
    final frames =
        RegExp(
              r'(?:package:pagestage_(?:app|core)/[a-zA-Z0-9_/]+\.dart|dart:[a-zA-Z0-9_/]+\.dart):[0-9]+:[0-9]+',
            )
            .allMatches(raw.substring(0, raw.length.clamp(0, 65536)))
            .take(24)
            .map((m) => m.group(0)!)
            .toList();
    return _append({
      'at': DateTime.now().toUtc().toIso8601String(),
      'source': {'flutter', 'platform', 'zone', 'application'}.contains(source)
          ? source
          : 'application',
      'kind': kind,
      'frames': frames,
    });
  }

  Future<void> _append(Map<String, Object?> event) {
    final next = _writes.then((_) async {
      await directory.create(recursive: true);
      final bytes = utf8.encode('${jsonEncode(event)}\n');
      if (bytes.length > maxBytes) return;
      if (await _current.exists() &&
          await _current.length() + bytes.length > maxBytes) {
        if (await _previous.exists()) await _previous.delete();
        await _current.rename(_previous.path);
      }
      await _current.writeAsBytes(bytes, mode: FileMode.append, flush: true);
    });
    // Reporting an I/O error must not recurse into the global error handler.
    _writes = next.catchError((Object _) {});
    return _writes;
  }

  Future<Map<String, Object?>> _snapshot() async {
    final raw = await platform.snapshot();
    String version(String field) {
      final value = raw[field];
      return value is String &&
              RegExp(r'^[0-9]+(?:[. _+-][0-9]+)*$').hasMatch(value) &&
              value.length <= 64
          ? value
          : 'unknown';
    }

    final system = {'android', 'ios'}.contains(raw['platform'])
        ? raw['platform']
        : 'unknown';
    final crashes = <Map<String, Object?>>[];
    for (final item
        in (raw['crashes'] is List ? raw['crashes'] as List : const []).take(
          32,
        )) {
      if (item is! Map) continue;
      final crash = <String, Object?>{};
      for (final key in [
        'timestamp',
        'reason',
        'status',
        'signal',
        'exceptionType',
        'exceptionCode',
        'pssKb',
        'rssKb',
      ]) {
        final value = item[key];
        if (value is int) crash[key] = value;
      }
      if (crash.isNotEmpty) crashes.add(crash);
    }
    return {
      'platform': system,
      'appVersion': version('appVersion'),
      'build': version('build'),
      'osVersion': version('osVersion'),
      'crashes': crashes,
    };
  }

  Future<void> collectNative() async {
    try {
      final snapshot = await _snapshot();
      final seenFile = File('${directory.path}/native-seen.json');
      final seen = <String>{};
      if (await seenFile.exists()) {
        try {
          seen.addAll(
            (jsonDecode(await seenFile.readAsString()) as List)
                .whereType<String>(),
          );
        } catch (_) {}
      }
      for (final crash in snapshot['crashes'] as List) {
        final signature = jsonEncode(crash);
        if (seen.add(signature)) {
          await _append({
            'at': DateTime.now().toUtc().toIso8601String(),
            'source': 'native',
            'kind': 'crash',
            'record': crash,
          });
        }
      }
      await directory.create(recursive: true);
      await seenFile.writeAsString(
        jsonEncode(seen.toList().reversed.take(64).toList()),
        flush: true,
      );
    } catch (error, stack) {
      await record(error, stack);
    }
  }

  Future<File> report() async {
    await collectNative();
    await flushed;
    final snapshot = await _snapshot();
    final events = <Object?>[];
    for (final file in [_previous, _current]) {
      if (!await file.exists() || await file.length() > maxBytes) continue;
      for (final line in await file.readAsLines()) {
        try {
          final event = jsonDecode(line);
          // Only journals written by this schema are exported.
          if (event is! Map) continue;
          final source = event['source'];
          final kind = event['kind'];
          final allowedKinds = {
            'format',
            'filesystem',
            'timeout',
            'state',
            'argument',
            'platform',
            'flutter',
            'exception',
            'crash',
            for (final kind in ProviderErrorKind.values)
              'provider_${kind.name}',
          };
          if (!{
                'flutter',
                'platform',
                'zone',
                'application',
                'native',
              }.contains(source) ||
              !allowedKinds.contains(kind)) {
            continue;
          }
          final stamp = DateTime.tryParse(
            event['at'] is String ? event['at'] as String : '',
          );
          final clean = <String, Object?>{
            'at': stamp?.toUtc().toIso8601String(),
            'source': source,
            'kind': kind,
          };
          if (event['frames'] is List) {
            clean['frames'] = (event['frames'] as List)
                .whereType<String>()
                .where(
                  (s) => RegExp(
                    r'^(?:package:pagestage_(?:app|core)/[a-zA-Z0-9_/]+\.dart|dart:[a-zA-Z0-9_/]+\.dart):[0-9]+:[0-9]+$',
                  ).hasMatch(s),
                )
                .take(24)
                .toList();
          }
          if (event['record'] case final Map record) {
            clean['record'] = {
              for (final key in [
                'timestamp',
                'reason',
                'status',
                'signal',
                'exceptionType',
                'exceptionCode',
                'pssKb',
                'rssKb',
              ])
                if (record[key] is int) key: record[key],
            };
          }
          events.add(clean);
        } catch (_) {}
      }
    }
    final file = File('${directory.path}/pagestage-diagnostics.json');
    await directory.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'schema': 1,
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        ...snapshot,
        'events': events,
      }),
      flush: true,
    );
    return file;
  }

  @override
  Future<void> export() async => platform.share((await report()).path);
  @override
  Future<void> feedback() => platform.feedback();
}
