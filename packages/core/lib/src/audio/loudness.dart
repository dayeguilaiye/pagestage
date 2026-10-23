import 'dart:math' as math;
import 'dart:typed_data';

import '../models/loudness.dart';
import '../pcm_audio.dart';

({PcmAudio audio, LoudnessReport report}) normalizeLoudness(
  PcmAudio source,
  LoudnessSettings settings,
) {
  final level = _measure(source);
  final desiredGain = level == null
      ? 1.0
      : math.pow(10, (settings.targetLufs - level) / 20).toDouble();
  final boostCap = math.pow(10, settings.maxBoostDb / 20).toDouble();
  final ceiling = (32768 * math.pow(10, settings.samplePeakDbfs / 20))
      .floor()
      .clamp(1, 32767);
  var peak = 0;
  for (final sample in source.samples) {
    peak = math.max(peak, sample.abs());
  }
  final peakCap = peak == 0 ? double.infinity : ceiling / peak;
  final gain = math.min(desiredGain, math.min(boostCap, peakCap));
  final gainDb = 20 * math.log(gain) / math.ln10;
  return (
    audio: PcmAudio(
      sampleRate: source.sampleRate,
      samples: Int16List.fromList([
        for (final sample in source.samples)
          (sample * gain).round().clamp(-32768, 32767),
      ]),
    ),
    report: LoudnessReport(
      measurement: level == null
          ? LoudnessMeasurement.unmeasurable
          : source.samples.length < (source.sampleRate * 0.4).round()
          ? LoudnessMeasurement.shortClipEstimate
          : LoudnessMeasurement.integrated,
      inputLufs: level,
      estimatedOutputLufs: level == null ? null : level + gainDb,
      gainDb: gainDb,
      targetLufs: settings.targetLufs,
      peakLimited: gain < desiredGain && gain == peakCap,
      boostLimited: gain < desiredGain && gain == boostCap,
    ),
  );
}

double? _measure(PcmAudio source) {
  final shelf = _shelf(source.sampleRate);
  final highPass = _highPass(source.sampleRate);
  final block = math.max(1, (source.sampleRate * 0.4).round());
  final hop = math.max(1, (source.sampleRate * 0.1).round());
  final ring = Float64List(block);
  final energies = <double>[];
  var sum = 0.0;
  for (var i = 0; i < source.samples.length; i++) {
    final weighted = highPass.filter(shelf.filter(source.samples[i] / 32768));
    final energy = weighted * weighted;
    sum += energy - ring[i % block];
    ring[i % block] = energy;
    if (i + 1 >= block && (i + 1 - block) % hop == 0) {
      energies.add(math.max(0, sum) / block);
    }
  }
  if (energies.isEmpty && source.samples.isNotEmpty) {
    // A documented short-clip estimate over actual samples; no zero padding.
    energies.add(math.max(0, sum) / source.samples.length);
  }
  final absolute = energies.where((e) => e > 0 && _level(e) > -70).toList();
  if (absolute.isEmpty) return null;
  final relativeGate = _level(_mean(absolute)) - 10;
  final gated = absolute.where((e) => _level(e) > relativeGate).toList();
  return gated.isEmpty ? null : _level(_mean(gated));
}

double _mean(List<double> values) =>
    values.reduce((a, b) => a + b) / values.length;

double _level(double energy) => -0.691 + 10 * math.log(energy) / math.ln10;

// Sample-rate-adjusted K-weighting coefficients derived from libebur128
// ebur128_init_filter (MIT). Attribution and license: LIBEBUR128-LICENSE.
_Biquad _shelf(int rate) {
  final k = math.tan(math.pi * 1681.974450955533 / rate);
  const q = 0.7071752369554196;
  final vh = math.pow(10, 3.999843853973347 / 20);
  final vb = math.pow(vh, 0.4996667741545416);
  final d = 1 + k / q + k * k;
  return _Biquad(
    (vh + vb * k / q + k * k) / d,
    2 * (k * k - vh) / d,
    (vh - vb * k / q + k * k) / d,
    2 * (k * k - 1) / d,
    (1 - k / q + k * k) / d,
  );
}

_Biquad _highPass(int rate) {
  final k = math.tan(math.pi * 38.13547087602444 / rate);
  const q = 0.5003270373238773;
  final d = 1 + k / q + k * k;
  return _Biquad(1, -2, 1, 2 * (k * k - 1) / d, (1 - k / q + k * k) / d);
}

class _Biquad {
  _Biquad(this.b0, this.b1, this.b2, this.a1, this.a2);
  final double b0, b1, b2, a1, a2;
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;
  double filter(double x) {
    final y = b0 * x + b1 * _x1 + b2 * _x2 - a1 * _y1 - a2 * _y2;
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }
}
