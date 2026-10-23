import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'MiniMax enforces its declared Unicode character limit at the adapter entry',
    () async {
      var calls = 0;
      final wav = PcmAudio(samples: Int16List.fromList([1])).toWav();
      final adapter = MiniMaxTtsAdapter(
        apiKey: 'fixture-secret',
        client: MockClient((_) async {
          calls++;
          return http.Response(
            jsonEncode({
              'base_resp': {'status_code': 0},
              'data': {
                'status': 2,
                'audio': wav
                    .map((b) => b.toRadixString(16).padLeft(2, '0'))
                    .join(),
              },
              'extra_info': {'usage_characters': 9999},
            }),
            200,
          );
        }),
      );
      final limit = adapter.capabilitiesFor(_request.binding).maxCharacters;
      final text = '𠀀' * limit;
      TtsRequest request(String text) => TtsRequest(
        text: text,
        language: 'zh',
        binding: _request.binding,
        direction: _request.direction,
      );
      await adapter.synthesize(request(text));
      expect(calls, 1);
      await expectLater(
        adapter.synthesize(request('$text。')),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.kind,
            'kind',
            ProviderErrorKind.invalidConfiguration,
          ),
        ),
      );
      expect(calls, 1);
    },
  );
  for (final seconds in [1, 60, 120]) {
    for (final design in [false, true]) {
      test(
        'MiniMax decodes $seconds-second ${design ? 'voice preview' : 'speech'} hex audio',
        () async {
          final samples = Int16List(24000 * seconds);
          for (var i = 0; i < samples.length; i++) {
            samples[i] = i.isEven ? 0x1234 : -0x5678;
          }
          final wav = PcmAudio(samples: samples).toWav();
          final hex = StringBuffer();
          for (var i = 0; i < wav.length; i++) {
            final pair = wav[i].toRadixString(16).padLeft(2, '0');
            hex.write(i.isEven ? pair : pair.toUpperCase());
          }
          final adapter = MiniMaxTtsAdapter(
            apiKey: 'fixture-secret',
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'base_resp': {'status_code': 0},
                  if (design) ...{
                    'voice_id': 'designed-test',
                    'trial_audio': hex.toString(),
                  } else ...{
                    'data': {'status': 2, 'audio': hex.toString()},
                    'extra_info': {'usage_characters': 4},
                  },
                }),
                200,
              ),
            ),
          );
          addTearDown(adapter.close);
          final PcmAudio audio;
          if (design) {
            final result = await adapter.design(
              const VoiceDesignRequest(
                description: 'Warm narrator',
                previewText: 'The garden was quiet.',
                language: 'en',
                model: 'speech-2.8-hd',
              ),
            );
            audio = PcmAudio.fromWav(result.preview.bytes);
          } else {
            final result = await adapter.synthesize(_request);
            expect(result.characters, 4);
            audio = result.audio;
          }
          expect(audio.duration, Duration(seconds: seconds));
          expect(audio.samples, samples);
        },
      );
    }
  }
  test('MiniMax rejects malformed hex in speech and voice previews', () async {
    final valid = PcmAudio(
      samples: Int16List.fromList([1234]),
    ).toWav().map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    for (final hex in [
      '',
      '0',
      '0g',
      '-1',
      '+1',
      '０0',
      '00\n0',
      '$valid-1',
      '${'00' * (24000 * 60 * 2)}0g',
    ]) {
      final adapter = MiniMaxTtsAdapter(
        apiKey: 'fixture-secret',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'base_resp': {'status_code': 0},
              'data': {'status': 2, 'audio': hex},
              'extra_info': {'usage_characters': 4},
              'voice_id': 'designed-test',
              'trial_audio': hex,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(adapter.close);
      final invalid = isA<ProviderException>().having(
        (e) => e.kind,
        'kind',
        ProviderErrorKind.invalidResponse,
      );
      await expectLater(adapter.synthesize(_request), throwsA(invalid));
      await expectLater(
        adapter.design(
          const VoiceDesignRequest(
            description: 'Warm narrator',
            previewText: 'The garden was quiet.',
            language: 'en',
            model: 'speech-2.8-hd',
          ),
        ),
        throwsA(invalid),
      );
    }
  });
  test(
    'MiniMax sends a WAV request and decodes documented hex audio',
    () async {
      final root = Directory.current.path.endsWith('/core')
          ? 'test'
          : 'packages/core/test';
      final fixture = await File(
        '$root/fixtures/minimax/success.json',
      ).readAsString();
      final adapter = MiniMaxTtsAdapter(
        apiKey: 'fixture-secret',
        baseUrl: Uri.parse('https://example.test/proxy/v1/'),
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.test/proxy/v1/t2a_v2',
          );
          expect(request.headers['authorization'], 'Bearer fixture-secret');
          expect(jsonDecode(request.body), {
            'model': 'speech-2.8-hd',
            'text': '风来了。',
            'stream': false,
            'output_format': 'hex',
            'language_boost': 'Chinese',
            'voice_setting': {
              'voice_id': 'Chinese (Mandarin)_Male_Announcer',
              'speed': 1,
              'vol': 1,
              'pitch': 0,
              'emotion': 'sad',
            },
            'audio_setting': {
              'sample_rate': 24000,
              'format': 'wav',
              'channel': 1,
            },
          });
          return http.Response(
            fixture,
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(adapter.close);
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
      expect(result.characters, 6);
    },
  );
  for (final entry in {
    1004: ProviderErrorKind.invalidKey,
    2049: ProviderErrorKind.invalidKey,
    1008: ProviderErrorKind.insufficientBalance,
    2053: ProviderErrorKind.insufficientBalance,
    1002: ProviderErrorKind.rateLimited,
    1039: ProviderErrorKind.rateLimited,
    1045: ProviderErrorKind.rateLimited,
  }.entries) {
    test(
      'MiniMax classifies provider code ${entry.key} without exposing secrets',
      () async {
        final adapter = MiniMaxTtsAdapter(
          apiKey: 'fixture-secret',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'base_resp': {
                  'status_code': entry.key,
                  'status_msg': 'fixture-secret',
                },
              }),
              200,
            ),
          ),
        );
        await expectLater(
          adapter.synthesize(_request),
          throwsA(
            isA<ProviderException>()
                .having((e) => e.kind, 'kind', entry.value)
                .having(
                  (e) => e.toString(),
                  'safe message',
                  isNot(contains('fixture-secret')),
                ),
          ),
        );
      },
    );
  }

  test(
    'transport and malformed provider responses expose only safe categories',
    () async {
      for (final failure in [
        (http.Response('fixture-secret', 401), ProviderErrorKind.invalidKey),
        (http.Response('fixture-secret', 429), ProviderErrorKind.rateLimited),
        (http.Response('fixture-secret', 503), ProviderErrorKind.unavailable),
        (
          http.Response('{"secret":"fixture-secret"}', 200),
          ProviderErrorKind.invalidResponse,
        ),
      ]) {
        final adapter = MiniMaxTtsAdapter(
          apiKey: 'fixture-secret',
          client: MockClient((_) async => failure.$1),
        );
        await expectLater(
          adapter.synthesize(_request),
          throwsA(
            isA<ProviderException>()
                .having((e) => e.kind, 'kind', failure.$2)
                .having(
                  (e) => e.toString(),
                  'safe message',
                  isNot(contains('fixture-secret')),
                ),
          ),
        );
      }
      final adapter = MiniMaxTtsAdapter(
        apiKey: 'fixture-secret',
        client: MockClient(
          (_) async => throw http.ClientException('fixture-secret'),
        ),
      );
      await expectLater(
        adapter.synthesize(_request),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.kind, 'kind', ProviderErrorKind.unavailable)
              .having(
                (e) => e.toString(),
                'safe message',
                isNot(contains('fixture-secret')),
              ),
        ),
      );
    },
  );
}

const _request = TtsRequest(
  text: '风来了。',
  language: 'zh',
  binding: VoiceBinding(
    provider: 'minimax',
    model: 'speech-2.8-hd',
    voiceId: 'Chinese (Mandarin)_Male_Announcer',
  ),
  direction: Direction(speakerId: 'narrator'),
);
