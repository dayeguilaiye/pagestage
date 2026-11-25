import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

final _books = [
  MemoryBook(
    title: '阿Q正传',
    chapters: [
      for (var i = 1; i <= 5; i++) MemoryChapter('第$i章', ['正文 $i']),
    ],
  ),
  MemoryBook(
    title: '狂人日记',
    chapters: [
      for (var i = 1; i <= 5; i++) MemoryChapter('第$i章', ['正文 $i']),
    ],
  ),
];

void main() {
  testWidgets('the book heard last carries on from the shelf', (tester) async {
    final fakes = Fakes();
    fakes.listening.bookmarks
      ..['memory-1'] = ListeningBookmark(
        bookId: 'memory-1',
        chapter: 2,
        line: 0,
        progress: 0.2,
        listenedAt: DateTime.utc(2026, 11, 1),
      )
      ..['memory-2'] = ListeningBookmark(
        bookId: 'memory-2',
        chapter: 4,
        line: 0,
        progress: 0.7,
        listenedAt: DateTime.utc(2026, 11, 20),
      );
    reduceMotion(tester);
    await pumpApp(tester, MemoryBookshelf(books: _books), fakes);
    final card = find.byKey(const ValueKey('continueListening'));
    expect(
      find.descendant(of: card, matching: find.text('狂人日记')),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: card, matching: find.byType(PsPlayButton)),
    );
    await tester.pump();
    expect(fakes.listening.opens, [('memory-2', null, null)]);

    // With the book docked in the player, the card steps aside.
    fakes.listening.value = const ListeningState(
      bookId: 'memory-2',
      bookTitle: '狂人日记',
      chapter: 4,
    );
    await tester.pumpAndSettle();
    expect(card, findsNothing);
  });

  testWidgets('the bundled example says it comes voiced', (tester) async {
    final fakes = Fakes()..generation.sampleIds = {'memory-1'};
    reduceMotion(tester);
    await pumpApp(tester, MemoryBookshelf(books: _books), fakes);
    expect(
      find.descendant(
        of: find.widgetWithText(PsShelfItem, '阿Q正传'),
        matching: find.text('示例 · 已配好音'),
      ),
      findsOneWidget,
    );
    expect(find.text('示例 · 已配好音'), findsOneWidget);
  });
}
