import 'package:pagestage_core/pagestage_core.dart';

class FakeRequestClock {
  Duration now = Duration.zero;
  final waits = <Duration>[];
  final events = <String>[];
  late final runtime = RequestRuntime(
    elapsed: () => now,
    sleep: (delay) async {
      waits.add(delay);
      now += delay;
    },
    onEvent: events.add,
  );
}
