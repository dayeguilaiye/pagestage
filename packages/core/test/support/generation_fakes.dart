import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';

class GenerationLlm implements LlmAdapter {
  final chapters = <int>[];
  FutureOr<void> Function(int chapter)? before;
  @override
  String get model => 'offline';
  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final input = jsonDecode(request.user) as Map;
    final chapter = request.schemaName == 'profile'
        ? ((input['chapters'] as List).first as Map)['number'] as int
        : input['chapter'] as int;
    chapters.add(chapter);
    await before?.call(chapter);
    return LlmResponse(
      data: request.schemaName == 'profile'
          ? {
              'characters': [],
              'personas': [],
              'merges': [],
              'provisionalResolutions': [],
              'lexicon': [],
            }
          : {
              'lines': [
                for (final text
                    in (input['source'] as String)
                        .split('\n')
                        .where((s) => s.isNotEmpty))
                  {
                    'text': text,
                    'speakerId': 'narrator',
                    'emotion': 'calm',
                    'intensity': 'mild',
                    'note': '',
                    'isDialogueTag': false,
                    'isNonStory': false,
                  },
              ],
            },
    );
  }
}

class GenerationTts implements TtsAdapter {
  final requests = <TtsRequest>[];
  FutureOr<void> Function(int request)? before;
  @override
  String get provider => 'minimax';
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) =>
      const TtsCapabilities(maxCharacters: 10000, supportsPronunciation: true);
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async {
    requests.add(request);
    await before?.call(requests.length);
    return TtsAudio(
      audio: PcmAudio(
        samples: Int16List.fromList(List.filled(240, 1000)),
        sampleRate: 24000,
      ),
      characters: request.text.length,
    );
  }
}
