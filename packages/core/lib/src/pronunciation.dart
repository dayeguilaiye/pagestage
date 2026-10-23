import 'dart:convert';

import 'models/cast.dart';

class PronunciationMatch {
  const PronunciationMatch(this.start, this.end, this.entry);
  final int start;
  final int end;
  final PronunciationEntry entry;
}

/// Leftmost, longest matches; source offsets stay UTF-16, like Script lines.
List<PronunciationMatch> pronunciationMatches(
  String text,
  List<PronunciationEntry> lexicon,
) {
  final entries = <String, PronunciationEntry>{};
  for (final entry in lexicon) {
    if (entry.term.isEmpty || !text.contains(entry.term)) continue;
    final normalized = PronunciationEntry(entry.term, _pinyin(entry.pinyin));
    if (normalized.pinyin.split(' ').length != entry.term.runes.length) {
      throw const FormatException(
        'Pinyin needs one syllable per term character.',
      );
    }
    final previous = entries[entry.term];
    if (previous != null && previous.pinyin != normalized.pinyin) {
      throw const FormatException('Conflicting pronunciations for one term.');
    }
    entries[entry.term] = normalized;
  }
  final candidates = entries.values.toList()
    ..sort((a, b) {
      final length = b.term.length.compareTo(a.term.length);
      return length == 0 ? a.term.compareTo(b.term) : length;
    });
  final result = <PronunciationMatch>[];
  for (var offset = 0; offset < text.length;) {
    PronunciationEntry? match;
    for (final entry in candidates) {
      if (text.startsWith(entry.term, offset)) {
        match = entry;
        break;
      }
    }
    if (match == null) {
      offset++;
    } else {
      result.add(PronunciationMatch(offset, offset + match.term.length, match));
      offset += match.term.length;
    }
  }
  return result;
}

List<PronunciationEntry> matchedPronunciations(
  List<PronunciationMatch> matches,
) {
  final byTerm = {for (final match in matches) match.entry.term: match.entry};
  final terms = byTerm.keys.toList()..sort();
  return [for (final term in terms) byTerm[term]!];
}

String _pinyin(String source) {
  const accented = ['āáǎà', 'ēéěè', 'īíǐì', 'ōóǒò', 'ūúǔù', 'ǖǘǚǜ'];
  const vowels = ['a', 'e', 'i', 'o', 'u', 'v'];
  final syllables = source.trim().toLowerCase().split(RegExp(r'\s+'));
  return syllables
      .map((syllable) {
        var tone = 0;
        var plain = syllable.replaceAll('u:', 'v').replaceAll('ü', 'v');
        for (var i = 0; i < accented.length; i++) {
          for (var j = 0; j < 4; j++) {
            if (plain.contains(accented[i][j])) {
              if (tone != 0) {
                throw const FormatException('Invalid pinyin tone.');
              }
              tone = j + 1;
              plain = plain.replaceAll(accented[i][j], vowels[i]);
            }
          }
        }
        if (RegExp(r'[0-5]$').hasMatch(plain)) {
          final numeric = int.parse(plain[plain.length - 1]);
          if (tone != 0 && tone != numeric) {
            throw const FormatException('Conflicting pinyin tones.');
          }
          tone = numeric == 0 ? 5 : numeric;
          plain = plain.substring(0, plain.length - 1);
        }
        if (!RegExp(r'^[a-zv]+$').hasMatch(plain)) {
          throw const FormatException(
            'Expected space-separated pinyin syllables.',
          );
        }
        return '$plain${tone == 0 ? 5 : tone}';
      })
      .join(' ');
}

String pronunciationSsml(String text, List<PronunciationMatch> matches) {
  const escape = HtmlEscape();
  final result = StringBuffer('<speak>');
  var offset = 0;
  for (final match in matches) {
    result.write(escape.convert(text.substring(offset, match.start)));
    result.write(
      '<phoneme alphabet="py" ph="${escape.convert(match.entry.pinyin)}">',
    );
    result.write(escape.convert(text.substring(match.start, match.end)));
    result.write('</phoneme>');
    offset = match.end;
  }
  result.write(escape.convert(text.substring(offset)));
  result.write('</speak>');
  return result.toString();
}
