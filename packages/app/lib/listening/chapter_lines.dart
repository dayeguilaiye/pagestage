import '../application/contracts.dart';

/// A run of chapter text inside one paragraph, belonging to one line.
class LineSegment {
  const LineSegment(
    this.text, {
    this.line,
    this.speaker,
    this.speakerId,
    this.speakerName,
    this.directed = false,
    this.nonStory = false,
  });

  final String text;

  /// The [ListeningLine.index] this run belongs to; null for plain text
  /// shown without listening.
  final int? line;

  /// Only on the first run of a line, so the cue appears once.
  final String? speaker;

  /// Who speaks the line, on every run of it.
  final String? speakerId;
  final String? speakerName;

  /// Whether [line] indexes the chapter's script, so the reader can
  /// correct who speaks it.
  final bool directed;
  final bool nonStory;

  /// Whether this run can be spoken, highlighted or played from.
  bool get spoken => line != null && !nonStory;
}

/// Paragraphs for the reader built from [lines], whose texts together are the
/// whole chapter. A newline inside a line's text ends a paragraph; blank
/// paragraphs are dropped and each paragraph's outer whitespace trimmed,
/// since the passage draws its own indent.
List<List<LineSegment>> layoutLines(List<ListeningLine> lines) {
  final sorted = [...lines]..sort((a, b) => a.index.compareTo(b.index));
  final paragraphs = <List<LineSegment>>[[]];
  final cued = <int>{};
  for (final line in sorted) {
    final parts = line.text.split('\n');
    for (final (i, part) in parts.indexed) {
      if (i > 0) paragraphs.add([]);
      if (part.isEmpty) continue;
      // The cue goes on the first run with something to read.
      final cue = part.trim().isNotEmpty && cued.add(line.index);
      paragraphs.last.add(
        LineSegment(
          part,
          line: line.index,
          speaker: cue ? line.speakerName : null,
          speakerId: line.speakerId,
          speakerName: line.speakerName,
          directed: line.directed,
          nonStory: line.nonStory,
        ),
      );
    }
  }
  return [
    for (final paragraph in paragraphs)
      if (_trim(paragraph) case final trimmed when trimmed.isNotEmpty) trimmed,
  ];
}

/// Plain paragraphs, for chapters read without listening.
List<List<LineSegment>> plainParagraphs(List<String> paragraphs) => [
  for (final text in paragraphs) [LineSegment(text)],
];

List<LineSegment> _trim(List<LineSegment> runs) {
  var first = 0;
  while (first < runs.length && runs[first].text.trim().isEmpty) {
    first++;
  }
  var last = runs.length - 1;
  while (last >= first && runs[last].text.trim().isEmpty) {
    last--;
  }
  if (first > last) return const [];
  final out = runs.sublist(first, last + 1);
  out.first = _with(out.first, out.first.text.trimLeft());
  out.last = _with(out.last, out.last.text.trimRight());
  return out;
}

LineSegment _with(LineSegment run, String text) => LineSegment(
  text,
  line: run.line,
  speaker: run.speaker,
  speakerId: run.speakerId,
  speakerName: run.speakerName,
  directed: run.directed,
  nonStory: run.nonStory,
);
