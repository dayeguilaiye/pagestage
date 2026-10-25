import 'package:flutter/foundation.dart';
import 'package:pagestage_core/pagestage_core.dart';

import 'cast_controller.dart';
import 'contracts.dart';
import 'listening_controller.dart';
import 'voice_controller.dart';

class AudioStorageController extends ChangeNotifier implements AudioStorage {
  AudioStorageController(this.store, this.casts, this.listening, this.voices) {
    store.addListener(_notify);
  }
  final LocalStore store;
  final CastController casts;
  final ListeningController listening;
  final VoiceController voices;
  void _notify() => notifyListeners();
  @override
  Future<List<BookStorageUsage>> usage() async => [
    for (final size in await BookStorage(store).usage())
      BookStorageUsage(
        bookId: size.bookId,
        title: size.title,
        totalBytes: size.totalBytes,
        audioBytes: size.audioBytes,
      ),
  ];
  @override
  Future<void> clearAudio(String bookId) async {
    await listening.invalidate(bookId);
    await voices.idle;
    await voices.stopAudition();
    await casts.stopAudition();
    await casts.idleAuditions;
    await casts.scheduler.withBookPaused(bookId, () async {
      await casts.scheduler.cancelGeneration(bookId);
      await BookStorage(store).clearAudio(bookId);
    });
    _notify();
  }

  @override
  void dispose() {
    store.removeListener(_notify);
    super.dispose();
  }
}
