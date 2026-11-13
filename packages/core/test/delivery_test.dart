import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

const _angry = Direction(
  speakerId: 'hero',
  emotion: Emotion.angry,
  intensity: Intensity.medium,
  note: 'Through clenched teeth.',
  pace: Pace.fast,
  volume: Volume.loud,
  cues: [
    VocalCue(VocalCueKind.sigh),
    VocalCue(VocalCueKind.chuckle, offset: 4),
  ],
);

TtsCapabilities _caps({
  Set<Emotion> emotions = const {},
  bool intensity = false,
  bool instruction = false,
  Set<VocalCueKind> cues = const {},
  bool prosody = false,
}) => TtsCapabilities(
  supportsPronunciation: false,
  maxCharacters: 100,
  emotions: emotions,
  intensity: intensity,
  instruction: instruction,
  cues: cues,
  prosody: prosody,
);

void main() {
  group('lowering a direction to what a voice can perform', () {
    test('an engine with nothing to vary receives an unmarked reading', () {
      final delivery = Delivery.lower(_angry, _caps());
      expect(delivery.toJson(), isEmpty);
    });

    test('native emotions and numeric controls carry the direction', () {
      final delivery = Delivery.lower(
        _angry,
        _caps(emotions: Emotion.values.toSet(), prosody: true),
      );
      expect(delivery.emotion, Emotion.angry);
      // No strength control, no instruction: neither is kept.
      expect(delivery.intensity, isNull);
      expect(delivery.note, isEmpty);
      // The emotion is spoken natively, so pace and volume are only the
      // director's own.
      expect(delivery.rateChange, 12);
      expect(delivery.volumeChange, 20);
      expect(delivery.pitchChange, 0);
    });

    test('an instruction engine keeps everything as words', () {
      final delivery = Delivery.lower(_angry, _caps(instruction: true));
      expect(delivery.emotion, Emotion.angry);
      expect(delivery.intensity, Intensity.medium);
      expect(
        delivery.instruction('en'),
        'Read with an angry emotion and medium intensity. Speak quickly. '
        'Speak loudly. Through clenched teeth.',
      );
      expect(
        delivery.instruction('zh'),
        '以愤怒的语气、强度中朗读。语速加快。声音放大。Through clenched teeth.',
      );
      expect(delivery.rateChange, 0);
    });

    test('an emotion the engine lacks falls back to its nearest', () {
      final delivery = Delivery.lower(
        const Direction(speakerId: 'a', emotion: Emotion.disgusted),
        _caps(emotions: {Emotion.calm, Emotion.angry, Emotion.sad}),
      );
      expect(delivery.emotion, Emotion.angry);
    });

    test('with only numeric controls the emotion shapes pace and pitch', () {
      Delivery lower(Intensity intensity, [Expressiveness? expressiveness]) =>
          Delivery.lower(
            Direction(
              speakerId: 'a',
              emotion: Emotion.sad,
              intensity: intensity,
            ),
            _caps(prosody: true),
            expressiveness: expressiveness ?? Expressiveness.natural,
          );
      final medium = lower(Intensity.medium);
      expect(medium.emotion, isNull);
      expect(
        [medium.rateChange, medium.volumeChange, medium.pitchChange],
        [-10, -10, -6],
      );
      // Stronger emotions move further, and dramatic further still.
      expect(lower(Intensity.strong).rateChange, -15);
      expect(lower(Intensity.mild).rateChange, -5);
      expect(lower(Intensity.medium, Expressiveness.dramatic).rateChange, -23);
      // A calm line is left exactly as the voice reads it.
      expect(
        Delivery.lower(
          const Direction(speakerId: 'a'),
          _caps(prosody: true),
        ).toJson(),
        isEmpty,
      );
    });

    test('vocal cues survive only where the engine can voice them', () {
      final delivery = Delivery.lower(
        _angry,
        _caps(cues: {VocalCueKind.laugh}),
      );
      // No sigh; the chuckle becomes the laugh the engine does have.
      expect(delivery.cues, [const VocalCue(VocalCueKind.laugh, offset: 4)]);
      expect(
        delivery.inline('Fine then.', (kind) => '(${kind.name})'),
        'Fine(laugh) then.',
      );
    });

    test('plain reading drops the performance; dramatic raises it', () {
      final rich = _caps(
        emotions: Emotion.values.toSet(),
        intensity: true,
        instruction: true,
        cues: VocalCueKind.values.toSet(),
      );
      final plain = Delivery.lower(
        _angry,
        rich,
        expressiveness: Expressiveness.plain,
      );
      expect(plain.toJson(), {'emotion': 'calm', 'intensity': 'mild'});
      final dramatic = Delivery.lower(
        _angry,
        rich,
        expressiveness: Expressiveness.dramatic,
      );
      expect(dramatic.intensity, Intensity.strong);
      expect(dramatic.cues, hasLength(2));
    });

    test('a long line split into requests keeps each cue with its text', () {
      final delivery = Delivery.lower(
        const Direction(
          speakerId: 'a',
          cues: [
            VocalCue(VocalCueKind.sigh),
            VocalCue(VocalCueKind.laugh, offset: 10),
          ],
        ),
        _caps(cues: VocalCueKind.values.toSet()),
      );
      expect(delivery.chunk(0, 6, last: false).cues, [
        const VocalCue(VocalCueKind.sigh),
      ]);
      expect(delivery.chunk(6, 10, last: true).cues, [
        const VocalCue(VocalCueKind.laugh, offset: 4),
      ]);
    });
  });

  test('directions written before pace, volume and cues keep their JSON', () {
    const old = Direction(
      speakerId: 'a',
      emotion: Emotion.sad,
      intensity: Intensity.strong,
      note: 'Softly.',
    );
    expect(old.toJson().keys, ['speakerId', 'emotion', 'intensity', 'note']);
    final restored = Direction.fromJson(_angry.toJson());
    expect(restored.pace, Pace.fast);
    expect(restored.volume, Volume.loud);
    expect(restored.cues, _angry.cues);
  });

  group('adapters translate a delivery to their own wire format', () {
    final wav = PcmAudio(samples: Int16List.fromList([1])).toWav();

    test(
      'MiniMax 2.8 sends emotion, prosody and inline interjections',
      () async {
        late Map<String, Object?> body;
        final adapter = MiniMaxTtsAdapter(
          apiKey: 'fixture-secret',
          client: MockClient((request) async {
            body = jsonDecode(request.body) as Map<String, Object?>;
            return http.Response(
              jsonEncode({
                'base_resp': {'status_code': 0},
                'data': {
                  'status': 2,
                  'audio': wav
                      .map((b) => b.toRadixString(16).padLeft(2, '0'))
                      .join(),
                },
                'extra_info': {'usage_characters': 4},
              }),
              200,
            );
          }),
        );
        addTearDown(adapter.close);
        const binding = VoiceBinding(
          provider: 'minimax',
          model: 'speech-2.8-hd',
          voiceId: 'voice',
        );
        await adapter.synthesize(
          TtsRequest(
            text: '算了。',
            language: 'zh',
            binding: binding,
            delivery: Delivery.lower(
              const Direction(
                speakerId: 'a',
                emotion: Emotion.sad,
                pace: Pace.slow,
                volume: Volume.soft,
                cues: [VocalCue(VocalCueKind.sigh)],
              ),
              adapter.capabilitiesFor(binding),
            ),
          ),
        );
        expect(body['text'], '(sighs)算了。');
        expect(body['voice_setting'], {
          'voice_id': 'voice',
          'speed': 0.88,
          'vol': 0.8,
          'pitch': 0,
          'emotion': 'sad',
        });
        // Earlier models would read a tag aloud, so they are never sent one.
        expect(
          adapter
              .capabilitiesFor(
                const VoiceBinding(
                  provider: 'minimax',
                  model: 'speech-02-hd',
                  voiceId: 'voice',
                ),
              )
              .cues,
          isEmpty,
        );
      },
    );

    test('Bailian sends the instruction and inline sound tags', () async {
      late Map<String, Object?> input;
      final adapter = BailianTtsAdapter(
        apiKey: 'fixture-secret',
        client: MockClient((request) async {
          if (request.method == 'GET') return http.Response.bytes(wav, 200);
          input =
              (jsonDecode(request.body) as Map)['input']
                  as Map<String, Object?>;
          return http.Response(
            jsonEncode({
              'output': {
                'finish_reason': 'stop',
                'audio': {'url': 'https://audio.example/a.wav'},
              },
              'usage': {'characters': 4},
            }),
            200,
          );
        }),
      );
      addTearDown(adapter.close);
      const binding = VoiceBinding(
        provider: 'bailian',
        model: 'qwen-audio-3.1-tts-flash',
        voiceId: 'Emily_v3.1',
      );
      await adapter.synthesize(
        TtsRequest(
          text: 'Never mind.',
          language: 'en',
          binding: binding,
          delivery: Delivery.lower(
            const Direction(
              speakerId: 'a',
              emotion: Emotion.sad,
              intensity: Intensity.medium,
              pace: Pace.slow,
              cues: [VocalCue(VocalCueKind.sigh)],
            ),
            adapter.capabilitiesFor(binding),
          ),
        ),
      );
      expect(input['text'], '[sighing]Never mind.');
      expect(
        input['instruction'],
        'Read with a sad emotion and medium intensity. Speak slowly.',
      );
    });
  });
}
