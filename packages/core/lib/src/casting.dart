import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:crypto/crypto.dart';

import 'local_store.dart';
import 'models/book.dart';
import 'models/cast.dart';
import 'models/script.dart';
import 'providers/provider_exception.dart';
import 'models/voice.dart';
import 'preset_catalog.dart';
import 'providers/tts_adapter.dart';

class CastingResult {
  CastingResult({
    required this.cast,
    required Map<String, Voice> voices,
    Set<String> exclusiveSpeakerIds = const {},
    List<String> warnings = const [],
  }) : voices = Map.unmodifiable(voices),
       exclusiveSpeakerIds = Set.unmodifiable(exclusiveSpeakerIds),
       warnings = List.unmodifiable(warnings);
  final Cast cast;
  final Map<String, Voice> voices;
  final Set<String> exclusiveSpeakerIds;
  final List<String> warnings;
}

class Casting {
  Casting(this.store, {List<VoicePreset>? catalog, this.adapters = const {}})
    : catalog = List.unmodifiable(catalog ?? defaultVoiceCatalog);
  final LocalStore store;
  final List<VoicePreset> catalog;
  final Map<String, TtsAdapter> adapters;

  Future<Voice> getVoice(String voiceId) async {
    final json = await store.get('voices', voiceId);
    if (json == null) throw StateError('Voice not found.');
    return Voice.fromJson(json);
  }

  Future<CastingResult> getCasting(String bookId) async {
    final cast = await CastRepository(store).get(bookId);
    final voices = <String, Voice>{};
    for (final speaker in cast.speakers) {
      if (speaker.voiceId != null) {
        voices[speaker.id] = await getVoice(speaker.voiceId!);
      }
    }
    final options = await store.get('casting', bookId);
    return CastingResult(
      cast: cast,
      voices: voices,
      exclusiveSpeakerIds: (options?['exclusiveSpeakerIds'] as List? ?? [])
          .cast<String>()
          .toSet(),
      warnings: (options?['warnings'] as List? ?? []).cast<String>(),
    );
  }

  Future<CastingResult> recommend(
    Book book, {
    int exclusiveCount = 20,
    Set<String>? providers,
    String bailianRegion = 'beijing',
  }) => _recommend(
    book,
    exclusiveCount: exclusiveCount,
    providers: providers,
    bailianRegion: bailianRegion,
  );

