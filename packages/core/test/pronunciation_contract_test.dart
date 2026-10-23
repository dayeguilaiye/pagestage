import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'MiniMax maps the polyphonic fixture to its numbered tone dictionary',
    () async {
      final fixture =
          jsonDecode(
                await File(
                  '$_root/fixtures/pronunciation/polyphonic-zh.json',
                ).readAsString(),
              )
              as Map;
      final adapter = MiniMaxTtsAdapter(
        apiKey: 'offline',
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map;
          expect(body['text'], fixture['text']);
          expect(body['pronunciation_dict'], {
            'tone': [
              '单明/(shan4)(ming2)',
              '曾乐/(zeng1)(le4)',
              '重庆/(chong2)(qing4)',
              '长乐/(chang2)(le4)',
            ],
          });
          return http.Response(
            await File('$_root/fixtures/minimax/success.json').readAsString(),
            200,
          );
        }),
      );
      await adapter.synthesize(
        TtsRequest(
          text: fixture['text'] as String,
          language: 'zh',
          binding: const VoiceBinding(
            provider: 'minimax',
            model: 'speech-2.8-hd',
            voiceId: 'Chinese (Mandarin)_Male_Announcer',
          ),
          direction: const Direction(speakerId: 'narrator'),
          pronunciations: (fixture['lexicon'] as List)
              .map(
                (e) => PronunciationEntry.fromJson(
                  Map<String, Object?>.from(e as Map),
                ),
              )
              .toList(),
        ),
      );
    },
  );
  test(
    'Bailian escapes source text and wraps matched Chinese terms in SSML',
    () async {
      final adapter = BailianTtsAdapter(
        apiKey: 'offline',
        requestCharacterLimit: 20,
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response.bytes(
              PcmAudio(samples: Int16List(240)).toWav(),
              200,
            );
          }
          final input = (jsonDecode(request.body) as Map)['input'] as Map;
          expect(input['enable_ssml'], isTrue);
          expect(
            input['text'],
            '<speak>&lt;<phoneme alphabet="py" ph="chang2 le4">长乐</phoneme> &amp; &quot;<phoneme alphabet="py" ph="chong2 qing4">重庆</phoneme>&quot;&gt;</speak>',
          );
          return http.Response(
            jsonEncode({
              'output': {
                'finish_reason': 'stop',
                'audio': {'url': 'https://audio.example.test/fixture.wav'},
              },
            }),
            200,
          );
        }),
      );
      await adapter.synthesize(
        const TtsRequest(
          text: '<长乐 & "重庆">',
          language: 'zh',
          binding: VoiceBinding(
            provider: 'bailian',
            model: 'qwen-audio-3.1-tts-flash',
            voiceId: 'longsanshu_v3.1',
          ),
          direction: Direction(speakerId: 'narrator'),
          pronunciations: [
            PronunciationEntry('长乐', 'cháng lè'),
            PronunciationEntry('重庆', 'chong2 qing4'),
          ],
        ),
      );
    },
  );

  for (final provider in ['minimax', 'bailian']) {
    for (final language in ['en', 'zh']) {
      test(
        '$provider keeps $language source plain without an applicable term',
        () async {
          final client = MockClient((request) async {
            if (request.method == 'GET') {
              return http.Response.bytes(
                PcmAudio(samples: Int16List(240)).toWav(),
                200,
              );
            }
            final body = jsonDecode(request.body) as Map;
            if (provider == 'minimax') {
              expect(body['text'], 'Hello & 长乐');
              expect(body.containsKey('pronunciation_dict'), isFalse);
              return http.Response(
                await File(
                  '$_root/fixtures/minimax/success.json',
                ).readAsString(),
                200,
              );
            }
            expect((body['input'] as Map)['text'], 'Hello & 长乐');
            expect((body['input'] as Map).containsKey('enable_ssml'), isFalse);
            return http.Response(
              jsonEncode({
                'output': {
                  'finish_reason': 'stop',
                  'audio': {'url': 'https://audio.example.test/fixture.wav'},
                },
              }),
              200,
            );
          });
          final TtsAdapter adapter = provider == 'minimax'
              ? MiniMaxTtsAdapter(apiKey: 'offline', client: client)
              : BailianTtsAdapter(apiKey: 'offline', client: client);
          await adapter.synthesize(
            TtsRequest(
              text: 'Hello & 长乐',
              language: language,
              binding: VoiceBinding(
                provider: provider,
                model: provider == 'minimax'
                    ? 'speech-2.8-hd'
                    : 'qwen-audio-3.1-tts-flash',
                voiceId: provider == 'minimax'
                    ? 'Chinese (Mandarin)_Male_Announcer'
                    : 'longsanshu_v3.1',
              ),
              direction: const Direction(speakerId: 'narrator'),
              pronunciations: [
                PronunciationEntry(
                  language == 'en' ? '长乐' : '重庆',
                  'chang2 le4',
                ),
              ],
            ),
          );
        },
      );
    }
  }
}

String get _root =>
    Directory.current.path.endsWith('/core') ? 'test' : 'packages/core/test';
