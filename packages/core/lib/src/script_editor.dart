import 'local_store.dart';
import 'models/book.dart';
import 'models/cast.dart';
import 'models/script.dart';
import 'script_repository.dart';

/// A reader's corrections to a directed chapter. The director is right most
/// of the time; when it gives a line to the wrong speaker, the reader says
/// who it was and only that line is voiced again.
class ScriptEditor {
  ScriptEditor(this.store);
  final LocalStore store;

  /// Changes who speaks line [lineIndex] of [chapter], and optionally how.
  /// Returns the saved script. Audio for the chapter is voiced again from
  /// the per-line cache, so unchanged lines cost nothing.
  Future<Script> revise(
    Book book,
    int chapter,
    int lineIndex, {
    String? speakerId,
    Emotion? emotion,
    Intensity? intensity,
  }) async {
    final script = await ScriptRepository(store).get(book.id, chapter);
    if (script == null ||
        script.sourceTextHash != book.chapter(chapter).textHash) {
      throw StateError('This chapter has no current script.');
    }
    if (lineIndex < 0 || lineIndex >= script.lines.length) {
      throw RangeError.index(lineIndex, script.lines, 'lineIndex');
    }
    var cast = await CastRepository(store).get(book.id);
    final line = script.lines[lineIndex];
    final speaker = speakerId == null ? null : cast.speaker(speakerId);
    final direction = line.direction.copyWith(
      speakerId: speaker?.id,
      emotion: emotion,
      intensity: intensity,
    );
    final revised = Script(
      bookId: script.bookId,
      chapterNumber: script.chapterNumber,
      sourceTextHash: script.sourceTextHash,
      model: script.model,
      promptVersion: script.promptVersion,
      lines: [
        for (final (index, other) in script.lines.indexed)
          if (index == lineIndex)
            ScriptLine(
              start: line.start,
              end: line.end,
              direction: direction,
              // Words given to a character are that character's own.
              isDialogueTag:
                  line.isDialogueTag && direction.speakerId == 'narrator',
              isNonStory: line.isNonStory,
            )
          else
            other,
      ],
    );
    if (speaker != null && speaker.id != line.direction.speakerId) {
      // Provisional characters are ranked by the lines directing gave them.
      final previous = cast.findSpeaker(line.direction.speakerId);
      cast = cast.copyWith(
        speakers: [
          for (final member in cast.speakers)
            if (member.kind != SpeakerKind.provisional)
              member
            else if (member.id == speaker.id)
              member.copyWith(
                dialogueCount: member.dialogueCount + 1,
                chapters: {...member.chapters, chapter}.toList()..sort(),
              )
            else if (member.id == previous?.id && member.dialogueCount > 0)
              member.copyWith(dialogueCount: member.dialogueCount - 1)
            else
              member,
        ],
      );
    }
    await store.transaction(() async {
      await CastRepository(store).save(cast);
      await ScriptRepository(store).save(revised);
    });
    return revised;
  }
}
