import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  for (final provider in ['minimax', 'bailian']) {
    test(
      '$provider sanitizes synthesis and design transport exceptions',
      () async {
        for (final failure in [
          TimeoutException('fixture-secret'),
          http.ClientException('fixture-secret'),
        ]) {
          final client = MockClient((_) async => throw failure);
          final TtsAdapter adapter = provider == 'minimax'
              ? MiniMaxTtsAdapter(apiKey: 'fixture-secret', client: client)
              : BailianTtsAdapter(apiKey: 'fixture-secret', client: client);
          final model = provider == 'minimax'
              ? 'speech-2.8-hd'
              : 'qwen-audio-3.1-tts-flash';
          final safeFailure = throwsA(
            isA<ProviderException>()
                .having((e) => e.kind, 'kind', ProviderErrorKind.unavailable)
                .having(
                  (e) => e.toString(),
                  'safe message',
                  isNot(contains('fixture-secret')),
                ),
          );
          await expectLater(
            adapter.synthesize(
              TtsRequest(
                text: 'Hello.',
                language: 'en',
                binding: VoiceBinding(
                  provider: provider,
                  model: model,
                  voiceId: 'voice',
                ),
                direction: const Direction(speakerId: 'narrator'),
              ),
            ),
            safeFailure,
          );
          await expectLater(
            (adapter as VoiceDesignAdapter).design(
              VoiceDesignRequest(
                description: 'Warm narrator',
                previewText: 'The garden was quiet this evening.',
                language: 'en',
                model: model,
              ),
            ),
            safeFailure,
          );
        }
      },
    );
  }
}
