import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:pagestage_core/src/cli.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late EdgeTtsAdapter adapter;
  late Uint8List mp3;
  late Uri endpoint;
  final sockets = <WebSocket>[];
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    endpoint = Uri.parse('ws://127.0.0.1:${server.port}/edge/v1');
    adapter = EdgeTtsAdapter(endpoint: endpoint);
    final root = Directory('test/fixtures/edge').existsSync()
        ? 'test'
        : 'packages/core/test';
    mp3 = await File('$root/fixtures/edge/tone.mp3').readAsBytes();
  });
  tearDown(() async {
    adapter.close();
    for (final socket in sockets) {
      unawaited(socket.close());
    }
    sockets.clear();
    await server.close(force: true);
  });

  void serve(
    void Function(WebSocket socket, String ssml) respond, {
    void Function(HttpRequest request)? inspect,
  }) {
    server.listen((request) async {
      inspect?.call(request);
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      var messages = 0;
      socket.listen((message) {
        if (++messages == 2) respond(socket, message as String);
      });
    });
  }

  test(
    'authenticates Edge protocol, escapes plain text and decodes MP3',
    () async {
      final ledger = _Ledger();
      final now = DateTime.utc(2026, 10, 29, 1, 2, 3);
      adapter.close();
      adapter = EdgeTtsAdapter(
        endpoint: endpoint,
        clock: () => now,
        usageLedger: ledger,
      );
      final messages = <String>[];
      server.listen((request) async {
        expect(request.uri.path, '/edge/v1');
        final query = request.uri.queryParameters;
        expect(query['ConnectionId'], matches(r'^[A-F0-9]{32}$'));
        final seconds = now.millisecondsSinceEpoch ~/ 1000 + 11644473600;
        final ticks = seconds ~/ 300 * 300 * 10000000;
        expect(
          query['Sec-MS-GEC'],
          sha256
              .convert(utf8.encode('${ticks}6A5AA1D4EAFF4E9FB37E23D68491D6F4'))
              .toString()
              .toUpperCase(),
        );
        expect(query['Sec-MS-GEC-Version'], '1-143.0.3650.75');
        expect(request.headers.value('user-agent'), contains('Edg/143.0.0.0'));
        expect(
          request.headers.value('origin'),
          startsWith('chrome-extension://'),
        );
        expect(
          request.headers.value('cookie'),
          matches(r'^muid=[A-F0-9]{32};$'),
        );
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((message) {
          messages.add(message as String);
          if (messages.length == 2) {
            socket.add('Path:turn.start\r\n\r\n{}');
            socket.add(_frame(mp3.sublist(0, 17)));
            socket.add(_frame(mp3.sublist(17)));
            socket.add(_frame([]));
            socket.add('Path:turn.end\r\n\r\n{}');
          }
        });
      });
      final result = await adapter.synthesize(
        _request(
          text: '重庆<&"\'\u0001<phoneme>你好</phoneme>',
          parameters: {'rate': '+10%', 'volume': '-5%', 'pitch': '+2Hz'},
        ),
      );
      final config = jsonDecode(messages.first.split('\r\n\r\n')[1]) as Map;
      expect(
        config['context']['synthesis']['audio']['outputFormat'],
        'audio-24khz-48kbitrate-mono-mp3',
      );
      expect(messages.last, contains('Thu Oct 29 2026 01:02:03 GMT+0000'));
      expect(
        messages.last,
        contains(
          'Microsoft Server Speech Text to Speech Voice (zh-CN, XiaoxiaoNeural)',
        ),
      );
      expect(messages.last, contains('pitch="+2Hz" rate="+10%" volume="-5%"'));
      expect(
        messages.last,
        contains('重庆&lt;&amp;&quot;&apos; &lt;phoneme&gt;你好&lt;/phoneme&gt;'),
      );
      expect(messages.last, isNot(contains('angry')));
      expect(messages.last, isNot(contains('chong2')));
      expect(result.audio.sampleRate, 24000);
      expect(result.audio.duration.inMilliseconds, inInclusiveRange(950, 1150));
      expect(result.audio.samples.any((sample) => sample.abs() > 100), isTrue);
      expect(result.characters, isNull);
      expect(result.totalTokens, isNull);
      expect(ledger.records.single.usage, isEmpty);
      expect(ledger.records.single.endpoint, endpoint.toString());
    },
  );

  test(
    'rejects unsupported bindings and invalid parameters before connecting',
    () async {
      var connections = 0;
      server.listen((request) {
        connections++;
        request.response.close();
      });
      for (final request in [
        _request(text: ''),
        _request(text: '好' * 601),
        _request(parameters: {'rate': 'fast'}),
        _request(parameters: {'pitch': '+2%'}),
        _request(parameters: {'volume': 1}),
        _request(voice: 'voice"/>'),
      _request(voice: 'en-USNeural'),
        _request(model: 'azure'),
        _request(designed: true),
      ]) {
        await expectLater(
          adapter.synthesize(request),
          _fails(ProviderErrorKind.invalidConfiguration),
        );
      }
      expect(connections, 0);
      expect(
        adapter.capabilitiesFor(_request().binding).supportsPronunciation,
        isFalse,
      );
    },
  );

  for (final scenario in [
    'empty',
    'truncatedHeader',
    'badPath',
    'badMp3',
    'unexpectedText',
  ]) {
    test('rejects $scenario instead of accepting malformed audio', () async {
      serve((socket, _) {
        switch (scenario) {
          case 'truncatedHeader':
            socket.add([0, 100, 1]);
          case 'badPath':
            socket.add(_frame(mp3, path: 'something-else'));
          case 'badMp3':
            socket.add(_frame([1, 2, 3, 4]));
          case 'unexpectedText':
            socket.add('Path:turn.error\r\n\r\nprivate-text');
        }
        socket.add('Path:turn.end\r\n\r\n{}');
      });
      await expectLater(
        adapter.synthesize(_request()),
        _fails(ProviderErrorKind.invalidResponse),
      );
    });
  }

  test(
    'disconnection after audio is a failure until turn.end arrives',
    () async {
      serve((socket, _) {
        socket.add(_frame(mp3));
        unawaited(socket.close());
      });
      await expectLater(
        adapter.synthesize(_request()),
        _fails(ProviderErrorKind.unavailable),
      );
    },
  );

  for (final status in [403, 429, 503]) {
    test('sanitizes rejected WebSocket upgrade $status', () async {
      server.listen((request) {
        request.response.statusCode = status;
        request.response.write('private-text');
        request.response.close();
      });
      await expectLater(
        adapter.synthesize(_request()),
        _fails(
          status == 429
              ? ProviderErrorKind.rateLimited
              : ProviderErrorKind.unavailable,
        ),
      );
    });
  }

  test(
    'times out an unfinished audio stream and releases the connection',
    () async {
      adapter.close();
      adapter = EdgeTtsAdapter(
        endpoint: endpoint,
        timeout: const Duration(milliseconds: 200),
      );
      final closed = Completer<void>();
      serve((socket, _) {
        socket.add(_frame(mp3));
        socket.done.then((_) => closed.complete());
      });
      await expectLater(
        adapter.synthesize(_request()),
        _fails(ProviderErrorKind.unavailable),
      );
      await closed.future.timeout(const Duration(seconds: 2));
    },
  );

  test(
    'session needs no key; long text splits, warns on lexicon and reuses cache',
    () async {
      var calls = 0;
      final texts = <String>[];
      serve((socket, ssml) {
        calls++;
        texts.add(
          RegExp(
            r'<prosody[^>]*>(.*?)</prosody>',
            dotAll: true,
          ).firstMatch(ssml)!.group(1)!,
        );
        socket.add(_frame(mp3));
        socket.add('Path:turn.end\r\n\r\n{}');
      });
      final config = ProviderConfiguration.fromValues({
        'edge': {'baseUrl': endpoint.toString(), 'requestsPerMinute': '60000'},
      });
      final session = TtsProviderSession.open(config, providers: ['edge']);
      addTearDown(session.close);
      final temp = await Directory.systemTemp.createTemp('edge-synthesis-');
      addTearDown(() => temp.delete(recursive: true));
      final text = '重庆。${'你好。' * 220}';
      final chapter = Chapter(number: 1, title: '章', text: text);
      Future<SynthesisResult> run() =>
          Synthesizer(adapters: session.adapters).synthesize(
            chapter: chapter,
            script: Script.narration(bookId: 'book', chapter: chapter),
            language: 'zh',
            voices: {'narrator': _request().binding},
            lexicon: const [PronunciationEntry('重庆', 'chong2 qing4')],
            outputPath: '${temp.path}/chapter.wav',
          );
      final first = await run();
      expect(calls, 2);
      expect(texts.join(), text);
      expect(texts.every((t) => t.runes.length <= 600), isTrue);
      expect(first.requests, 2);
      expect(first.utterances.single.pronunciationApplied, isFalse);
      expect(first.utterances.single.pronunciationWarning, isNotNull);
      expect(
        PcmAudio.fromWav(await File(first.path).readAsBytes()).samples,
        isNotEmpty,
      );
      expect((await run()).requests, 0);
      expect(calls, 2);
    },
  );

  test(
    'CLI narrates with Edge and applies explicit prosody over config',
    () async {
      final temp = await Directory.systemTemp.createTemp('edge-cli-');
      addTearDown(() => temp.delete(recursive: true));
      final source = await File(
        '${temp.path}/book.txt',
      ).writeAsString('第一章\n你好。');
      final imported = StringBuffer();
      expect(
        await runCli(
          ['--data-dir', temp.path, 'import', source.path],
          output: imported,
          environment: {},
        ),
        0,
      );
      final bookId =
          (jsonDecode(imported.toString()) as Map)['bookId'] as String;
      final messages = <String>[];
      serve((socket, ssml) {
        messages.add(ssml);
        socket.add(_frame(mp3));
        socket.add('Path:turn.end\r\n\r\n{}');
      });
      final config = await File('${temp.path}/providers.json').writeAsString(
        jsonEncode({
          'edge': {
            'baseUrl': endpoint.toString(),
            'rate': '+5%',
            'volume': '-10%',
            'pitch': '+3Hz',
          },
        }),
      );
      final output = StringBuffer();
      expect(
        await runCli(
          [
            '--data-dir',
            temp.path,
            'narrate',
            bookId,
            '1',
            '--provider',
            'edge',
            '--config',
            config.path,
            '--rate=+20%',
          ],
          output: output,
          environment: {'EDGE_RATE': '+15%', 'EDGE_PITCH': '-2Hz'},
        ),
        0,
      );
      final result = jsonDecode(output.toString()) as Map;
      expect(result['provider'], 'edge');
      expect(result['model'], EdgeTtsAdapter.model);
      expect(await File(result['path'] as String).exists(), isTrue);
      expect(messages.single, contains('rate="+20%"'));
      expect(messages.single, contains('pitch="-2Hz"'));
      expect(messages.single, contains('volume="-10%"'));
      expect(messages.single, contains('XiaoxiaoNeural'));
      final catalog = StringBuffer();
      expect(
        await runCli(
          [
            '--data-dir',
            temp.path,
            'cast',
            'catalog',
            '--provider',
            'edge',
            '--language',
            'zh',
          ],
          output: catalog,
          environment: {},
        ),
        0,
      );
      expect(jsonDecode(catalog.toString()) as List, hasLength(6));
    },
  );
}

TtsRequest _request({
  String text = '重庆，你好。',
  Map<String, Object?> parameters = const {},
  String voice = 'zh-CN-XiaoxiaoNeural',
  String model = EdgeTtsAdapter.model,
  bool designed = false,
}) => TtsRequest(
  text: text,
  language: 'zh',
  binding: VoiceBinding(
    provider: 'edge',
    model: model,
    voiceId: voice,
    parameters: parameters,
    designed: designed,
  ),
  direction: const Direction(speakerId: 'narrator', emotion: Emotion.angry),
  pronunciations: const [PronunciationEntry('重庆', 'chong2 qing4')],
);

List<int> _frame(List<int> audio, {String path = 'audio'}) {
  final header = utf8.encode('Content-Type:audio/mpeg\r\nPath:$path\r\n');
  return [header.length >> 8, header.length & 255, ...header, ...audio];
}

Matcher _fails(ProviderErrorKind kind) => throwsA(
  isA<ProviderException>()
      .having((error) => error.kind, 'kind', kind)
      .having(
        (error) => error.toString(),
        'safe message',
        isNot(contains('private-text')),
      ),
);

class _Ledger implements UsageLedger {
  final records = <UsageRecord>[];
  @override
  void record(UsageRecord record) => records.add(record);
}