  Future<CastingResult> _recommend(
    Book book, {
    required int exclusiveCount,
    Set<String>? providers,
    required String bailianRegion,
    Set<String>? fixedExclusiveIds,
  }) async {
    if (exclusiveCount < 0) {
      throw const FormatException('Exclusive count must be non-negative.');
    }
    if (!['beijing', 'singapore'].contains(bailianRegion)) {
      throw const FormatException('Unsupported Bailian region.');
    }
    final previous = await getCasting(book.id);
    if (previous.cast.profiledThrough == 0) {
      throw StateError('Profile the book before casting.');
    }
    final candidates =
        catalog
            .where(
              (voice) =>
                  voice.languages.contains(book.language) &&
                  (providers == null ||
                      providers.contains(voice.binding.provider)) &&
                  (voice.binding.provider != 'bailian' ||
                      voice.regions.contains(bailianRegion)),
            )
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (candidates.isEmpty) {
      throw StateError('No presets match this language and provider region.');
    }
    final eligibleBindings = candidates
        .map((preset) => _bindingKey(preset.binding))
        .toSet();
    bool preserveAutomatic(Speaker speaker, Voice voice) =>
        fixedExclusiveIds != null ||
        (eligibleBindings.contains(_bindingKey(voice.binding)) &&
            _inheritsPersona(previous.cast, speaker, voice));
    final ranked =
        previous.cast.speakers
            .where((s) => s.kind == SpeakerKind.character)
            .toList()
          ..sort((a, b) {
            final count = b.dialogueCount.compareTo(a.dialogueCount);
            return count == 0 ? a.id.compareTo(b.id) : count;
          });
    final exclusiveIds =
        fixedExclusiveIds ??
        ranked.take(exclusiveCount).map((s) => s.id).toSet();
    final voices = <String, Voice>{...previous.voices};
    Voice automaticVoice(Speaker speaker, VoicePreset preset) {
      final old = previous.voices[speaker.id];
      // Recommending the same binding preserves its existing audition sample.
      if (old != null &&
          _bindingKey(old.binding) == _bindingKey(preset.binding)) {
        return old;
      }
      return _voice(book, speaker, preset);
    }

    final reserved = <String>{};
    final warnings = <String>[];
    final speakers = previous.cast.speakers;
    final uniqueSpeakers = [
      ...speakers.where((s) => s.kind == SpeakerKind.narrator),
      ...speakers.where((s) => s.kind == SpeakerKind.persona),
      ...ranked.where((s) => exclusiveIds.contains(s.id)),
    ];
    final manualKeys = voices.values
        .where((v) => v.manuallySelected || v.binding.designed)
        .map((v) => _bindingKey(v.binding))
        .toSet();
    for (final speaker in uniqueSpeakers) {
      var voice = voices[speaker.id];
      if (voice != null &&
          (voice.manuallySelected ||
              voice.binding.designed ||
              preserveAutomatic(speaker, voice))) {
        if (!reserved.add(_bindingKey(voice.binding)) &&
            !_inheritsPersona(previous.cast, speaker, voice)) {
          warnings.add(
            'Voice for ${speaker.id} is shared with another priority speaker.',
          );
        }
        continue;
      }
      final available = [...candidates];
      available.sort((a, b) {
        final match = _compareMatch(speaker, a, b);
        if (match != 0) return match;
        final usedA =
            reserved.contains(_bindingKey(a.binding)) ||
            manualKeys.contains(_bindingKey(a.binding));
        final usedB =
            reserved.contains(_bindingKey(b.binding)) ||
            manualKeys.contains(_bindingKey(b.binding));
        if (usedA != usedB) return usedA ? 1 : -1;
        return a.id.compareTo(b.id);
      });
      if (reserved.contains(_bindingKey(available.first.binding)) ||
          manualKeys.contains(_bindingKey(available.first.binding))) {
        warnings.add(
          'Best matching preset is shared for ${speaker.id}; you can change it with cast set.',
        );
      }
      voice = automaticVoice(speaker, available.first);
      voices[speaker.id] = voice;
      reserved.add(_bindingKey(voice.binding));
    }
    final extras =
        speakers.where((s) => !uniqueSpeakers.any((u) => u.id == s.id)).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final allocatedExtras = <Speaker>[];
    for (final speaker in extras) {
      final old = voices[speaker.id];
      if (old != null &&
          (old.manuallySelected ||
              old.binding.designed ||
              preserveAutomatic(speaker, old))) {
        allocatedExtras.add(speaker);
        continue;
      }
      final pool = [...candidates];
      int overlaps(VoicePreset voice) => allocatedExtras
          .where(
            (other) =>
                other.chapters.any(speaker.chapters.contains) &&
                _bindingKey(voices[other.id]!.binding) ==
                    _bindingKey(voice.binding),
          )
          .length;
      pool.sort((a, b) {
        final match = _compareMatch(speaker, a, b);
        if (match != 0) return match;
        final reservedA = reserved.contains(_bindingKey(a.binding));
        final reservedB = reserved.contains(_bindingKey(b.binding));
        if (reservedA != reservedB) return reservedA ? 1 : -1;
        final overlap = overlaps(a).compareTo(overlaps(b));
        return overlap == 0 ? a.id.compareTo(b.id) : overlap;
      });
      if (overlaps(pool.first) > 0 ||
          reserved.contains(_bindingKey(pool.first.binding))) {
        warnings.add(
          'Extras pool capacity requires a shared voice for ${speaker.id}.',
        );
      }
      voices[speaker.id] = automaticVoice(speaker, pool.first);
      allocatedExtras.add(speaker);
    }
    for (final speaker in speakers) {
      final voice = voices[speaker.id]!;
      if (voice.manuallySelected || voice.binding.designed) continue;
      final matches = candidates.where(
        (preset) => _bindingKey(preset.binding) == _bindingKey(voice.binding),
      );
      if (matches.isEmpty) continue;
      final preset = matches.first;
      if ((speaker.gender != 'unknown' && preset.gender != speaker.gender) ||
          (speaker.ageGroup != 'unknown' &&
              preset.ageGroup != speaker.ageGroup) ||
          (speaker.kind == SpeakerKind.narrator && !preset.narratorCandidate)) {
        warnings.add(
          'Approximate voice match for ${speaker.id}; you can change it with cast set.',
        );
      }
    }
    final cast = previous.cast.copyWith(
      speakers: speakers
          .map((speaker) => speaker.copyWith(voiceId: voices[speaker.id]!.id))
          .toList(),
    );
    await store.transaction(() async {
      for (final voice in voices.values) {
        await store.put('voices', voice.id, voice.toJson());
      }
      await CastRepository(store).save(cast);
      await store.put('casting', book.id, {
        'exclusiveCount': exclusiveCount,
        'providers': providers?.toList(),
        'bailianRegion': bailianRegion,
        'exclusiveSpeakerIds': exclusiveIds.toList(),
        'warnings': warnings,
      });
    });
    return CastingResult(
      cast: cast,
      voices: voices,
      exclusiveSpeakerIds: exclusiveIds,
      warnings: warnings,
    );
  }

