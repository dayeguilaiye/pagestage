/// Project settings for speech, not a broadcast delivery specification.
class LoudnessSettings {
  const LoudnessSettings({
    this.targetLufs = -20,
    this.maxBoostDb = 12,
    this.samplePeakDbfs = -1,
  });
  final double targetLufs;
  final double maxBoostDb;
  final double samplePeakDbfs;
  Map<String, Object?> toJson() => {
    'version': 'k-weighted-mono-v1',
    'targetLufs': targetLufs,
    'maxBoostDb': maxBoostDb,
    'samplePeakDbfs': samplePeakDbfs,
  };
}

enum LoudnessMeasurement { integrated, shortClipEstimate, unmeasurable }

class LoudnessReport {
  const LoudnessReport({
    required this.measurement,
    required this.inputLufs,
    required this.estimatedOutputLufs,
    required this.gainDb,
    required this.targetLufs,
    required this.peakLimited,
    required this.boostLimited,
  });
  final bool peakLimited;
  final bool boostLimited;
  final LoudnessMeasurement measurement;
  final double? inputLufs;
  final double? estimatedOutputLufs;
  final double gainDb;
  final double targetLufs;
  Map<String, Object?> toJson() => {
    'measurement': measurement.name,
    'peakLimited': peakLimited,
    'boostLimited': boostLimited,
    'inputLufs': inputLufs,
    'estimatedOutputLufs': estimatedOutputLufs,
    'gainDb': gainDb,
    'targetLufs': targetLufs,
  };
}
