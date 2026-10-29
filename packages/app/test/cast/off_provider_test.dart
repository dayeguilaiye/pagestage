import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _bookId = 'memory-1';

final _book = MemoryBook(
  title: '阿Q正传',
  chapters: [
    for (var i = 1; i <= 5; i++) MemoryChapter('第$i章', ['正文 $i']),
  ],
);

const _cast = CastState(
  bookId: _bookId,
  chapterCount: 5,
  profiledThrough: 5,
  status: ProfilingStatus.complete,
  members: [
    CastMember(
      id: 'narrator',
      name: '旁白',
      kind: CastMemberKind.narrator,
      provider: 'minimax',
    ),
    CastMember(
      id: 'zhao',
      name: '赵太爷',
      kind: CastMemberKind.character,
      provider: 'bailian',
    ),
  ],
);

/// MiniMax has its key but is switched off; Bailian is on.
const _minimaxOff = ProviderPreferences(
  hasMinimaxKey: true,
  minimaxOn: false,
  hasBailianKey: true,
);

Future<Fakes> _openBook(WidgetTester tester, Fakes fakes) async {
  reduceMotion(tester);
  await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
  await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
  await tester.pumpAndSettle();
  return fakes;
}

Future<Fakes> _openCast(WidgetTester tester, Fakes fakes) async {
  await _openBook(tester, fakes);
  await tester.tap(find.text('演员表'));
  await tester.pumpAndSettle();
  return fakes;
}

void main() {
  testWidgets('the cast names who uses a switched-off provider', (
    tester,
  ) async {
    final fakes = await _openCast(
      tester,
      Fakes(
        casts: FakeCasts(state: _cast),
        providers: FakeProviders(_minimaxOff),
      ),
    );
    expect(find.text('MiniMax 已关闭'), findsOneWidget);
    expect(
      find.text('旁白用的是 MiniMax 的音色。打开它，或为这些角色换上已开启服务商的音色。'),
      findsOneWidget,
    );
    // Bailian is on, so its speakers need nothing.
    expect(find.text('阿里云百炼已关闭'), findsNothing);

    await tester.tap(find.text('打开 MiniMax'));
    await tester.pumpAndSettle();
    expect(fakes.providers.value.voiceProviders, {'minimax', 'bailian'});
    expect(find.text('MiniMax 已关闭'), findsNothing);
  });

  testWidgets('rematching recasts and resumes paused generation', (
    tester,
  ) async {
    final fakes = await _openCast(
      tester,
      Fakes(
        casts: FakeCasts(state: _cast),
        providers: FakeProviders(_minimaxOff),
        generation: FakeGeneration(
          const GenerationState(
            failures: [
              GenerationFailure(
                bookId: _bookId,
                chapter: 2,
                provider: 'minimax',
                reason: 'providerDisabled',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('重新匹配音色').first);
    await tester.pumpAndSettle();
    expect(fakes.casts.rematches, [_bookId]);
    expect(fakes.generation.resumes, [_bookId]);
  });

  testWidgets('a failed rematch says so', (tester) async {
    final casts = FakeCasts(state: _cast)..rematchFailure = Exception();
    await _openCast(
      tester,
      Fakes(casts: casts, providers: FakeProviders(_minimaxOff)),
    );
    await tester.tap(find.text('重新匹配音色'));
    await tester.pumpAndSettle();
    expect(find.text('没能重新匹配音色，请再试一次'), findsOneWidget);
  });

  testWidgets('without a key the notice opens the provider page', (
    tester,
  ) async {
    await _openCast(
      tester,
      Fakes(
        casts: FakeCasts(state: _cast),
        providers: FakeProviders(const ProviderPreferences(edgeOn: true)),
      ),
    );
    expect(find.text('MiniMax 还没有密钥'), findsOneWidget);
    expect(find.text('阿里云百炼还没有密钥'), findsOneWidget);
    await tester.tap(find.text('填写 MiniMax 的密钥'));
    await tester.pumpAndSettle();
    expect(find.text('粘贴或输入密钥'), findsOneWidget);
  });

  testWidgets('nothing to rematch with while no provider is on', (
    tester,
  ) async {
    await _openCast(tester, Fakes(casts: FakeCasts(state: _cast)));
    expect(find.text('MiniMax 还没有密钥'), findsOneWidget);
    expect(find.text('重新匹配音色'), findsNothing);
  });

  testWidgets(
    'generation paused on a switched-off provider offers both fixes',
    (tester) async {
      final fakes = await _openBook(
        tester,
        Fakes(
          providers: FakeProviders(_minimaxOff),
          generation: FakeGeneration(
            const GenerationState(
              failures: [
                GenerationFailure(
                  bookId: _bookId,
                  chapter: 2,
                  provider: 'minimax',
                  reason: 'providerDisabled',
                ),
                GenerationFailure(
                  bookId: _bookId,
                  chapter: 3,
                  provider: 'bailian',
                  reason: 'quotaExceeded',
                ),
              ],
            ),
          ),
        ),
      );
      expect(
        find.text('配音要用到 MiniMax 的音色。打开它，或为用到它的角色换上已开启服务商的音色。'),
        findsOneWidget,
      );
      // Other pauses keep their own banner.
      expect(find.text('配音生成暂停了'), findsOneWidget);
      expect(find.textContaining('账户额度用完了'), findsOneWidget);

      await tester.tap(find.text('打开 MiniMax'));
      await tester.pumpAndSettle();
      expect(fakes.generation.resumes, [_bookId]);
    },
  );
}
