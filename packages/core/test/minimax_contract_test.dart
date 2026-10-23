import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
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
        TtsRequest.forCapabilities(
          text: _request.text,
          language: _request.language,
          binding: _request.binding,
          direction: const Direction(
            speakerId: 'narrator',
            emotion: Emotion.sad,
            intensity: Intensity.strong,
            note: 'Speak softly.',
          ),
          capabilities: adapter.capabilitiesFor(_request.binding),
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
