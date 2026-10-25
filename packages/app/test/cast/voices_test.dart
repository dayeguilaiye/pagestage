import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/cast/voice_page.dart';
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

const _zhao = CastMember(
  id: 'zhao',
  name: '赵太爷',
  kind: CastMemberKind.character,
  voiceDescription: '老年男声，傲慢',
  voiceName: '老年男声',
  provider: 'minimax',
);

const _presets = [
  VoiceOption(id: 'p1', name: '沉稳大叔', provider: 'minimax', description: '低沉'),
  VoiceOption(id: 'p2', name: '老年男声', provider: 'minimax', selected: true),
  VoiceOption(id: 'p3', name: '北京大爷', provider: 'bailian'),
];

Future<Fakes> _openCast(WidgetTester tester, FakeVoices voices) async {
  final fakes = Fakes(
    voices: voices,
    casts: FakeCasts(
      state: const CastState(
        bookId: _bookId,
        chapterCount: 5,
        profiledThrough: 5,
        status: ProfilingStatus.complete,
        members: [_zhao],
      ),
    ),
  );
  reduceMotion(tester);
  await pumpApp(tester, MemoryBookshelf(books: [_book]), fakes);
  await tester.tap(find.widgetWithText(PsShelfItem, '阿Q正传'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('演员表'));
  await tester.pumpAndSettle();
  return fakes;
}

Future<void> _expand(WidgetTester tester) async {
  await tester.ensureVisible(find.text('赵太爷'));
  await tester.tap(find.text('赵太爷'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _choose(String id) => find.descendant(
  of: find.byKey(ValueKey('voice-$id')),
  matching: find.widgetWithText(PsButton, '选用'),
);

void main() {
  testWidgets('a preset is heard before it can be chosen', (tester) async {
    final voices = FakeVoices(presetOptions: _presets);
    await _openCast(tester, voices);
    await _expand(tester);
    expect(find.text('设计音色'), findsNothing);
    await _tapVisible(tester, find.text('换音色'));

    expect(find.text('沉稳大叔'), findsOneWidget);
    expect(find.text('MiniMax · 低沉'), findsOneWidget);
    expect(find.text('使用中'), findsOneWidget);
    expect(tester.widget<PsButton>(_choose('p1')).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('voice-p1')));
    await tester.pumpAndSettle();
    expect(voices.presetAuditions, ['p1']);
    expect(find.text('停止试听'), findsNothing); // tooltip only
    expect(tester.widget<PsButton>(_choose('p1')).onPressed, isNotNull);
    // Unheard options stay locked.
    expect(tester.widget<PsButton>(_choose('p3')).onPressed, isNull);

    await tester.tap(_choose('p1'));
    await tester.pumpAndSettle();
    expect(voices.selectedPresets, [(_bookId, 'zhao', 'p1')]);
    expect(find.byType(VoicePage), findsNothing);
    expect(find.text('已为赵太爷换上新声音'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('playing a preset again stops it; leaving stops any sample', (
    tester,
  ) async {
    final voices = FakeVoices(presetOptions: _presets);
    await _openCast(tester, voices);
    await _expand(tester);
    await _tapVisible(tester, find.text('换音色'));

    await tester.tap(find.byKey(const ValueKey('voice-p3')));
    await tester.pumpAndSettle();
    expect(voices.auditioning, 'p3');
    await tester.tap(find.byKey(const ValueKey('voice-p3')));
    await tester.pumpAndSettle();
    expect(voices.auditioning, isNull);
    expect(voices.stops, 1);

    await tester.tap(find.byKey(const ValueKey('voice-p1')));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(voices.stops, 2);
    expect(voices.selectedPresets, isEmpty);
  });

  testWidgets('without a design provider there is no voice design', (
    tester,
  ) async {
    final voices = FakeVoices(presetOptions: _presets);
    await _openCast(tester, voices);
    await _expand(tester);
    expect(find.text('换音色'), findsOneWidget);
    expect(find.text('设计音色'), findsNothing);
    await _tapVisible(tester, find.text('换音色'));
    expect(find.text('音色设计'), findsNothing);
  });

  testWidgets('a designed voice starts from the description and is chosen', (
    tester,
  ) async {
    final voices = FakeVoices(providers: ['minimax', 'bailian']);
    await _openCast(tester, voices);
    await _expand(tester);
    await _tapVisible(tester, find.text('设计音色'));

    final field = find.byKey(const ValueKey('voiceDescription'));
    expect(tester.widget<TextField>(field).controller!.text, '老年男声，傲慢');
    await tester.tap(find.text('阿里云百炼'));
    await tester.enterText(field, '老年男声，傲慢，带点江南口音');
    await _tapVisible(tester, find.text('生成 3 个候选'));
    expect(voices.designs, [('bailian', '老年男声，傲慢，带点江南口音')]);
    expect(find.text('候选 1'), findsOneWidget);
    expect(find.text('候选 3'), findsOneWidget);

    await _tapVisible(tester, find.byKey(const ValueKey('voice-c2')));
    expect(voices.candidateAuditions, ['c2']);
    await tester.tap(_choose('c2'));
    await tester.pumpAndSettle();
    expect(voices.selectedCandidates, [(_bookId, 'zhao', 'c2')]);
    expect(find.byType(VoicePage), findsNothing);
  });

  testWidgets('a failed design can be retried and earlier candidates return', (
    tester,
  ) async {
    final voices = FakeVoices(
      providers: ['minimax'],
      savedCandidates: const [
        VoiceOption(id: 'old', name: '上次的候选', provider: 'minimax'),
      ],
    )..designFailure = Exception('500 upstream');
    await _openCast(tester, voices);
    await _expand(tester);
    await _tapVisible(tester, find.text('设计音色'));
    // Restored from last time.
    expect(find.text('上次的候选'), findsOneWidget);

    await _tapVisible(tester, find.text('重新生成候选'));
    expect(find.text('没能设计出声音'), findsOneWidget);
    expect(find.textContaining('500'), findsNothing);
    expect(find.text('上次的候选'), findsOneWidget);

    voices.designFailure = null;
    await _tapVisible(tester, find.text('重试'));
    expect(voices.designs, hasLength(2));
    expect(find.text('没能设计出声音'), findsNothing);
    expect(find.text('候选 1'), findsOneWidget);
  });

  testWidgets('a rebuilt voice asks for a fresh listen and can be dismissed', (
    tester,
  ) async {
    final voices = FakeVoices(
      notices: const [
        VoiceRebuildNotice(
          id: 'n1',
          bookId: _bookId,
          speakerId: 'zhao',
          speakerName: '赵太爷',
          provider: 'bailian',
        ),
        VoiceRebuildNotice(
          id: 'n2',
          bookId: 'other-book',
          speakerId: 'x',
          speakerName: '别的书',
          provider: 'minimax',
        ),
      ],
    );
    final fakes = await _openCast(tester, voices);
    expect(find.text('赵太爷的声音重建了'), findsOneWidget);
    expect(find.text('别的书的声音重建了'), findsNothing);

    await tester.tap(find.text('重新试听'));
    await tester.pumpAndSettle();
    expect(fakes.casts.auditions, [(_bookId, 'zhao')]);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('notice-n1')),
        matching: find.byTooltip('关闭'),
      ),
    );
    await tester.pumpAndSettle();
    expect(voices.dismissed, ['n1']);
    expect(find.text('赵太爷的声音重建了'), findsNothing);
  });
}
