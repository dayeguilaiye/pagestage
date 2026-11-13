import 'dart:io';

import 'package:pagestage_core/pagestage_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late LocalStore store;
  late Book book;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('editor-');
    store = LocalStore('${dir.path}/db.sqlite');
    final file = await File(
      '${dir.path}/novel.txt',
    ).writeAsString('Chapter 1\n"Go," she said.\n');
    book = await Library(store).importTxt(file.path);
    await CastRepository(store).save(
      Cast(
        bookId: book.id,
        profiledThrough: 1,
        speakers: [
          Speaker(id: 'narrator', name: 'Narrator', kind: SpeakerKind.narrator),
          Speaker(id: 'ann', name: 'Ann', chapters: [1]),
          Speaker(
            id: 'guest',
            name: 'Guest',
            kind: SpeakerKind.provisional,
            dialogueCount: 1,
            chapters: [1],
          ),
        ],
      ),
    );
    await ScriptRepository(store).save(
      Script(
        bookId: book.id,
        chapterNumber: 1,
        sourceTextHash: book.chapter(1).textHash,
        model: 'offline',
        promptVersion: Director.promptVersion,
        lines: const [
          ScriptLine(
            start: 0,
            end: 6,
            direction: Direction(speakerId: 'guest', emotion: Emotion.angry),
          ),
          ScriptLine(
            start: 6,
            end: 16,
            direction: Direction(speakerId: 'narrator'),
            isDialogueTag: true,
          ),
        ],
      ),
    );
  });
  tearDown(() async {
    await store.close();
    await dir.delete(recursive: true);
  });

  test(
    'a line given to the wrong speaker is handed to the right one',
    () async {
      final before = AudioRepository.hashScript(
        (await ScriptRepository(store).get(book.id, 1))!,
      );
      final revised = await ScriptEditor(
        store,
      ).revise(book, 1, 0, speakerId: 'ann');
      expect(revised.lines.first.direction.speakerId, 'ann');
      // The rest of the direction, and every other line, is untouched.
      expect(revised.lines.first.direction.emotion, Emotion.angry);
      expect(revised.lines.last.direction.speakerId, 'narrator');
      final saved = (await ScriptRepository(store).get(book.id, 1))!;
      expect(AudioRepository.hashScript(saved), isNot(before));
      final cast = await CastRepository(store).get(book.id);
      expect(cast.speaker('guest').dialogueCount, 0);
    },
  );

  test('narration given to a character stops being a dialogue tag', () async {
    final revised = await ScriptEditor(
      store,
    ).revise(book, 1, 1, speakerId: 'guest');
    expect(revised.lines.last.isDialogueTag, isFalse);
    final cast = await CastRepository(store).get(book.id);
    expect(cast.speaker('guest').dialogueCount, 2);
  });

  test('unknown lines, speakers and stale scripts are refused', () async {
    final editor = ScriptEditor(store);
    await expectLater(
      editor.revise(book, 1, 9, speakerId: 'ann'),
      throwsRangeError,
    );
    await expectLater(
      editor.revise(book, 1, 0, speakerId: 'nobody'),
      throwsStateError,
    );
    await store.delete('scripts', '${book.id}:1');
    await expectLater(
      editor.revise(book, 1, 0, speakerId: 'ann'),
      throwsStateError,
    );
  });
}
