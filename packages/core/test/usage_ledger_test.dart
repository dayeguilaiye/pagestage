import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

// Synthetic provider responses shaped after each vendor's documented fields.
void main() {
  late Directory temp;
  late File file;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pagestage-usage');
    file = File('${temp.path}/nested/usage.jsonl');
  });
  tearDown(() => temp.delete(recursive: true));

  List<Map<String, Object?>> lines() => file
      .readAsLinesSync()
      .map((line) => Map<String, Object?>.from(jsonDecode(line) as Map))
      .toList();

  test('JSONL ledger appends labelled records one line each', () {
    final ledger = JsonlUsageLedger(
      file,
      labels: {
        'run': 'run-1',
        'arguments': ['synthesize', 'book', '1'],
      },
      clock: () => DateTime.utc(2026, 10, 23, 8),
    );
    for (final characters in [3, 5]) {
      ledger.record(
        UsageRecord(
          provider: 'minimax',
          endpoint: 'https://api.minimax.io/v1/t2a_v2',
          model: 'speech-2.8-hd',
          requestId: 'trace-$characters',
          usage: {'usage_characters': characters},
        ),
      );
    }
    expect(lines(), [
      for (final characters in [3, 5])
        {
          'time': '2026-10-23T08:00:00.000Z',
          'run': 'run-1',
          'arguments': ['synthesize', 'book', '1'],
          'provider': 'minimax',
          'endpoint': 'https://api.minimax.io/v1/t2a_v2',
          'model': 'speech-2.8-hd',
          'requestId': 'trace-$characters',
          'usage': {'usage_characters': characters},
        },
    ]);
  });

  test('MiniMax records extra_info billing fields and trace ID', () async {
    final wav = PcmAudio(samples: Int16List.fromList([1, 2])).toWav();
    final adapter = MiniMaxTtsAdapter(
      apiKey: 'fixture-secret',
      usageLedger: JsonlUsageLedger(file),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'base_resp': {'status_code': 0},
            'trace_id': 'trace-1',
            'data': {
              'status': 2,
              'audio': wav
                  .map((b) => b.toRadixString(16).padLeft(2, '0'))
                  .join(),
            },
            'extra_info': {
              'usage_characters': 4,
              'word_count': 4,
              'audio_length': 900,
            },
          }),
          200,
        ),
      ),
    );
    await adapter.synthesize(_minimaxRequest);
    final record = lines().single;
    expect(record['provider'], 'minimax');
    expect(record['endpoint'], 'https://api.minimax.io/v1/t2a_v2');
    expect(record['model'], 'speech-2.8-hd');
    expect(record['requestId'], 'trace-1');
    expect(record['usage'], {
      'usage_characters': 4,
      'word_count': 4,
      'audio_length': 900,
    });
    expect(file.readAsStringSync(), isNot(contains('fixture-secret')));
  });

  test('MiniMax provider errors are not recorded as usage', () async {
    final adapter = MiniMaxTtsAdapter(
      apiKey: 'fixture-secret',
      usageLedger: JsonlUsageLedger(file),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'base_resp': {'status_code': 1008},
          }),
          200,
        ),
      ),
    );
    await expectLater(
      adapter.synthesize(_minimaxRequest),
      throwsA(isA<ProviderException>()),
    );
    expect(file.existsSync(), isFalse);
  });

  test('Bailian records the usage object and request ID', () async {
    final wav = PcmAudio(samples: Int16List.fromList([1, 2])).toWav();
    final adapter = BailianTtsAdapter(
      apiKey: 'fixture-secret',
      usageLedger: JsonlUsageLedger(file),
      client: MockClient((request) async {
        if (request.method == 'GET') return http.Response.bytes(wav, 200);
        return http.Response(
          jsonEncode({
            'request_id': 'req-1',
            'output': {
              'finish_reason': 'stop',
              'audio': {'url': 'https://audio.example.test/a.wav'},
            },
            'usage': {'characters': 20},
          }),
          200,
        );
      }),
    );
    await adapter.synthesize(_bailianRequest);
    final record = lines().single;
    expect(record['provider'], 'bailian');
    expect(
      record['endpoint'],
      'https://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer',
    );
    expect(record['model'], 'qwen-audio-3.1-tts-flash');
    expect(record['requestId'], 'req-1');
    expect(record['usage'], {'characters': 20});
  });

  test(
    'LLM records raw usage even when the billed content is rejected',
    () async {
      final adapter = OpenAiLlmAdapter(
        stream: false,
        baseUrl: Uri.parse('https://api.example.test/v1'),
        apiKey: 'fixture-secret',
        model: 'director-model',
        usageLedger: JsonlUsageLedger(file),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'id': 'chatcmpl-1',
              'choices': [
                {
                  'finish_reason': 'stop',
                  'message': {'content': 'not json'},
                },
              ],
              'usage': {
                'prompt_tokens': 120,
                'completion_tokens': 30,
                'total_tokens': 150,
                'prompt_cache_hit_tokens': 100,
                'prompt_cache_miss_tokens': 20,
              },
            }),
            200,
          ),
        ),
      );
      await expectLater(
        adapter.complete(
          const LlmRequest(
            system: 'Return JSON.',
            user: 'Direct.',
            schemaName: 'script',
            schema: {'type': 'object'},
          ),
        ),
        throwsA(isA<ProviderException>()),
      );
      final record = lines().single;
      expect(record['provider'], 'llm');
      expect(
        record['endpoint'],
        'https://api.example.test/v1/chat/completions',
      );
      expect(record['model'], 'director-model');
      expect(record['requestId'], 'chatcmpl-1');
      expect(record['usage'], {
        'prompt_tokens': 120,
        'completion_tokens': 30,
        'total_tokens': 150,
        'prompt_cache_hit_tokens': 100,
        'prompt_cache_miss_tokens': 20,
      });
    },
  );
}

const _minimaxRequest = TtsRequest(
  text: '风来了。',
  language: 'zh',
  binding: VoiceBinding(
    provider: 'minimax',
    model: 'speech-2.8-hd',
    voiceId: 'Chinese (Mandarin)_Male_Announcer',
  ),
  direction: Direction(speakerId: 'narrator'),
);

const _bailianRequest = TtsRequest(
  text: 'The garden is quiet.',
  language: 'en',
  binding: VoiceBinding(
    provider: 'bailian',
    model: 'qwen-audio-3.1-tts-flash',
    voiceId: 'Emily_v3.1',
  ),
  direction: Direction(speakerId: 'narrator'),
);
