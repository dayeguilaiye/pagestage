import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pagestage_core/pagestage_core.dart';

class MingPreparation {
  const MingPreparation(
    this.phase,
    this.done,
    this.total,
    this.percent,
    this.detail,
  );

  factory MingPreparation.fromMap(Map<dynamic, dynamic> value) =>
      MingPreparation(
        value['phase'] as String,
        value['done'] as int,
        value['total'] as int,
        value['percent'] as int,
        value['detail'] as String,
      );

  final String phase;
  final int done;
  final int total;
  final int percent;
  final String detail;

  bool get ready => phase == 'ready';
  bool get working => phase == 'copying' || phase == 'compiling';
}

/// Observes the native process even while the settings page is closed.
class MingDevice extends ValueNotifier<MingPreparation> {
  MingDevice(
    super.value, {
    this.voices = const [],
    this.legacyVoiceIds = const {},
  });

  final List<VoicePreset> voices;
  final Set<String> legacyVoiceIds;

  void checkBinding(VoiceBinding binding) {
    if (binding.provider != 'ming' ||
        binding.model != MingTtsEngine.model ||
        !(legacyVoiceIds.contains(binding.voiceId) ||
            voices.any((v) => v.binding.voiceId == binding.voiceId))) {
      throw const ProviderException(
        provider: 'ming',
        kind: ProviderErrorKind.invalidVoice,
      );
    }
  }

  static VoicePreset _preset(Map row) {
    final id = row['id'] as String;
    return VoicePreset(
      id: 'ming:$id',
      binding: VoiceBinding(
        provider: 'ming',
        model: MingTtsEngine.model,
        voiceId: id,
      ),
      description: row['description'] as String,
      displayName: row['name'] as String?,
      gender: row['gender'] as String,
      ageGroup: row['ageGroup'] as String? ?? 'unknown',
      styles: (row['styles'] as List? ?? []).cast<String>(),
      languages: (row['languages'] as List).cast<String>(),
      narratorCandidate: row['narratorCandidate'] == true,
    );
  }

  static const _methods = MethodChannel('pagestage/ming');
  static const _events = EventChannel('pagestage/ming/progress');
  StreamSubscription<dynamic>? _subscription;

  factory MingDevice.fromSnapshot(Map<String, dynamic> snapshot) {
    final rows = (snapshot['voices'] as List).cast<Map>();
    return MingDevice(
      MingPreparation.fromMap(snapshot),
      voices: List.unmodifiable(
        rows.where((row) => row['legacy'] != true).map(_preset),
      ),
      legacyVoiceIds: {
        for (final row in rows)
          if (row['legacy'] == true) row['id'] as String,
      },
    );
  }

  static Future<MingDevice?> open() async {
    final snapshot = await _methods.invokeMapMethod<String, dynamic>('status');
    if (snapshot == null || snapshot['available'] != true) return null;
    final device = MingDevice.fromSnapshot(snapshot);
    device._subscription = _events.receiveBroadcastStream().listen((event) {
      device.value = MingPreparation.fromMap(event as Map);
    });
    return device;
  }

  Future<void> initialize() async {
    await _methods.invokeMethod<void>('initialize');
  }

  Future<List<TtsAudio>> synthesize(List<TtsRequest> lines) async {
    if (!value.ready) throw MingTtsEngine.unprepared;
    for (final request in lines) {
      checkBinding(request.binding);
    }
    try {
      final rows = await _methods.invokeListMethod<Uint8List>('synthesize', {
        'lines': [
          for (final request in lines)
            {
              'text': request.text,
              'voice': request.binding.voiceId,
              'emotion':
                  MingTtsEngine.emotions[request.delivery.emotion] ?? '中性',
            },
        ],
      });
      if (rows == null ||
          rows.length != lines.length ||
          rows.any((bytes) => bytes.isEmpty || bytes.length.isOdd)) {
        throw const ProviderException(
          provider: 'ming',
          kind: ProviderErrorKind.invalidResponse,
        );
      }
      return [
        for (final (index, bytes) in rows.indexed)
          TtsAudio(
            audio: PcmAudio(samples: _samples(bytes), sampleRate: 44100),
            characters: lines[index].text.runes.length,
          ),
      ];
    } on PlatformException catch (e) {
      throw ProviderException(
        provider: 'ming',
        kind: ProviderErrorKind.unavailable,
        code: e.code,
      );
    }
  }

  static Int16List _samples(Uint8List bytes) {
    final view = ByteData.sublistView(bytes);
    final samples = Int16List(bytes.length ~/ 2);
    for (var i = 0; i < samples.length; i++) {
      samples[i] = view.getInt16(i * 2, Endian.little);
    }
    return samples;
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

class MingTtsEngine implements TtsEngine {
  const MingTtsEngine(this.device);
  final MingDevice device;
  static const model = 'ming-3.0-tts-0.5b-10step-matrix2-v1';
  static const emotions = {
    Emotion.calm: '中性',
    Emotion.happy: '高兴',
    Emotion.angry: '愤怒',
    Emotion.surprised: '惊讶',
    Emotion.sad: '悲伤',
    Emotion.fearful: '恐惧',
    Emotion.disgusted: '厌恶',
  };
  static const unprepared = ProviderException(
    provider: 'ming',
    kind: ProviderErrorKind.invalidConfiguration,
    code: 'mingNotInitialized',
  );

  @override
  String get id => 'ming';
  @override
  EngineLocality get locality => EngineLocality.device;
  @override
  List<EngineField> get fields => const [];
  @override
  int get requestsPerMinute => 60000;
  @override
  EngineReadiness readiness(ProviderConfiguration config) =>
      device.value.ready ? EngineReadiness.ready : EngineReadiness.notInstalled;
  @override
  Uri? endpoint(ProviderConfiguration config) => null;
  @override
  String? designModel(ProviderConfiguration config) => null;
  @override
  List<VoicePreset> presets(ProviderConfiguration config) => device.voices;
  @override
  TtsCapabilities capabilitiesFor(
    VoiceBinding binding,
    ProviderConfiguration config,
  ) => MingAdapter(device).capabilitiesFor(binding);
  @override
  OpenedTts open(ProviderConfiguration config, {UsageLedger? usageLedger}) {
    if (!device.value.ready) throw unprepared;
    return (adapter: MingAdapter(device), close: () {});
  }
}

class MingAdapter implements PairedTtsAdapter {
  const MingAdapter(this.device);
  final MingDevice device;
  @override
  String get provider => 'ming';
  @override
  TtsCapabilities capabilitiesFor(VoiceBinding binding) {
    device.checkBinding(binding);
    return TtsCapabilities(
      supportsPronunciation: false,
      maxCharacters: 48,
      emotions: MingTtsEngine.emotions.keys.toSet(),
      pairedSynthesis: true,
    );
  }

  @override
  Future<TtsAudio> synthesize(TtsRequest request) async =>
      (await device.synthesize([request])).single;
  @override
  Future<(TtsAudio, TtsAudio)> synthesizePair(
    TtsRequest first,
    TtsRequest second,
  ) async {
    final audio = await device.synthesize([first, second]);
    return (audio[0], audio[1]);
  }
}
