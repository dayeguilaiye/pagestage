import 'models/script.dart';
import 'providers/tts_adapter.dart';

/// How much of the director's performance a book asks of its voices.
enum Expressiveness {
  /// Distinct voices reading evenly: no emotion, notes or vocal cues.
  plain,

  /// The performance as directed.
  natural,

  /// Emotions one step stronger than directed.
  dramatic,
}

/// A [Direction] reduced to what one voice binding can perform.
///
/// The director writes one script for every engine. Before a line is voiced,
/// its direction is lowered against the capabilities of the voice it was
/// cast to: what the engine can express stays, what it has a near
/// substitute for is substituted, and the rest is left out. Adapters only
/// translate a delivery to their wire format, and audio is cached by it, so
/// direction an engine cannot perform neither reaches it nor invalidates
/// audio it already made.
class Delivery {
  const Delivery({
    this.emotion,
    this.intensity,
    this.note = '',
    this.pace = Pace.normal,
    this.volume = Volume.normal,
    this.cues = const [],
    this.rateChange = 0,
    this.volumeChange = 0,
    this.pitchChange = 0,
  });

  /// Null when the engine has no way to express an emotion.
  final Emotion? emotion;

  /// Null when the engine cannot vary how strongly an emotion shows.
  final Intensity? intensity;

  /// Free-text vocal direction, kept only for engines that take one.
  final String note;

  /// Kept only for engines that take a free-text instruction and have no
  /// numeric controls; otherwise they arrive as [rateChange] and
  /// [volumeChange].
  final Pace pace;
  final Volume volume;

  /// Offsets are relative to the text this delivery travels with.
  final List<VocalCue> cues;

  /// Percent changes from the voice's own pace, loudness and pitch, for
  /// engines with numeric controls. They carry the directed pace and volume
  /// and, when the engine has no other way to show it, the emotion.
  final int rateChange;
  final int volumeChange;
  final int pitchChange;

  /// The delivery of a line without any direction, such as a voice sample.
  factory Delivery.calm(TtsCapabilities capabilities) =>
      Delivery.lower(const Direction(speakerId: ''), capabilities);

  factory Delivery.lower(
    Direction direction,
    TtsCapabilities capabilities, {
    Expressiveness expressiveness = Expressiveness.natural,
  }) {
    final plain = expressiveness == Expressiveness.plain;
    final directed = plain ? Emotion.calm : direction.emotion;
    var strength = plain ? Intensity.mild : direction.intensity;
    if (expressiveness == Expressiveness.dramatic &&
        directed != Emotion.calm &&
        strength != Intensity.strong) {
      strength = Intensity.values[strength.index + 1];
    }
    final pace = plain ? Pace.normal : direction.pace;
    final volume = plain ? Volume.normal : direction.volume;

    // Emotion: spoken natively, described in an instruction, replaced by
    // the nearest emotion the engine has, or left to pace and pitch.
    Emotion? emotion;
    if (capabilities.emotions.contains(directed) || capabilities.instruction) {
      emotion = directed;
    } else {
      for (final near in _nearEmotions[directed] ?? const <Emotion>[]) {
        if (capabilities.emotions.contains(near)) {
          emotion = near;
          break;
        }
      }
    }
    final expressed = emotion != null;
    final scaled = capabilities.intensity || capabilities.instruction;

    var rate = 0, loudness = 0, pitch = 0;
    if (capabilities.prosody) {
      rate += const [-12, 0, 12][pace.index];
      loudness += const [-20, 0, 20][volume.index];
      if (!expressed && directed != Emotion.calm) {
        final (r, v, p) = _emulation[directed]!;
        final scale =
            const [0.5, 1.0, 1.5][strength.index] *
            (expressiveness == Expressiveness.dramatic ? 1.5 : 1.0);
        rate += (r * scale).round();
        loudness += (v * scale).round();
        pitch += (p * scale).round();
      }
    }

    final cues = <VocalCue>[];
    if (!plain) {
      for (final cue in direction.cues) {
        final kind = capabilities.cues.contains(cue.kind)
            ? cue.kind
            : (_nearCues[cue.kind] ?? const <VocalCueKind>[])
                  .where(capabilities.cues.contains)
                  .firstOrNull;
        if (kind != null) cues.add(VocalCue(kind, offset: cue.offset));
      }
      cues.sort((a, b) => a.offset.compareTo(b.offset));
    }

    final verbal = capabilities.instruction && !capabilities.prosody;
    return Delivery(
      emotion: emotion,
      intensity: expressed && scaled ? strength : null,
      note: capabilities.instruction && !plain ? direction.note.trim() : '',
      pace: verbal ? pace : Pace.normal,
      volume: verbal ? volume : Volume.normal,
      cues: List.unmodifiable(cues),
      rateChange: rate.clamp(-40, 40),
      volumeChange: loudness.clamp(-40, 40),
      pitchChange: pitch.clamp(-40, 40),
    );
  }

