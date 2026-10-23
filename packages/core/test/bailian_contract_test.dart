import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'Bailian sends Qwen Audio request and downloads WAV without credentials',
    () async {
      final adapter = BailianTtsAdapter(
        apiKey: 'fixture-secret',
        client: MockClient((request) async {
          if (request.method == 'GET') {
            expect(
              request.url.toString(),
              'https://audio.example.test/result.wav?signature=fixture',
            );
            expect(request.headers.containsKey('authorization'), isFalse);
            final root = Directory.current.path.endsWith('/core')
                ? 'test'
                : 'packages/core/test';
            final source =
                jsonDecode(
                      await File(
                        '$root/fixtures/minimax/success.json',
                      ).readAsString(),
                    )
                    as Map;
            final hex = (source['data'] as Map)['audio'] as String;
            final wav = Uint8List.fromList([
              for (var i = 0; i < hex.length; i += 2)
                int.parse(hex.substring(i, i + 2), radix: 16),
            ]);
            return http.Response.bytes(wav, 200);
          }
          expect(
            request.url.toString(),
            'https://dashscope.aliyuncs.com/api/v1/services/audio/tts/SpeechSynthesizer',
          );
          expect(request.headers['authorization'], 'Bearer fixture-secret');
          expect(jsonDecode(request.body), {
            'model': 'qwen-audio-3.1-tts-flash',
            'input': {
              'text': 'The garden is quiet.',
              'instruction':
                  'Read with a sad emotion and strong intensity. Speak softly.',
              'voice': 'Emily_v3.1',
              'format': 'wav',
              'sample_rate': 24000,
              'language_hints': ['en'],
            },
          });
          return http.Response(
            jsonEncode({
              'output': {
                'finish_reason': 'stop',
                'audio': {
                  'url':
                      'https://audio.example.test/result.wav?signature=fixture',
                  'data': '',
                },
              },
              'usage': {
                'characters': 20,
                'input_tokens': 6,
                'output_tokens': 13,
                'total_tokens': 19,
              },
              'request_id': 'synthetic-doc-fixture',
            }),
            200,
          );
        }),
      );
      final result = await adapter.synthesize(
        TtsRequest(
          text: _request.text,
          language: _request.language,
          binding: _request.binding,
          direction: const Direction(
            speakerId: 'narrator',
            emotion: Emotion.sad,
            intensity: Intensity.strong,
            note: 'Speak softly.',
          ),
        ),
      );
      expect(result.audio.duration, const Duration(milliseconds: 10));
      expect(result.audio.samples.take(4), [1200, -1200, 1200, -1200]);
      expect(result.characters, 20);
      expect(result.inputTokens, 6);
      expect(result.outputTokens, 13);
      expect(result.totalTokens, 19);
    },
  );
  test(
    'Bailian maps Chinese performance from a direct synthesis request',
    () async {
      final adapter = BailianTtsAdapter(
        apiKey: 'fixture-secret',
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response.bytes(
              PcmAudio(samples: Int16List.fromList([1])).toWav(),
              200,
            );
          }
          final body = jsonDecode(request.body) as Map;
          expect((body['input'] as Map)['instruction'], '以开心的语气、强度强朗读。轻快一些。');
          return http.Response(
            jsonEncode({
              'output': {
                'finish_reason': 'stop',
                'audio': {'url': 'https://audio.example.test/result.wav'},
              },
            }),
            200,
          );
        }),
      );
      await adapter.synthesize(
        TtsRequest(
          text: '故事开始了。',
          language: 'zh',
          binding: _request.binding,
          direction: const Direction(
            speakerId: 'narrator',
            emotion: Emotion.happy,
            intensity: Intensity.strong,
            note: '  轻快一些。  ',
          ),
        ),
      );
    },
  );
  test(
    'Bailian classifies key, balance, throttling and configuration errors safely',
    () async {
      for (final entry in [
        (401, 'InvalidApiKey', ProviderErrorKind.invalidKey),
        (400, 'Arrearage', ProviderErrorKind.insufficientBalance),
        (429, 'Throttling.RateQuota', ProviderErrorKind.rateLimited),
        (400, 'Throttling.AllocationQuota', ProviderErrorKind.rateLimited),
        (403, 'AccessDenied', ProviderErrorKind.invalidConfiguration),
        (503, 'InternalError', ProviderErrorKind.unavailable),
      ]) {
        final adapter = BailianTtsAdapter(
          apiKey: 'fixture-secret',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({'code': entry.$2, 'message': 'fixture-secret'}),
              entry.$1,
            ),
          ),
        );
        await expectLater(
          adapter.synthesize(_request),
          throwsA(
            isA<ProviderException>()
                .having((e) => e.kind, 'kind', entry.$3)
                .having(
                  (e) => e.toString(),
                  'safe message',
                  isNot(contains('fixture-secret')),
                ),
          ),
        );
      }
    },
  );

  test(
    'synthesis capabilities reflect model, voice origin and request limit',
    () {
      final beijing = BailianTtsAdapter(
        apiKey: 'fixture-secret',
        client: MockClient(
          (_) async => throw StateError('No request expected.'),
        ),
      );
      final singapore = BailianTtsAdapter(
        apiKey: 'fixture-secret',
        region: BailianRegion.singapore,
        client: MockClient(
          (_) async => throw StateError('No request expected.'),
        ),
      );
      final preset = beijing.capabilitiesFor(_request.binding);
      expect(preset.maxCharacters, 600);
      expect(preset.supportsPronunciation, isTrue);
      expect(
        singapore.capabilitiesFor(_request.binding).supportsPronunciation,
        isTrue,
      );
      expect(
        beijing
            .capabilitiesFor(
              const VoiceBinding(
                provider: 'bailian',
                model: 'qwen-audio-3.1-tts-flash',
                voiceId: 'custom',
                designed: true,
              ),
            )
            .supportsPronunciation,
        isFalse,
      );
      expect(
        () => beijing.capabilitiesFor(
          const VoiceBinding(
            provider: 'bailian',
            model: 'qwen3-tts-flash',
            voiceId: 'Cherry',
          ),
        ),
        throwsA(isA<ProviderException>()),
      );
      final minimax = MiniMaxTtsAdapter(
        apiKey: 'fixture-secret',
        client: MockClient(
          (_) async => throw StateError('No request expected.'),
        ),
      );
      final capabilities = minimax.capabilitiesFor(
        const VoiceBinding(
          provider: 'minimax',
          model: 'speech-2.8-hd',
          voiceId: 'English_expressive_narrator',
        ),
      );
      expect(capabilities.maxCharacters, 9999);
      expect(capabilities.supportsPronunciation, isTrue);
    },
  );
}

const _request = TtsRequest(
  text: 'The garden is quiet.',
  language: 'en',
  binding: VoiceBinding(
    provider: 'bailian',
    model: 'qwen-audio-3.1-tts-flash',
    voiceId: 'Emily_v3.1',
  ),
  direction: Direction(speakerId: 'narrator'),
);
