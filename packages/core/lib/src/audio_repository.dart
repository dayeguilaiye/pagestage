import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'local_store.dart';
import 'casting.dart';
import 'library.dart';
import 'models/cast.dart';
import 'models/script.dart';
import 'synthesizer.dart';

/// A persisted chapter playlist. Partial playlists can be played immediately.
class ChapterAudio {
  ChapterAudio({
    required this.bookId,
    required this.chapter,
    required this.mode,
    required this.scriptHash,
    required List<SynthesizedUtterance> utterances,
    this.complete = false,
    this.path,
    this.inputsHash,
  }) : utterances = List.unmodifiable(utterances);

  final String bookId;
  final int chapter;
  final PerformanceMode mode;
  final String scriptHash;
  final List<SynthesizedUtterance> utterances;
  final bool complete;
  final String? path;
  final String? inputsHash;

  Duration get duration => utterances.fold(
    Duration.zero,
    (total, item) => total + item.pauseBefore + item.duration,
  );

  Map<String, Object?> toJson() => {
    'bookId': bookId,
    'chapter': chapter,
    'mode': mode.name,
    'scriptHash': scriptHash,
    'complete': complete,
    'path': path,
    'inputsHash': inputsHash,
    'utterances': utterances.map((item) => item.toJson()).toList(),
  };

  factory ChapterAudio.fromJson(Map<String, Object?> json) => ChapterAudio(
    bookId: json['bookId'] as String,
    chapter: json['chapter'] as int,
    mode: PerformanceMode.values.byName(json['mode'] as String),
    scriptHash: json['scriptHash'] as String,
    complete: json['complete'] as bool,
    path: json['path'] as String?,
    inputsHash: json['inputsHash'] as String?,
    utterances: (json['utterances'] as List)
        .map(
          (item) => SynthesizedUtterance.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
        .toList(),
  );
}

/// Owns generated audio inside the caller's data directory, separately per book.
class AudioRepository {
  AudioRepository(this.store, {Directory? directory})
    : directory =
          directory ?? Directory(p.join(p.dirname(store.path), 'audio'));
  final LocalStore store;
  final Directory directory;
  Directory get legacyCacheDirectory =>
      Directory(p.join(directory.path, 'cache'));

  static String hashScript(Script script) =>
      sha256.convert(utf8.encode(jsonEncode(script.toJson()))).toString();

  Future<String> hashInputs(Script script, PerformanceMode mode) async {
    final book = await Library(store).getBook(script.bookId);
    final ids =
        script.lines
            .where(
              (line) =>
                  !line.isNonStory &&
                  !(mode == PerformanceMode.drama && line.isDialogueTag) &&
                  line
                      .textIn(book.chapter(script.chapterNumber).text)
                      .trim()
                      .isNotEmpty,
            )
            .map((line) => line.direction.speakerId)
            .toSet()
            .toList()
          ..sort();
    final bindings = await Casting(
      store,
    ).getChapterBindings(book, script.chapterNumber, speakerIds: ids);
    final cast = await CastRepository(store).get(script.bookId);
    return sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'script': hashScript(script),
              'mode': mode.name,
              'bindings': {for (final id in ids) id: bindings[id]!.toJson()},
              'lexicon': cast.lexicon.map((entry) => entry.toJson()).toList(),
            }),
          ),
        )
        .toString();
  }

  Directory bookDirectory(String bookId) {
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(bookId)) {
      throw ArgumentError.value(bookId, 'bookId');
    }
    return Directory(p.join(directory.path, bookId));
  }

  Directory cacheDirectory(String bookId) =>
      Directory(p.join(bookDirectory(bookId).path, 'cache'));
  String outputPath(String bookId, int chapter, PerformanceMode mode) =>
      p.join(bookDirectory(bookId).path, 'chapter-$chapter-${mode.name}.wav');

  Future<ChapterAudio?> get(
    String bookId,
    int chapter, {
    PerformanceMode mode = PerformanceMode.audiobook,
  }) async {
    final json = await store.get('audio', '$bookId:$chapter:${mode.name}');
    return json == null ? null : ChapterAudio.fromJson(json);
  }

  Future<void> save(ChapterAudio audio) => store.put(
    'audio',
    '${audio.bookId}:${audio.chapter}:${audio.mode.name}',
    audio.toJson(),
  );

  Future<bool> isComplete(
    Script script, {
    PerformanceMode mode = PerformanceMode.audiobook,
  }) async {
    final audio = await get(script.bookId, script.chapterNumber, mode: mode);
    if (audio == null ||
        !audio.complete ||
        audio.scriptHash != hashScript(script)) {
      return false;
    }
    if (audio.inputsHash != await hashInputs(script, mode)) return false;
    for (final item in audio.utterances) {
      if (!await File(item.audioPath).exists()) return false;
    }
    return true;
  }

  Future<void> saveResult(
    Script script,
    SynthesisResult result, {
    PerformanceMode mode = PerformanceMode.audiobook,
    required String inputsHash,
  }) => save(
    ChapterAudio(
      bookId: script.bookId,
      chapter: script.chapterNumber,
      mode: mode,
      scriptHash: hashScript(script),
      utterances: result.utterances,
      path: result.path,
      complete: true,
      inputsHash: inputsHash,
    ),
  );
}
