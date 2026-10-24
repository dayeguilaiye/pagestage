import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

import '../tool/build_preset_catalog.dart';
import '../tool/sync_minimax_voices.dart';

void main() {
  test('catalog documents every preset and exposes honest metadata gaps', () {
    expect(defaultVoiceCatalog, hasLength(184));
    expect(defaultVoiceCatalog.map((p) => p.id).toSet(), hasLength(184));
    for (final preset in defaultVoiceCatalog) {
      expect(preset.sourceUrl, startsWith('https://'));
      expect(preset.description, isNotEmpty);
      for (final field in [
        'languages',
        'gender',
        'ageGroup',
        'styles',
        'narratorCandidate',
      ]) {
        expect(
          preset.tagProvenance[field],
          isNotEmpty,
          reason: '${preset.id}: $field',
        );
      }
      if (preset.gender == 'unknown') {
        expect(preset.metadataGaps, contains('gender'));
      }
      if (preset.ageGroup == 'unknown') {
        expect(preset.metadataGaps, contains('ageGroup'));
      }
      if (preset.narratorReview == 'notReviewed') {
        expect(preset.metadataGaps, contains('narratorListeningReview'));
      }
    }
    final narrator = defaultVoiceCatalog.singleWhere(
      (p) => p.id == 'bailian:anmingyuan_v3.1',
    );
    expect(narrator.useCases, contains('旁白'));
    expect(narrator.narratorCandidate, isTrue);
    final english = defaultVoiceCatalog.singleWhere(
      (p) => p.id == 'bailian:Emily_v3.1',
    );
    expect(english.gender, 'female');
    expect(english.ageGroup, 'unknown');
    expect(english.narratorCandidate, isFalse);
  });

  test(
    'official descriptions correct demographic guesses and preserve gaps',
    () {
      VoicePreset voice(String id) =>
          defaultVoiceCatalog.singleWhere((p) => p.id == 'minimax:$id');
      expect(voice('Chinese (Mandarin)_Gentle_Senior').gender, 'female');
      expect(voice('Chinese (Mandarin)_Gentle_Senior').ageGroup, 'youngAdult');
      expect(voice('Chinese (Mandarin)_HK_Flight_Attendant').gender, 'female');
      expect(
        voice('Chinese (Mandarin)_HK_Flight_Attendant').ageGroup,
        'middleAged',
      );
      expect(voice('Chinese (Mandarin)_Mature_Woman').ageGroup, 'youngAdult');
      expect(voice('male-qn-qingse').gender, 'male');
      expect(voice('male-qn-qingse').metadataGaps, contains('description'));
      expect(
        voice('English_expressive_narrator').metadataGaps,
        contains('apiMetadata'),
      );
      expect(voice('Santa_Claus ').binding.voiceId, 'Santa_Claus ');
    },
  );

  test(
    'bundled catalog includes every reviewed source and all API descriptions',
    () async {
      final expectedIds = <String>{};
      for (final provider in ['minimax', 'bailian']) {
        final source =
            jsonDecode(
                  await File(
                    '${Directory('tool/voice_sources').existsSync() ? 'tool' : 'packages/core/tool'}/voice_sources/$provider.json',
                  ).readAsString(),
                )
                as Map;
        for (final row in source['voices'] as List) {
          final id = "$provider:${row['id']}";
          expectedIds.add(id);
          final preset = defaultVoiceCatalog.singleWhere((p) => p.id == id);
          for (final text in row['apiDescription'] as List? ?? []) {
            expect(preset.description, contains(text), reason: id);
          }
        }
      }
      expect(defaultVoiceCatalog.map((p) => p.id).toSet(), expectedIds);
    },
  );

  test('official API descriptions supply information missing from voice IDs', () {
    final result = buildPreset(
      'minimax',
      {
        'model': 'speech-2.8-hd',
        'sourceUrl': 'https://platform.minimax.io/docs/faq/system-voice-id',
        'metadataSourceUrl':
            'https://platform.minimax.io/docs/api-reference/voice-management-get',
      },
      {
        'id': 'Chinese (Mandarin)_News_Anchor',
        'providerLabel': 'News Anchor',
        'languages': ['zh'],
        'apiName': 'News Anchor (Female)',
        'apiDescription': [
          'A professional middle-aged female news anchor voice in standard Mandarin, with a broadcast-style tone.',
        ],
      },
    );
    expect(result['gender'], 'female');
    expect(result['ageGroup'], 'middleAged');
    expect(result['description'], contains('middle-aged female'));
    expect((result['tagProvenance'] as Map)['gender'], contains('API'));
    // A broadcast voice is not automatically a verified audiobook narrator.
    expect(result['narratorCandidate'], isFalse);
    expect(result['narratorReview'], 'notReviewed');
  });

  test('names and traits without a life stage retain unknown age', () {
    for (final text in [
      'Calm Woman',
      'Kind-Hearted Girl',
      'Gentleman',
      '沉稳权威女',
      '清甜女声',
    ]) {
      expect(inferAge(text), 'unknown');
    }
    expect(inferGender('Female Narrator'), 'female');
    expect(inferGender('HK Flight Attendant'), 'unknown');
    expect(inferAge('天真男童音'), 'child');
    expect(inferAge('顽皮少年音'), 'teen');
    expect(inferAge('Young male'), 'youngAdult');
    expect(inferAge('Elderly woman'), 'senior');
  });

  test(
    'metadata sync sends one system-only request and saves public fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'voice-metadata-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final config = File('${directory.path}/providers.json');
      await config.writeAsString(
        jsonEncode({
          'minimax': {
            'key': 'test-secret',
            'baseUrl': 'https://example.test/v1/',
          },
        }),
      );
      final outputFile = File('${directory.path}/voices.json');
      var requests = 0;
      final output = StringBuffer();
      final code = await syncMiniMaxVoices(
        ['--config', config.path, '--output', outputFile.path],
        output: output,
        errorOutput: output,
        httpClient: MockClient((request) async {
          requests++;
          expect(request.url.toString(), 'https://example.test/v1/get_voice');
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'voice_type': 'system'});
          expect(request.followRedirects, isFalse);
          expect(request.headers['Authorization'], 'Bearer test-secret');
          return http.Response(
            jsonEncode({
              'base_resp': {'status_code': 0},
              'system_voice': [
                {
                  'voice_id': 'narrator',
                  'voice_name': 'Narrator',
                  'description': ['Calm male voice'],
                  'private_field': 'discard',
                },
              ],
              'voice_cloning': [
                {'voice_id': 'private-clone'},
              ],
            }),
            200,
          );
        }),
      );
      expect(code, 0);
      expect(requests, 1);
      final snapshot = await outputFile.readAsString();
      expect(snapshot, contains('Calm male voice'));
      expect(snapshot, isNot(contains('private')));
      expect('$snapshot$output', isNot(contains('test-secret')));
    },
  );

  test(
    'failed metadata sync neither retries nor replaces saved snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'voice-metadata-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final config = File('${directory.path}/providers.json');
      await config.writeAsString(
        jsonEncode({
          'minimax': {'key': 'test-secret'},
        }),
      );
      final file = await File(
        '${directory.path}/voices.json',
      ).writeAsString('previous snapshot');
      var requests = 0;
      final output = StringBuffer();
      final code = await syncMiniMaxVoices(
        ['--config', config.path, '--output', file.path],
        output: output,
        errorOutput: output,
        httpClient: MockClient((request) async {
          requests++;
          return http.Response('sensitive test-secret error', 429);
        }),
      );
      expect(code, 1);
      expect(requests, 1);
      expect(await file.readAsString(), 'previous snapshot');
      expect(output.toString(), contains('HTTP 429'));
      expect(output.toString(), contains('Request attempts: 1'));
      expect(output.toString(), isNot(contains('test-secret')));
    },
  );

  test('connection failures report a safe category without retrying', () async {
    final directory = await Directory.systemTemp.createTemp('voice-metadata-');
    addTearDown(() => directory.delete(recursive: true));
    final config = await File('${directory.path}/providers.json').writeAsString(
      jsonEncode({
        'minimax': {'key': 'test-secret'},
      }),
    );
    final output = StringBuffer();
    var requests = 0;
    final code = await syncMiniMaxVoices(
      ['--config', config.path, '--output', '${directory.path}/voices.json'],
      errorOutput: output,
      httpClient: MockClient((request) async {
        requests++;
        throw http.ClientException('sensitive test-secret transport error');
      }),
    );
    expect(code, 1);
    expect(requests, 1);
    expect(output.toString(), contains('connection failed'));
    expect(output.toString(), isNot(contains('test-secret')));
    expect(await File('${directory.path}/voices.json').exists(), isFalse);
  });
}
