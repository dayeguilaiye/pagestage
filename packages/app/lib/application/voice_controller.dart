import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pagestage_core/pagestage_core.dart';

import 'cast_controller.dart';
import 'contracts.dart';
import 'listening_controller.dart';
import 'provider_gateway.dart';

class VoiceController extends ChangeNotifier implements Voices {
  VoiceController._(this.store, this.casts, this.listening);
  final LocalStore store;
  final CastController casts;
  final ListeningController listening;
  ProviderGateway get gateway => casts.gateway;
  final _notices = <VoiceRebuildNotice>[];
  @override
  List<VoiceRebuildNotice> get notices => List.unmodifiable(_notices);
  @override
  String? get auditioning => _auditioning;
  String? _auditioning;
  int _auditionEpoch = 0;
  bool _closed = false;
  Future<void> _operations = Future.value();
  late final StreamSubscription<Object?> _events;

  static Future<VoiceController> open(
    LocalStore store,
    CastController casts,
    ListeningController listening,
  ) async {
    final service = VoiceController._(store, casts, listening);
    for (final row in await store.list('voiceRebuilds')) {
      service._notices.add(
        VoiceRebuildNotice(
          id: row['id'] as String,
          bookId: row['bookId'] as String,
          speakerId: row['speakerId'] as String,
          speakerName: row['speakerName'] as String,
          provider: row['provider'] as String,
        ),
      );
    }
    service._events = casts.auditionEngine.states.listen((state) {
      if (state.completed || state.error != null) {
        service._auditioning = null;
        service._notify();
      }
    });
    service.gateway.rebuild = service._rebuild;
    listening.generation?.gateway = service.gateway;
    casts.beforeAudition = service.stopAudition;
    casts.onCastingChanged = listening.invalidate;
    return service;
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  Future<T> _operation<T>(Future<T> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> get idle => _operations;

  @override
  Future<List<VoiceOption>> presets(String bookId, String speakerId) async {
    final book = await Library(store).getBook(bookId);
    final current = await Casting(store).getCasting(bookId);
    final selected =
        current.voices[current.cast.speaker(speakerId).id]?.binding;
    return [
      for (final p in defaultVoiceCatalog)
        if (p.languages.contains(book.language) &&
            (p.binding.provider != 'bailian' ||
                p.regions.contains(gateway.providers.value.region.name)))
          VoiceOption(
            id: p.id,
            name: p.binding.voiceId,
            provider: p.binding.provider,
            description: p.description,
            selected:
                selected?.provider == p.binding.provider &&
                selected?.voiceId == p.binding.voiceId,
          ),
    ];
  }

  Future<VoicePreset> _preset(
    String bookId,
    String speakerId,
    String id,
  ) async {
    if (!(await presets(bookId, speakerId)).any((v) => v.id == id)) {
      throw StateError('Unavailable preset.');
    }
    return defaultVoiceCatalog.singleWhere((p) => p.id == id);
  }

  @override
  Future<void> auditionPreset(
    String bookId,
    String speakerId,
    String presetId,
  ) {
    final epoch = ++_auditionEpoch;
    return _operation(() async {
      final preset = await _preset(bookId, speakerId, presetId);
      final book = await Library(store).getBook(bookId);
      final key = sha256
          .convert(utf8.encode(jsonEncode(preset.binding.toJson())))
          .toString();
      final file = File(
        '${AudioRepository(store).bookDirectory(bookId).path}/previews/$key.wav',
      );
      if (!await _validPreview(file.path)) {
        final result = await gateway
            .tts(() => bookId, content: 'voiceSample')[preset.binding.provider]!
            .synthesize(
              TtsRequest(
                text: _preview(book.language),
                language: book.language,
                binding: preset.binding,
                direction: Direction(speakerId: speakerId),
              ),
            );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(result.audio.toWav(), flush: true);
      }
      await _play(bookId, presetId, file.path, epoch);
    });
  }

  Future<T> _change<T>(String bookId, Future<T> Function() change) =>
      casts.scheduler.withBookPaused(bookId, () async {
        await listening.invalidate(bookId);
        await stopAudition();
        await casts.stopAudition();
        final result = await change();
        _notify();
        return result;
      });

  @override
  Future<void> selectPreset(String bookId, String speakerId, String presetId) =>
      _operation(() async {
        final preset = await _preset(bookId, speakerId, presetId);
        await _change(bookId, () async {
          final book = await Library(store).getBook(bookId);
          final cast = await CastRepository(store).get(bookId);
          final speaker = cast.speaker(speakerId);
          final voiceId = sha256
              .convert(utf8.encode('$bookId:${speaker.id}:$presetId'))
              .toString()
              .substring(0, 24);
          await Casting(store).selectVoice(
            book,
            speaker.id,
            Voice(
              id: voiceId,
              bookId: bookId,
              description: speaker.voiceDescription.isEmpty
                  ? preset.description
                  : speaker.voiceDescription,
              binding: preset.binding,
            ),
          );
        });
      });

  @override
  Future<List<String>> designProviders(String bookId) async {
    await Library(store).getBook(bookId);
    final preferences = gateway.providers.value;
    return [
      if (preferences.hasMinimaxKey) 'minimax',
      if (preferences.hasBailianKey &&
          preferences.region == ProviderRegion.beijing)
        'bailian',
    ];
  }

  VoiceDesign _design(String bookId) => VoiceDesign(
    store,
    adapters: gateway.tts(() => bookId, content: 'voiceSample'),
  );
  VoiceOption _option(VoiceCandidate c, String? selectedId) => VoiceOption(
    id: c.id,
    name: c.voice.binding.voiceId,
    provider: c.voice.binding.provider,
    description: c.voice.description,
    selected: c.id == selectedId,
  );
  @override
  Future<List<VoiceOption>> candidates(String bookId, String speakerId) async {
    final cast = await CastRepository(store).get(bookId);
    final selected = cast.speaker(speakerId).voiceId;
    return [
      for (final c in await _design(bookId).list(bookId, speakerId: speakerId))
        if (await _validPreview(c.voice.samplePath)) _option(c, selected),
    ];
  }

  @override
  Future<List<VoiceOption>> design(
    String bookId,
    String speakerId, {
    required String provider,
    required String description,
  }) => _operation(() async {
    if (!(await designProviders(bookId)).contains(provider) ||
        description.trim().isEmpty) {
      throw ProviderException(
        provider: provider,
        kind: ProviderErrorKind.invalidConfiguration,
      );
    }
    final book = await Library(store).getBook(bookId);
    final result = await casts.scheduler.withBookPaused(
      bookId,
      () => _design(bookId).generate(
        book,
        speakerId,
        provider: provider,
        model: provider == 'minimax'
            ? 'speech-2.8-hd'
            : 'qwen-audio-3.1-tts-flash',
        description: description.trim(),
        previewText: _preview(book.language),
        outputDirectory:
            '${AudioRepository(store).bookDirectory(bookId).path}/designs',
      ),
    );
    if (await store.get('books', bookId) == null) {
      await Library(store).deleteBook(bookId);
      return [];
    }
    _notify();
    return [for (final c in result) _option(c, null)];
  });
  @override
  Future<void> auditionCandidate(
    String bookId,
    String speakerId,
    String candidateId,
  ) {
    final epoch = ++_auditionEpoch;
    return _operation(() async {
      final candidates = await _design(
        bookId,
      ).list(bookId, speakerId: speakerId);
      final candidate = candidates.singleWhere((c) => c.id == candidateId);
      await _play(bookId, candidateId, candidate.voice.samplePath!, epoch);
    });
  }

  @override
  Future<void> selectCandidate(
    String bookId,
    String speakerId,
    String candidateId,
  ) => _operation(() async {
    await _change(bookId, () async {
      final book = await Library(store).getBook(bookId);
      await _design(bookId).select(book, speakerId, candidateId);
    });
  });

  Future<void> _play(String bookId, String id, String path, int epoch) async {
    if (await store.get('books', bookId) == null) {
      await Library(store).deleteBook(bookId);
      return;
    }
    if (_closed || epoch != _auditionEpoch) return;
    await listening.pause();
    await casts.stopAudition();
    await casts.auditionEngine.load(path, Duration.zero);
    await casts.auditionEngine.setSpeed(1);
    if (_closed || epoch != _auditionEpoch) return;
    _auditioning = id;
    await casts.auditionEngine.play();
    _notify();
  }

  @override
  Future<void> stopAudition() async {
    _auditionEpoch++;
    _auditioning = null;
    await casts.auditionEngine.pause();
    _notify();
  }

  @override
  Future<void> dismissNotice(String id) async {
    await store.delete('voiceRebuilds', id);
    _notices.removeWhere((n) => n.id == id);
    _notify();
  }

  /// Called at a failed scheduler checkpoint. The queue reruns synthesis with
  /// new input hashes; unchanged utterances are recovered from their own cache.
  Future<bool> _rebuild(ScheduledTask task, VoiceBinding binding) async {
    final book = await Library(store).getBook(task.bookId);
    final current = await Casting(store).getCasting(book.id);
    final affected = current.voices.entries
        .where(
          (e) =>
              e.value.binding.provider == binding.provider &&
              e.value.binding.voiceId == binding.voiceId,
        )
        .toList();
    if (affected.isEmpty) return false;
    if (!(await designProviders(book.id)).contains(binding.provider)) {
      return false;
    }
    final voice = affected.first.value;
    final adapter =
        gateway.tts(() => book.id, content: 'voiceSample')[binding.provider]!
            as VoiceDesignAdapter;
    final designed = await adapter.design(
      VoiceDesignRequest(
        description: voice.description,
        previewText: _preview(book.language),
        language: book.language,
        model: binding.model,
      ),
    );
    final sample = await gateway
        .tts(() => book.id, content: 'voiceSample')[binding.provider]!
        .synthesize(
          TtsRequest(
            text: _preview(book.language),
            language: book.language,
            binding: designed.binding,
            direction: Direction(speakerId: affected.first.key),
          ),
        );
    final file = File(
      '${AudioRepository(store).bookDirectory(book.id).path}/designs/rebuilt-${voice.id}-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await file.parent.create(recursive: true);
    await file.writeAsBytes(sample.audio.toWav(), flush: true);
    for (final entry in affected) {
      final updated = entry.value.copyWith(
        binding: designed.binding,
        samplePath: file.path,
      );
      await store.put('voices', updated.id, updated.toJson());
      final id = '${updated.id}:${designed.binding.voiceId}';
      final speaker = current.cast.speaker(entry.key);
      final notice = VoiceRebuildNotice(
        id: id,
        bookId: book.id,
        speakerId: speaker.id,
        speakerName: speaker.name,
        provider: binding.provider,
      );
      await store.put('voiceRebuilds', id, {
        'id': id,
        'bookId': book.id,
        'speakerId': speaker.id,
        'speakerName': speaker.name,
        'provider': binding.provider,
      });
      _notices.add(notice);
    }
    _notify();
    return true;
  }

  static String _preview(String language) => language == 'zh'
      ? '你好，故事即将开始。请跟随我的声音，一起走进书中的世界。'
      : 'Hello. Our story is about to begin. Follow my voice into the world of this book.';
  static Future<bool> _validPreview(String? path) async {
    if (path == null) return false;
    try {
      VoicePreview.detect(await File(path).readAsBytes());
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async {
    _closed = true;
    await stopAudition();
    await _operations;
    await _events.cancel();
    gateway.rebuild = null;
    casts.beforeAudition = null;
    casts.onCastingChanged = null;
    dispose();
  }
}
