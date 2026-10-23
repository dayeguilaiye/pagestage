import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'local_store.dart';
import 'casting.dart';
import 'models/script.dart';
import 'models/book.dart';
import 'models/cast.dart';
import 'models/voice.dart';
import 'providers/provider_exception.dart';
import 'providers/tts_adapter.dart';
import 'providers/voice_design_adapter.dart';

class VoiceCandidate {
  const VoiceCandidate({
    required this.voice,
    required this.speakerId,
    required this.previewText,
  });
  String get id => voice.id;
  final Voice voice;
  final String speakerId;
  final String previewText;
  Map<String, Object?> toJson() => {
    'id': id,
    'voice': voice.toJson(),
    'speakerId': speakerId,
    'previewText': previewText,
  };
  factory VoiceCandidate.fromJson(Map<String, Object?> json) => VoiceCandidate(
    voice: Voice.fromJson(Map<String, Object?>.from(json['voice'] as Map)),
    speakerId: json['speakerId'] as String,
    previewText: json['previewText'] as String,
  );
}

/// Generates persistent audition candidates without changing the current cast.
class VoiceDesign {
  VoiceDesign(this.store, {required this.adapters});
  final LocalStore store;
  final Map<String, TtsAdapter> adapters;

  Future<List<VoiceCandidate>> generate(
    Book book,
    String speakerId, {
    required String provider,
    required String model,
    required String description,
    required String previewText,
    required String outputDirectory,
    int count = 3,
  }) async {
    if (count < 3 ||
        description.trim().isEmpty ||
        previewText.trim().isEmpty ||
        model.trim().isEmpty) {
      throw const FormatException(
        'Provide a description, preview, model and at least three candidates.',
      );
    }
    final cast = await CastRepository(store).get(book.id);
    final speaker = cast.speaker(speakerId);
    final adapter = adapters[provider];
    final binding = VoiceBinding(
      provider: provider,
      model: model,
      voiceId: '',
      designed: true,
    );
    if (adapter is! VoiceDesignAdapter ||
        adapter == null ||
        !adapter.capabilitiesFor(binding).supportsVoiceDesign) {
      throw ProviderException(
        provider: provider,
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    final directory = Directory(outputDirectory).absolute;
    await directory.create(recursive: true);
    final result = <VoiceCandidate>[];
    final random = Random.secure();
    for (var i = 0; i < count; i++) {
      final designed = await (adapter as VoiceDesignAdapter).design(
        VoiceDesignRequest(
          description: description,
          previewText: previewText,
          language: book.language,
          model: model,
        ),
      );
      if (designed.binding.provider != provider ||
          !designed.binding.designed ||
          designed.binding.model != model ||
          designed.binding.voiceId.trim().isEmpty ||
          result.any(
            (c) => c.voice.binding.voiceId == designed.binding.voiceId,
          )) {
        throw ProviderException(
          provider: provider,
          kind: ProviderErrorKind.invalidResponse,
        );
      }
      final id =
          'design-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      final file = File(
        p.join(directory.path, '$id.${designed.preview.extension}'),
      );
      await file.writeAsBytes(designed.preview.bytes, flush: true);
      final candidate = VoiceCandidate(
        speakerId: speaker.id,
        previewText: previewText,
        voice: Voice(
          id: id,
          bookId: book.id,
          description: description,
          binding: designed.binding,
          samplePath: file.path,
        ),
      );
      await store.put('voiceCandidates', id, candidate.toJson());
      result.add(candidate);
    }
    return result;
  }

  Future<VoiceCandidate> get(String candidateId) async {
    final json = await store.get('voiceCandidates', candidateId);
    if (json == null) throw StateError('Voice candidate not found.');
    return VoiceCandidate.fromJson(json);
  }

  Future<Voice> select(Book book, String speakerId, String candidateId) async {
    final candidate = await get(candidateId);
    final cast = await CastRepository(store).get(book.id);
    final speaker = cast.speaker(speakerId);
    if (candidate.voice.bookId != book.id ||
        cast.findSpeaker(candidate.speakerId)?.id != speaker.id) {
      throw StateError('Candidate belongs to another book or speaker.');
    }
    if (candidate.voice.binding.provider != 'minimax') {
      VoicePreview.detect(
        await File(candidate.voice.samplePath!).readAsBytes(),
      );
      return Casting(store).selectVoice(book, speaker.id, candidate.voice);
    }
    final adapter = adapters[candidate.voice.binding.provider];
    if (adapter == null) {
      throw ProviderException(
        provider: candidate.voice.binding.provider,
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    // This synthesis activates MiniMax designs. It must precede durable selection.
    final audio = await adapter.synthesize(
      TtsRequest(
        text: candidate.previewText,
        language: book.language,
        binding: candidate.voice.binding,
        direction: Direction(speakerId: speaker.id),
      ),
    );
    if (audio.audio.samples.isEmpty) {
      throw ProviderException(
        provider: adapter.provider,
        kind: ProviderErrorKind.invalidResponse,
      );
    }
    final path = p.setExtension(candidate.voice.samplePath!, '.selected.wav');
    await File(path).writeAsBytes(audio.audio.toWav(), flush: true);
    return Casting(
      store,
    ).selectVoice(book, speaker.id, candidate.voice.copyWith(samplePath: path));
  }

  Future<List<VoiceCandidate>> list(String bookId, {String? speakerId}) async {
    final cast = await CastRepository(store).get(bookId);
    final target = speakerId == null ? null : cast.speaker(speakerId).id;
    return (await store.list('voiceCandidates'))
        .map(VoiceCandidate.fromJson)
        .where(
          (c) =>
              c.voice.bookId == bookId &&
              (target == null || cast.findSpeaker(c.speakerId)?.id == target),
        )
        .toList();
  }
}