  Future<Voice> selectPreset(
    Book book,
    String speakerId,
    String presetId,
  ) async {
    final matches = catalog.where(
      (preset) =>
          preset.id == presetId && preset.languages.contains(book.language),
    );
    if (matches.isEmpty) {
      throw StateError('Preset not available for this book language.');
    }
    final options = await store.get('casting', book.id);
    final preset = matches.first;
    if (preset.binding.provider == 'bailian' &&
        !preset.regions.contains(options?['bailianRegion'] ?? 'beijing')) {
      throw StateError('Preset not available in the selected Bailian region.');
    }
    final cast = await CastRepository(store).get(book.id);
    return selectVoice(
      book,
      speakerId,
      _voice(book, cast.speaker(speakerId), preset),
    );
  }

  Future<Voice> selectVoice(Book book, String speakerId, Voice voice) async {
    if (voice.bookId != book.id) {
      throw StateError('Voice belongs to another book.');
    }
    final cast = await CastRepository(store).get(book.id);
    final speaker = cast.speaker(speakerId);
    final selected = voice.copyWith(manuallySelected: true);
    await store.transaction(() async {
      await store.put('voices', selected.id, selected.toJson());
      await CastRepository(store).save(
        cast.copyWith(
          speakers: cast.speakers
              .map(
                (s) =>
                    s.id == speaker.id ? s.copyWith(voiceId: selected.id) : s,
              )
              .toList(),
        ),
      );
    });
    return selected;
  }

