import 'delivery.dart';
import 'local_store.dart';
import 'synthesizer.dart';

/// How one book is performed: the reader's choices for all of its chapters.
class Performance {
  const Performance({
    this.mode = PerformanceMode.audiobook,
    this.expressiveness = Expressiveness.natural,
  });
  final PerformanceMode mode;
  final Expressiveness expressiveness;

  Performance copyWith({
    PerformanceMode? mode,
    Expressiveness? expressiveness,
  }) => Performance(
    mode: mode ?? this.mode,
    expressiveness: expressiveness ?? this.expressiveness,
  );
}

class PerformanceRepository {
  PerformanceRepository(this.store);
  final LocalStore store;

  Future<Performance> get(String bookId) async {
    final json = await store.get('performance', bookId);
    return Performance(
      mode: PerformanceMode.values.byName(
        json?['mode'] as String? ?? 'audiobook',
      ),
      expressiveness: Expressiveness.values.byName(
        json?['expressiveness'] as String? ?? 'natural',
      ),
    );
  }

  Future<void> save(String bookId, Performance performance) =>
      store.put('performance', bookId, {
        'bookId': bookId,
        'mode': performance.mode.name,
        'expressiveness': performance.expressiveness.name,
      });
}
