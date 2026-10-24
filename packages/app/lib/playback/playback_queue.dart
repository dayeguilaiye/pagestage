import 'dart:io';
import 'dart:typed_data';

import 'package:pagestage_core/pagestage_core.dart';

/// The same sample timeline is used by both engine candidates. Silence is PCM
/// in the timeline, so no Dart timer decides when the next line starts.
class PlaybackEntry {
  const PlaybackEntry(this.utterance, this.start);
  final SynthesizedUtterance utterance;
  final Duration start;
  Duration get audioStart => start + utterance.pauseBefore;
  Duration get end => audioStart + utterance.duration;
}

class PlaybackQueue {
  PlaybackQueue(List<SynthesizedUtterance> utterances) {
    var offset = Duration.zero;
    for (final utterance in utterances) {
      if (utterance.duration.isNegative ||
          utterance.pauseBefore.isNegative ||
          utterance.lineIndices.isEmpty) {
        throw ArgumentError('Invalid audio interval.');
      }
      final entry = PlaybackEntry(utterance, offset);
      _entries.add(entry);
      offset = entry.end;
    }
  }
  final _entries = <PlaybackEntry>[];
  List<PlaybackEntry> get entries => List.unmodifiable(_entries);
  Duration get duration => _entries.isEmpty ? Duration.zero : _entries.last.end;
  int indexAt(Duration position) {
    if (_entries.isEmpty) return -1;
    for (var i = 0; i < _entries.length; i++) {
      if (position < _entries[i].end) return i;
    }
    return _entries.length - 1;
  }

  int indexForLine(int line) => _entries.indexWhere(
    (entry) => entry.utterance.lineIndices.contains(line),
  );
  Duration positionForLine(int line) {
    final index = indexForLine(line);
    if (index < 0) {
      throw ArgumentError.value(line, 'line', 'This line has no audio.');
    }
    return _entries[index].audioStart;
  }

  /// Materializes this already-synthesized chapter in bounded memory, copying
  /// normalized mono PCM and the declared pauses without re-encoding speech.
  Future<void> writeWav(File output) async {
    await output.parent.create(recursive: true);
    final staging = File('${output.path}.part');
    final sink = await staging.open(mode: FileMode.write);
    var sampleRate = 24000;
    var count = 0;
    try {
      await sink.writeFrom(List.filled(44, 0));
      for (final entry in _entries) {
        final audio = PcmAudio.fromWav(
          await File(entry.utterance.audioPath).readAsBytes(),
        );
        if (count == 0) sampleRate = audio.sampleRate;
        if (audio.sampleRate != sampleRate) {
          throw StateError('Audio sample rates must match.');
        }
        final silence =
            sampleRate * entry.utterance.pauseBefore.inMicroseconds ~/ 1000000;
        await sink.writeFrom(Uint8List(silence * 2));
        final pcm = audio.toWav();
        await sink.writeFrom(pcm, 44);
        count += silence + audio.samples.length;
      }
      final header = ByteData.sublistView(
        PcmAudio(samples: Int16List(0), sampleRate: sampleRate).toWav(),
      );
      header.setUint32(4, 36 + count * 2, Endian.little);
      header.setUint32(40, count * 2, Endian.little);
      await sink.setPosition(0);
      await sink.writeFrom(header.buffer.asUint8List());
      await sink.flush();
    } finally {
      await sink.close();
    }
    await staging.rename(output.path);
  }
}
