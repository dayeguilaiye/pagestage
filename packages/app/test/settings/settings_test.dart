import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

Future<Fakes> _openSettings(
  WidgetTester tester, {
  ProviderPreferences preferences = const ProviderPreferences(
    profileModel: 'gpt-profile',
    hasLlmKey: true,
    hasMinimaxKey: true,
    hasBailianKey: false,
  ),
  Locale locale = const Locale('zh', 'CN'),
}) async {
  final fakes = Fakes(providers: FakeProviders(preferences));
  await pumpApp(tester, MemoryBookshelf(), fakes, locale: locale);
  await tester.tap(
    find.byTooltip(locale.languageCode == 'zh' ? '设置' : 'Settings'),
  );
  await tester.pumpAndSettle();
  return fakes;
}

const _keys = {
  '接口地址': 'baseUrl',
  '建档模型': 'profileModel',
  '导演模型': 'directorModel',
  '大模型密钥': 'key-llm',
  'MiniMax 密钥': 'key-minimax',
  '百炼密钥': 'key-bailian',
};

Finder _field(String label) => find.byKey(ValueKey(_keys[label]!));

final _list = find.byType(Scrollable).first;

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 120, scrollable: _list);
  await tester.pumpAndSettle();
}

/// Scrolls the field in [label] into view and types [text] into it.
Future<void> _enter(WidgetTester tester, String label, String text) async {
  await _reveal(tester, _field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  final button = find.text('保存');
  await _reveal(tester, button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('untouched stored keys are kept when other settings change', (
    tester,
  ) async {
    final fakes = await _openSettings(tester);

    await _enter(tester, '导演模型', 'gpt-director');
    await _save(tester);

    final save = fakes.providers.saves.single;
    expect(save.preferences.directorModel, 'gpt-director');
    expect(save.preferences.profileModel, 'gpt-profile');
    expect(save.llmKey, isNull);
    expect(save.minimaxKey, isNull);
    expect(save.bailianKey, isNull);
    expect(fakes.providers.value.hasLlmKey, isTrue);
    expect(fakes.providers.value.hasMinimaxKey, isTrue);
    expect(find.text('设置已保存'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a typed key replaces and an explicit removal deletes', (
    tester,
  ) async {
    final fakes = await _openSettings(tester);

    await _reveal(tester, _field('MiniMax 密钥'));
    final remove = find.text('删除密钥').last;
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('将删除'), findsOneWidget);

    await _enter(tester, '百炼密钥', '  sk-new  ');
    await _reveal(tester, find.text('新加坡'));
    await tester.tap(find.text('新加坡'));
    await _save(tester);

    final save = fakes.providers.saves.single;
    expect(save.bailianKey, 'sk-new');
    expect(save.minimaxKey, '');
    expect(save.llmKey, isNull);
    expect(save.preferences.region, ProviderRegion.singapore);
    // Typed keys do not stay in the field after saving.
    final field = tester.widget<TextField>(_field('百炼密钥'));
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('clearing a typed key is not a deletion', (tester) async {
    final fakes = await _openSettings(tester);
    await _enter(tester, '大模型密钥', 'sk-oops');
    await _enter(tester, '大模型密钥', '');
    await _enter(tester, '建档模型', 'gpt-new');
    await _save(tester);
    expect(fakes.providers.saves.single.llmKey, isNull);
  });

  testWidgets('keys are masked until shown', (tester) async {
    await _openSettings(tester);
    await _enter(tester, '大模型密钥', 'sk-secret');
    EditableText editable() => tester.widget<EditableText>(
      find.descendant(of: _field('大模型密钥'), matching: find.byType(EditableText)),
    );
    expect(editable().obscureText, isTrue);

    // Out from under the bar.
    await tester.drag(_list, const Offset(0, 200));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: _field('大模型密钥'), matching: find.text('显示')),
    );
    await tester.pump();
    expect(editable().obscureText, isFalse);
  });

  testWidgets('protocol and an invalid address', (tester) async {
    final fakes = await _openSettings(tester);
    await tester.tap(find.text('Responses'));
    await _enter(tester, '接口地址', 'api.example.com');
    await _save(tester);
    await _reveal(tester, _field('接口地址'));
    expect(find.text('请输入以 https:// 或 http:// 开头的地址'), findsOneWidget);
    expect(fakes.providers.saves, isEmpty);

    await _enter(tester, '接口地址', 'https://api.example.com/v1');
    await _save(tester);
    final save = fakes.providers.saves.single;
    expect(save.preferences.protocol, LlmProtocol.responses);
    expect(save.preferences.baseUrl, 'https://api.example.com/v1');
  });

  testWidgets('a failed save is explained without the raw error', (
    tester,
  ) async {
    final fakes = await _openSettings(tester);
    fakes.providers.failWith = Exception('401 for key sk-leaked');
    await _enter(tester, '大模型密钥', 'sk-leaked');
    await _save(tester);

    expect(find.text('没能保存设置'), findsOneWidget);
    expect(find.textContaining('401'), findsNothing);
    // The key stays in its masked field so the reader can retry.
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: _field('大模型密钥'),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText,
      isTrue,
    );
  });

  testWidgets('the exclusive voice count steps and stops at zero', (
    tester,
  ) async {
    final fakes = await _openSettings(tester);
    expect(fakes.casts.exclusiveCount, 20);
    await fakes.casts.setExclusiveCount(1);
    final fewer = find.byTooltip('减少');
    await _reveal(tester, fewer);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byTooltip('增加'));
    await tester.pumpAndSettle();
    expect(fakes.casts.exclusiveCount, 2);
    await tester.tap(fewer);
    await tester.pumpAndSettle();
    await tester.tap(fewer);
    await tester.pumpAndSettle();
    expect(fakes.casts.exclusiveCount, 0);
    await tester.tap(fewer);
    await tester.pumpAndSettle();
    expect(fakes.casts.exclusiveCount, 0);
  });

  testWidgets('settings read in English', (tester) async {
    await _openSettings(tester, locale: const Locale('en'));
    expect(find.text('Language model'), findsWidgets);
    expect(find.text('Directing model'), findsOneWidget);
    await _reveal(tester, find.text('Exclusive voices'));
    expect(find.text('Exclusive voices'), findsOneWidget);
  });
}