  /// The part of this delivery that travels with the text range
  /// [start]..[end] of the line, when a long line is voiced in several
  /// requests. A cue at the very end of the line stays with the [last] one.
  Delivery chunk(int start, int end, {required bool last}) => Delivery(
    emotion: emotion,
    intensity: intensity,
    note: note,
    pace: pace,
    volume: volume,
    rateChange: rateChange,
    volumeChange: volumeChange,
    pitchChange: pitchChange,
    cues: [
      for (final cue in cues)
        if (cue.offset >= start &&
            (cue.offset < end || (last && cue.offset >= end)))
          VocalCue(
            cue.kind,
            offset: (cue.offset - start).clamp(0, end - start),
          ),
    ],
  );

  /// One sentence asking for this delivery, for engines that take a
  /// free-text instruction.
  String instruction(String language) {
    final note = this.note.trim();
    final emotion = this.emotion ?? Emotion.calm;
    final intensity = this.intensity ?? Intensity.mild;
    if (language == 'zh') {
      const emotions = ['平静', '开心', '悲伤', '愤怒', '恐惧', '厌恶', '惊讶'];
      const intensities = ['轻', '中', '强'];
      return '以${emotions[emotion.index]}的语气、'
          '强度${intensities[intensity.index]}朗读。'
          '${const ['语速放慢。', '', '语速加快。'][pace.index]}'
          '${const ['声音放轻。', '', '声音放大。'][volume.index]}'
          '$note';
    }
    return [
      'Read with ${emotion == Emotion.angry ? 'an' : 'a'} ${emotion.name} '
          'emotion and ${intensity.name} intensity.',
      const ['Speak slowly.', '', 'Speak quickly.'][pace.index],
      const ['Speak softly.', '', 'Speak loudly.'][volume.index],
      note,
    ].where((part) => part.isNotEmpty).join(' ');
  }

  /// [text] with each cue written in the engine's own inline syntax by
  /// [tag]. Cues [tag] has no word for are left out.
  String inline(String text, String? Function(VocalCueKind kind) tag) {
    final buffer = StringBuffer();
    var written = 0;
    for (final cue in cues) {
      final word = tag(cue.kind);
      if (word == null) continue;
      var offset = cue.offset.clamp(written, text.length);
      // Never split a surrogate pair.
      if (offset > 0 &&
          offset < text.length &&
          text.codeUnitAt(offset) & 0xfc00 == 0xdc00) {
        offset++;
      }
      buffer
        ..write(text.substring(written, offset))
        ..write(word);
      written = offset;
    }
    buffer.write(text.substring(written));
    return buffer.toString();
  }

  /// Canonical identity for audio caching: only what differs from an
  /// unmarked reading is written.
  Map<String, Object?> toJson() => {
    if (emotion != null) 'emotion': emotion!.name,
    if (intensity != null) 'intensity': intensity!.name,
    if (note.isNotEmpty) 'note': note,
    if (pace != Pace.normal) 'pace': pace.name,
    if (volume != Volume.normal) 'volume': volume.name,
    if (cues.isNotEmpty) 'cues': cues.map((cue) => cue.toJson()).toList(),
    if (rateChange != 0) 'rate': rateChange,
    if (volumeChange != 0) 'loudness': volumeChange,
    if (pitchChange != 0) 'pitch': pitchChange,
  };
}

// The closest emotions to fall back on, nearest first.
const _nearEmotions = <Emotion, List<Emotion>>{
  Emotion.happy: [Emotion.surprised],
  Emotion.sad: [Emotion.fearful],
  Emotion.angry: [Emotion.disgusted],
  Emotion.fearful: [Emotion.sad, Emotion.surprised],
  Emotion.disgusted: [Emotion.angry, Emotion.sad],
  Emotion.surprised: [Emotion.happy, Emotion.fearful],
};

// Percent changes to (rate, loudness, pitch) that suggest an emotion at
// medium intensity on engines that only have numeric controls.
const _emulation = <Emotion, (int, int, int)>{
  Emotion.happy: (5, 5, 6),
  Emotion.sad: (-10, -10, -6),
  Emotion.angry: (6, 15, 3),
  Emotion.fearful: (10, -5, 8),
  Emotion.disgusted: (-4, 0, -4),
  Emotion.surprised: (6, 8, 10),
};

const _nearCues = <VocalCueKind, List<VocalCueKind>>{
  VocalCueKind.chuckle: [VocalCueKind.laugh],
  VocalCueKind.laugh: [VocalCueKind.chuckle],
  VocalCueKind.sob: [VocalCueKind.sniff],
  VocalCueKind.sniff: [VocalCueKind.sob],
  VocalCueKind.groan: [VocalCueKind.sigh],
  VocalCueKind.clearThroat: [VocalCueKind.cough],
  VocalCueKind.cough: [VocalCueKind.clearThroat],
};