  Future<List<Voice>> audition(
    Book book, {
    required String outputDirectory,
    String? speakerId,
    String? text,
  }) async {
    final current = await getCasting(book.id);
    final speakers = speakerId == null
        ? current.cast.speakers
        : [current.cast.speaker(speakerId)];
    final sampleText =
        text ??
        (book.language == 'zh'
            ? '你好，故事即将开始。请跟随我的声音，一起走进书中的世界。'
            : 'Hello. Our story is about to begin. Follow my voice into the world of this book.');
    final samples = <Voice>[];
    for (final speaker in speakers) {
      final voice = current.voices[speaker.id];
      if (voice == null) {
        throw StateError(
          'Select a voice for every speaker before auditioning.',
        );
      }
      final adapter = adapters[voice.binding.provider];
      if (adapter == null) {
        throw ProviderException(
          provider: voice.binding.provider,
          kind: ProviderErrorKind.invalidConfiguration,
        );
      }
      if (sampleText.isEmpty ||
          sampleText.runes.length >
              adapter.capabilitiesFor(voice.binding).maxCharacters) {
        throw const FormatException(
          'Audition text exceeds the provider character limit or is empty.',
        );
      }
      final response = await adapter.synthesize(
        TtsRequest(
          text: sampleText,
          language: book.language,
          binding: voice.binding,
          direction: Direction(speakerId: speaker.id),
        ),
      );
      final file = File(p.join(outputDirectory, '${voice.id}.wav'));
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.audio.toWav(), flush: true);
      final updated = voice.copyWith(samplePath: file.absolute.path);
      await store.put('voices', updated.id, updated.toJson());
      samples.add(updated);
    }
    return samples;
  }

  /// Records chapter appearances, fills missing voices and persists reveal
  /// inheritance, then returns the effective bindings for this chapter.
  Future<Map<String, VoiceBinding>> prepareChapterBindings(
    Book book,
    int chapterNumber, {
    Iterable<String> speakerIds = const [],
  }) async {
    book.chapter(chapterNumber);
    var current = await getCasting(book.id);
    final requested = speakerIds.toSet();
    final canonicalIds = requested
        .map((id) => current.cast.speaker(id).id)
        .toSet();
    if (canonicalIds.isNotEmpty) {
      final cast = current.cast.copyWith(
        speakers: current.cast.speakers
            .map(
              (speaker) =>
                  canonicalIds.contains(speaker.id) &&
                      !speaker.chapters.contains(chapterNumber)
                  ? speaker.copyWith(
                      chapters: [...speaker.chapters, chapterNumber]..sort(),
                    )
                  : speaker,
            )
            .toList(),
      );
      await CastRepository(store).save(cast);
    }
    if (current.cast.speakers.any((speaker) => speaker.voiceId == null)) {
      final options = await store.get('casting', book.id);
      if (options == null) {
        throw StateError('Recommend a cast before synthesis.');
      }
      current = await _recommend(
        book,
        exclusiveCount: options['exclusiveCount'] as int,
        providers: (options['providers'] as List?)?.cast<String>().toSet(),
        bailianRegion: options['bailianRegion'] as String,
        fixedExclusiveIds: current.exclusiveSpeakerIds,
      );
    } else {
      current = await getCasting(book.id);
    }
    final prepared = _inheritRevealedVoices(current, chapterNumber);
    if (!identical(prepared, current)) {
      await store.transaction(() async {
        for (final entry in prepared.voices.entries) {
          if (entry.value.id != current.voices[entry.key]?.id) {
            await store.put('voices', entry.value.id, entry.value.toJson());
          }
        }
        await CastRepository(store).save(prepared.cast);
      });
      current = prepared;
    }
    return _chapterBindings(current, chapterNumber, requested);
  }

  /// Reads effective bindings without recommending or changing the cast.
  Future<Map<String, VoiceBinding>> getChapterBindings(
    Book book,
    int chapterNumber, {
    Iterable<String> speakerIds = const [],
  }) async {
    book.chapter(chapterNumber);
    return _chapterBindings(
      _inheritRevealedVoices(await getCasting(book.id), chapterNumber),
      chapterNumber,
      speakerIds,
    );
  }

  Map<String, VoiceBinding> _chapterBindings(
    CastingResult current,
    int chapterNumber,
    Iterable<String> requested,
  ) {
    final bindings = {
      for (final entry in current.voices.entries)
        entry.key: entry.value.binding,
    };
    for (final persona in current.cast.speakers) {
      if (persona.kind == SpeakerKind.persona &&
          persona.characterId != null &&
          persona.revealChapter != null &&
          chapterNumber >= persona.revealChapter!) {
        final owner = current.cast.speaker(persona.characterId!);
        bindings[persona.id] = current.voices[owner.id]!.binding;
      }
    }
    for (final id in requested) {
      bindings[id] = bindings[current.cast.speaker(id).id]!;
    }
    return bindings;
  }

  Voice _voice(Book book, Speaker speaker, VoicePreset preset) => Voice(
    id: sha256
        .convert(utf8.encode('${book.id}:${speaker.id}'))
        .toString()
        .substring(0, 24),
    bookId: book.id,
    description: speaker.voiceDescription.isEmpty
        ? preset.description
        : speaker.voiceDescription,
    binding: preset.binding,
  );

  static bool _inheritsPersona(Cast cast, Speaker speaker, Voice voice) =>
      cast.speakers.any(
        (persona) =>
            persona.kind == SpeakerKind.persona &&
            persona.characterId == speaker.id &&
            persona.revealChapter != null &&
            (persona.voiceId == voice.id ||
                voice.inheritedFromPersonaId == persona.id) &&
            !speaker.chapters.any(
              (chapter) => chapter < persona.revealChapter!,
            ),
      );

  static String _bindingKey(VoiceBinding binding) =>
      '${binding.provider}:${binding.model}:${binding.voiceId}';

  static int _compareMatch(Speaker speaker, VoicePreset a, VoicePreset b) {
    if (speaker.kind == SpeakerKind.narrator) {
      int narratorRank(VoicePreset preset) =>
          preset.narratorReview == 'approved'
          ? 0
          : preset.narratorCandidate
          ? 1
          : 2;
      final narrator = narratorRank(a).compareTo(narratorRank(b));
      if (narrator != 0) return narrator;
    }
    return _matchScore(speaker, a).compareTo(_matchScore(speaker, b));
  }

  static int _matchScore(Speaker speaker, VoicePreset preset) {
    const ages = ['child', 'teen', 'youngAdult', 'middleAged', 'senior'];
    final gender =
        speaker.gender == 'unknown' || preset.gender == speaker.gender
        ? 0
        : preset.gender == 'unknown'
        ? 300
        : 1000;
    final speakerAge = ages.indexOf(speaker.ageGroup);
    final presetAge = ages.indexOf(preset.ageGroup);
    final age = speakerAge < 0
        ? 0
        : presetAge < 0
        ? 100
        : (speakerAge - presetAge).abs() * 20;
    final profileStyles = voiceStyleTags(
      '${speaker.speakingStyle} ${speaker.voiceDescription}',
    );
    final styles = speaker.kind == SpeakerKind.narrator && profileStyles.isEmpty
        ? ['calm', 'clear']
        : profileStyles;
    final styleMisses = styles.where((style) => !preset.styles.contains(style));
    final incomplete =
        (preset.gender == 'unknown' ? 1 : 0) +
        (presetAge < 0 ? 1 : 0) +
        (preset.description.isEmpty ? 1 : 0) +
        (preset.styles.isEmpty ? 1 : 0);
    // Demographics dominate; style and completeness break close matches.
    return gender + age + styleMisses.length.clamp(0, 5) * 3 + incomplete;
  }
}

