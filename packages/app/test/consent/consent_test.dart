import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/consent/consent_gate.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _request = ConsentRequest(
  id: 7,
  bookTitle: '阿Q正传',
  provider: 'llm',
  endpoint: 'https://api.example.com/v1',
  content: 'chapterTextAndCast',
);

Future<Fakes> _pump(WidgetTester tester) async {
  final fakes = Fakes();
  await pumpApp(tester, MemoryBookshelf(), fakes);
  return fakes;
}

void main() {
  testWidgets('a request explains what goes where', (tester) async {
    final fakes = await _pump(tester);
    fakes.consents.value = _request;
    await tester.pumpAndSettle();

    expect(find.text('把《阿Q正传》的内容发出去？'), findsOneWidget);
    expect(find.text('大模型'), findsOneWidget);
    expect(find.text('https://api.example.com/v1'), findsOneWidget);
    expect(find.text('章节正文与演员表'), findsOneWidget);
  });

  testWidgets('cancelling answers no', (tester) async {
    final fakes = await _pump(tester);
    fakes.consents.value = _request;
    await tester.pumpAndSettle();

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(fakes.consents.responses, [(7, false)]);
    expect(find.byType(ConsentDialog), findsNothing);
  });

  testWidgets('dismissing answers no', (tester) async {
    final fakes = await _pump(tester);
    fakes.consents.value = _request;
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(fakes.consents.responses, [(7, false)]);
  });

  testWidgets('accepting answers yes', (tester) async {
    final fakes = await _pump(tester);
    fakes.consents.value = _request;
    await tester.pumpAndSettle();

    await tester.tap(find.text('同意并发送'));
    await tester.pumpAndSettle();
    expect(fakes.consents.responses, [(7, true)]);
  });

  testWidgets('repeated notifications open one dialog', (tester) async {
    final fakes = await _pump(tester);
    fakes.consents.value = _request;
    await tester.pump();
    fakes.consents.value = const ConsentRequest(
      id: 7,
      bookTitle: '阿Q正传',
      provider: 'llm',
      endpoint: 'https://api.example.com/v1',
      content: 'chapterTextAndCast',
    );
    fakes.consents.notifyListeners();
    await tester.pumpAndSettle();
    expect(find.byType(ConsentDialog), findsOneWidget);

    await tester.tap(find.text('同意并发送'));
    await tester.pumpAndSettle();
    expect(fakes.consents.responses, [(7, true)]);
    expect(find.byType(ConsentDialog), findsNothing);
  });

  testWidgets('a withdrawn request closes without an answer, the next opens', (
    tester,
  ) async {
    final fakes = await _pump(tester);
    fakes.consents.value = _request;
    await tester.pumpAndSettle();

    fakes.consents.value = const ConsentRequest(
      id: 8,
      bookTitle: '阿Q正传',
      provider: 'minimax',
      endpoint: 'https://api.minimax.io/v1',
      content: 'voiceSample',
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConsentDialog), findsOneWidget);
    expect(find.text('声音样本文本'), findsOneWidget);
    expect(fakes.consents.responses, isEmpty);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(fakes.consents.responses, [(8, false)]);
  });
}
