import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/diagnostics.dart';

class FixturePlatform implements DiagnosticPlatform {
  String? shared;
  int feedbackCount = 0;
  Map<String, Object?> data = {
    'platform': 'android',
    'appVersion': '0.1.0',
    'build': '4',
    'osVersion': '36',
    'secret': 'sk-private-value',
    'crashes': [
      {
        'timestamp': 10,
        'reason': 5,
        'status': 11,
        'description': '正文不可泄露 sk-private-value',
        'trace': 'private book text',
        'signal': 11,
      },
    ],
  };
  @override
  Future<Map<String, Object?>> snapshot() async => data;
  @override
  Future<void> share(String path) async {
    shared = path;
  }

  @override
  Future<void> feedback() async {
    feedbackCount++;
  }
}

void main() {
  late Directory dir;
  late FixturePlatform platform;
  late DiagnosticLog log;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('diagnostic-test-');
    platform = FixturePlatform();
    log = DiagnosticLog(dir, platform: platform, maxBytes: 1400);
  });
  tearDown(() async {
    await log.flushed;
    await dir.delete(recursive: true);
  });
  test(
    'exports useful categories and source locations without exception/native contents',
    () async {
      const secret = 'sk-private-value';
      const body = '正文不可泄露';
      await log.record(
        StateError('$secret $body'),
        StackTrace.fromString(
          '#0 Listener (package:pagestage_app/application/listening_controller.dart:42:3)\n$secret $body /Users/private/file.txt',
        ),
        source: '$secret $body',
      );
      await log.record(
        PlatformException(code: secret, message: body),
        StackTrace.empty,
      );
      await log.export();
      final text = await File(platform.shared!).readAsString();
      expect(text, isNot(contains(secret)));
      expect(text, isNot(contains(body)));
      expect(text, isNot(contains('private book text')));
      expect(text, contains('listening_controller.dart:42:3'));
      expect(text, contains('state'));
      expect(text, contains('platform'));
      final report = jsonDecode(text) as Map;
      expect(report['appVersion'], '0.1.0');
      expect((report['crashes'] as List).single, {
        'timestamp': 10,
        'reason': 5,
        'status': 11,
        'signal': 11,
      });
      await log.feedback();
      expect(platform.feedbackCount, 1);
    },
  );
  test(
    'journal rotates within bounded size and survives reopening with native deduplication',
    () async {
      for (var i = 0; i < 100; i++) {
        await log.record(FormatException('private $i'), StackTrace.empty);
      }
      await log.collectNative();
      await log.collectNative();
      final files = await dir
          .list()
          .where((f) => f.path.endsWith('.jsonl'))
          .toList();
      expect(files, hasLength(2));
      for (final f in files) {
        expect(await File(f.path).length(), lessThanOrEqualTo(1400));
      }
      final reopened = DiagnosticLog(dir, platform: platform, maxBytes: 1400);
      final report =
          jsonDecode(await (await reopened.report()).readAsString()) as Map;
      expect(
        (report['events'] as List).where((e) => e['source'] == 'native'),
        hasLength(1),
      );
    },
  );
  test(
    'metadata whitelist drops arbitrary strings and unsupported native fields',
    () async {
      platform.data = {
        'platform': 'sk-secret',
        'appVersion': 'book body',
        'build': 'token',
        'osVersion': 'private',
        'crashes': [
          {'timestamp': 'secret', 'signal': 11, 'key': 'secret'},
        ],
      };
      final report =
          jsonDecode(await (await log.report()).readAsString()) as Map;
      expect(report['platform'], 'unknown');
      expect(report['appVersion'], 'unknown');
      expect(report['crashes'], [
        {'signal': 11},
      ]);
    },
  );
  test('pauses export fixed categories and drop anything else', () async {
    await log.recordPause(
      provider: 'llm',
      task: 'profile',
      reason: 'invalidResponse',
      code: 'schema_unsupported',
    );
    await log.recordPause(
      provider: 'sk-private-value',
      task: 'profile',
      reason: 'invalidResponse',
      code: '正文不可泄露 {"secret": 1}',
    );
    final report = jsonDecode(await (await log.report()).readAsString()) as Map;
    final pauses = (report['events'] as List)
        .cast<Map>()
        .where((e) => e['kind'] == 'pause')
        .map((e) => Map.of(e)..remove('at'))
        .toList();
    expect(pauses, [
      {
        'source': 'scheduler',
        'kind': 'pause',
        'provider': 'llm',
        'task': 'profile',
        'reason': 'invalidResponse',
        'code': 'schema_unsupported',
      },
      {
        'source': 'scheduler',
        'kind': 'pause',
        'task': 'profile',
        'reason': 'invalidResponse',
      },
    ]);
  });
}