// Computes reveal inheritance without changing stored voices or cast snapshots.
CastingResult _inheritRevealedVoices(CastingResult current, int chapterNumber) {
  final personas =
      current.cast.speakers
          .where(
            (speaker) =>
                speaker.kind == SpeakerKind.persona &&
                speaker.characterId != null &&
                speaker.revealChapter != null &&
                chapterNumber >= speaker.revealChapter!,
          )
          .toList()
        ..sort((a, b) => a.revealChapter!.compareTo(b.revealChapter!));
  for (final persona in personas) {
    final owner = current.cast.speaker(persona.characterId!);
    final ownerVoice = current.voices[owner.id]!;
    if (ownerVoice.manuallySelected ||
        ownerVoice.binding.designed ||
        ownerVoice.inheritedFromPersonaId != null ||
        owner.chapters.any((chapter) => chapter < persona.revealChapter!)) {
      continue;
    }
    final personaVoice = current.voices[persona.id]!;
    final inherited = Voice(
      id: sha256
          .convert(
            utf8.encode(
              '${current.cast.bookId}:${owner.id}:inherited:${persona.id}',
            ),
          )
          .toString()
          .substring(0, 24),
      bookId: current.cast.bookId,
      description: personaVoice.description,
      binding: personaVoice.binding,
      samplePath: personaVoice.samplePath,
      inheritedFromPersonaId: persona.id,
    );
    current = CastingResult(
      cast: current.cast.copyWith(
        speakers: current.cast.speakers
            .map(
              (speaker) => speaker.id == owner.id
                  ? speaker.copyWith(voiceId: inherited.id)
                  : speaker,
            )
            .toList(),
      ),
      voices: {...current.voices, owner.id: inherited},
      exclusiveSpeakerIds: current.exclusiveSpeakerIds,
      warnings: current.warnings,
    );
  }
  return current;
}
