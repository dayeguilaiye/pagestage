import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

// Synthetic fixtures derived from official documentation; not production traffic.
void main() {
  test(
    'MiniMax sends design request and retains an MP3 preview without activating it',
    () async {
      final requests = <http.Request>[];
      final adapter = MiniMaxTtsAdapter(
        apiKey: 'fake-secret',
        baseUrl: Uri.parse('https://example.test/custom/v1'),
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'voice_id': 'ttv-designed-1',
              'trial_audio': '49443304000000000000fffb9000',
              'base_resp': {'status_code': 0},
            }),
            200,
          );
        }),
      );
      final result = await adapter.design(
        const VoiceDesignRequest(
          description: 'Warm narrator',
          previewText: 'The garden was quiet this evening.',
          language: 'en',
          model: 'speech-2.8-hd',
        ),
      );
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/custom/v1/voice_design');
      expect(requests.single.headers['Authorization'], 'Bearer fake-secret');
      expect(jsonDecode(requests.single.body), {
        'prompt': 'Warm narrator',
        'preview_text': 'The garden was quiet this evening.',
      });
      expect(result.binding.voiceId, 'ttv-designed-1');
      expect(result.binding.model, 'speech-2.8-hd');
      expect(result.binding.designed, isTrue);
      expect(result.preview.extension, 'mp3');
    },
  );
  test(
    'Beijing Bailian keeps exact target model and returns a WAV designed binding',
    () async {
      final wav = PcmAudio(samples: Int16List.fromList([1, 2, 3])).toWav();
      late Map<String, dynamic> body;
      final adapter = BailianTtsAdapter(
        apiKey: 'fake-key',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/services/audio/tts/customization');
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'output': {
                'voice_id': 'designed-bailian',
                'target_model': 'qwen-audio-3.1-tts-plus',
                'preview_audio': {
                  'data': base64Encode(wav),
                  'response_format': 'wav',
                  'sample_rate': 24000,
                },
              },
              'usage': {'count': 1},
            }),
            200,
          );
        }),
      );
      final result = await adapter.design(
        const VoiceDesignRequest(
          description: 'Warm and clear',
          previewText: 'The garden was quiet this evening.',
          language: 'en',
          model: 'qwen-audio-3.1-tts-plus',
        ),
      );
      expect(body, {
        'model': 'voice-enrollment',
        'input': {
          'action': 'create_voice',
          'target_model': 'qwen-audio-3.1-tts-plus',
          'voice_prompt': 'Warm and clear',
          'preview_text': 'The garden was quiet this evening.',
          'prefix': 'pagestage',
          'language_hints': ['en'],
        },
        'parameters': {'sample_rate': 24000, 'response_format': 'wav'},
      });
      expect(result.binding.model, 'qwen-audio-3.1-tts-plus');
      expect(result.binding.designed, isTrue);
      expect(result.binding.parameters['region'], 'beijing');
      expect(result.preview.bytes, wav);
      expect(
        adapter.capabilitiesFor(result.binding).supportsPronunciation,
        isFalse,
      );
    },
  );
  test(
    'Bailian rejects non-Beijing design and synthesis of Beijing designed voices',
    () async {
      var calls = 0;
      final adapter = BailianTtsAdapter(
        apiKey: 'fake-key',
        region: BailianRegion.singapore,
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 500);
        }),
      );
      const binding = VoiceBinding(
        provider: 'bailian',
        model: 'qwen-audio-3.1-tts-flash',
        voiceId: 'designed-voice',
        designed: true,
        parameters: {'region': 'beijing'},
      );
      final invalid = isA<ProviderException>().having(
        (e) => e.kind,
        'kind',
        ProviderErrorKind.invalidConfiguration,
      );
      await expectLater(
        adapter.design(
          const VoiceDesignRequest(
            description: 'Warm and clear',
            previewText: 'The garden was quiet this evening.',
            language: 'en',
            model: 'qwen-audio-3.1-tts-flash',
          ),
        ),
        throwsA(invalid),
      );
      await expectLater(
        adapter.synthesize(
          const TtsRequest(
            text: 'Hello.',
            language: 'en',
            binding: binding,
            direction: Direction(speakerId: 'hero'),
          ),
        ),
        throwsA(invalid),
      );
      expect(calls, 0);
    },
  );

  test(
    'design errors and malformed previews remain safe typed failures',
    () async {
      final cases = <(int, Map<String, Object?>, ProviderErrorKind)>[
        (
          200,
          {
            'base_resp': {
              'status_code': 1004,
              'status_msg': 'fake-secret raw-body',
            },
          },
          ProviderErrorKind.invalidKey,
        ),
        (
          200,
          {
            'base_resp': {'status_code': 1008},
          },
          ProviderErrorKind.insufficientBalance,
        ),
        (
          200,
          {
            'base_resp': {'status_code': 1002},
          },
          ProviderErrorKind.rateLimited,
        ),
        (503, {'secret': 'fake-secret'}, ProviderErrorKind.unavailable),
        (
          200,
          {
            'base_resp': {'status_code': 0},
            'voice_id': 'v',
            'trial_audio': '0000',
          },
          ProviderErrorKind.invalidResponse,
        ),
        (
          200,
          {
            'base_resp': {'status_code': 0},
            'voice_id': 'v',
            'trial_audio': 'xyz',
          },
          ProviderErrorKind.invalidResponse,
        ),
      ];
      for (final (status, body, kind) in cases) {
        final adapter = MiniMaxTtsAdapter(
          apiKey: 'fake-secret',
          client: MockClient(
            (_) async => http.Response(jsonEncode(body), status),
          ),
        );
        await expectLater(
          adapter.design(
            const VoiceDesignRequest(
              description: 'Warm narrator',
              previewText: 'The garden was quiet this evening.',
              language: 'en',
              model: 'speech-2.8-hd',
            ),
          ),
          throwsA(
            isA<ProviderException>()
                .having((e) => e.kind, 'kind', kind)
                .having(
                  (e) => e.toString(),
                  'safe message',
                  isNot(contains('fake-secret')),
                ),
          ),
        );
      }
    },
  );

  test(
    'Bailian rejects a response bound to a different target model',
    () async {
      final adapter = BailianTtsAdapter(
        apiKey: 'fake-key',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'output': {
                'voice_id': 'voice',
                'target_model': 'qwen-audio-3.0-tts-flash',
                'preview_audio': {
                  'data': base64Encode(
                    PcmAudio(samples: Int16List.fromList([1])).toWav(),
                  ),
                  'sample_rate': 24000,
                  'response_format': 'wav',
                },
              },
            }),
            200,
          ),
        ),
      );
      await expectLater(
        adapter.design(
          const VoiceDesignRequest(
            description: 'Warm narrator',
            previewText: 'The garden was quiet this evening.',
            language: 'en',
            model: 'qwen-audio-3.1-tts-flash',
          ),
        ),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.kind,
            'kind',
            ProviderErrorKind.invalidResponse,
          ),
        ),
      );
    },
  );

  test(
    'Bailian design and synthesis use the same safe provider error categories',
    () async {
      for (final entry in [
        ('InvalidApiKey', ProviderErrorKind.invalidKey),
        ('Arrearage', ProviderErrorKind.insufficientBalance),
        ('Throttling.RateQuota', ProviderErrorKind.rateLimited),
      ]) {
        final adapter = BailianTtsAdapter(
          apiKey: 'fixture-secret',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'code': entry.$1,
                'message': 'fixture-secret raw-body',
              }),
              400,
            ),
          ),
        );
        final failure = throwsA(
          isA<ProviderException>()
              .having((error) => error.kind, 'kind', entry.$2)
              .having(
                (error) => error.toString(),
                'safe message',
                isNot(contains('fixture-secret')),
              ),
        );
        await expectLater(
          adapter.design(
            const VoiceDesignRequest(
              description: 'Warm narrator',
              previewText: 'The garden was quiet this evening.',
              language: 'en',
              model: 'qwen-audio-3.1-tts-flash',
            ),
          ),
          failure,
        );
        await expectLater(
          adapter.synthesize(
            const TtsRequest(
              text: 'Hello.',
              language: 'en',
              binding: VoiceBinding(
                provider: 'bailian',
                model: 'qwen-audio-3.1-tts-flash',
                voiceId: 'Emily_v3.1',
              ),
              direction: Direction(speakerId: 'narrator'),
            ),
          ),
          failure,
        );
      }
    },
  );
}
