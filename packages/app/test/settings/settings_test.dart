import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/contracts.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/settings/settings_page.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

const _mb = 1024 * 1024;

const _ready = ProviderPreferences(
  baseUrl: 'https://api.deepseek.com/v1',
  profileModel: 'deepseek-chat',
  hasLlmKey: true,
);

/// Opens settings from the shelf.
Future<Fakes> _open(WidgetTester tester, [Fakes? fakes]) async {
  fakes ??= Fakes();
  reduceMotion(tester);
  await pumpApp(tester, MemoryBookshelf(), fakes);
  await tester.tap(find.byTooltip('设置'));
  await tester.pumpAndSettle();
  return fakes;
}

/// Scrolls the page on top until [finder] is on screen.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _inDialog(String text) =>
    find.descendant(of: find.byType(PsDialog), matching: find.text(text));

Switch _switch(WidgetTester tester, String provider) =>
    tester.widget<Switch>(find.byKey(ValueKey('switch-$provider')));

extension on ProviderPreferences {
  ProviderPreferences withKeys({bool minimax = false, bool bailian = false}) =>
      ProviderPreferences(
        baseUrl: baseUrl,
        profileModel: profileModel,
        hasLlmKey: hasLlmKey,
        hasMinimaxKey: minimax,
        hasBailianKey: bailian,
      );
}

PsIconButton _button(WidgetTester tester, String label) =>
    tester.widget<PsIconButton>(
      find.ancestor(
        of: find.byTooltip(label),
        matching: find.byType(PsIconButton),
      ),
    );

void main() {
  group('providers', () {
    testWidgets('a new reader is asked for a language model first', (
      tester,
    ) async {
      await _open(tester);
      expect(find.text('先配置大模型'), findsOneWidget);
      expect(find.text('未配置'), findsOneWidget);
      // Paid voices wait for a key; Edge needs none but starts off.
      expect(find.text('填写密钥后才能开启'), findsNWidgets(2));
      expect(_switch(tester, 'minimax').onChanged, isNull);
      expect(_switch(tester, 'bailian').onChanged, isNull);
      expect(_switch(tester, 'edge').onChanged, isNotNull);
      expect(_switch(tester, 'edge').value, isFalse);

      await tester.tap(find.text('配置大模型'));
      await tester.pumpAndSettle();
      expect(find.text('接口地址'), findsOneWidget);
    });

    testWidgets('each provider shows its state', (tester) async {
      await _open(
        tester,
        Fakes(
          providers: FakeProviders(
            const ProviderPreferences(
              baseUrl: 'https://api.deepseek.com/v1',
              profileModel: 'deepseek-chat',
              region: ProviderRegion.singapore,
              hasLlmKey: true,
              hasBailianKey: true,
            ),
          ),
        ),
      );
      expect(find.text('先配置大模型'), findsNothing);
      expect(find.text('还没有开启配音服务商'), findsNothing);
      expect(find.text('deepseek-chat · api.deepseek.com'), findsOneWidget);
      expect(find.text('已配置'), findsOneWidget);
      // A saved key starts on; Singapore cannot design voices.
      expect(_switch(tester, 'bailian').value, isTrue);
      expect(find.text('配音 · 新加坡'), findsOneWidget);
      expect(_switch(tester, 'minimax').value, isFalse);
    });

    testWidgets('switches turn voice providers on and off at once', (
      tester,
    ) async {
      final fakes = await _open(
        tester,
        Fakes(providers: FakeProviders(_ready.withKeys(minimax: true))),
      );
      await tester.tap(find.byKey(const ValueKey('switch-minimax')));
      await tester.pumpAndSettle();
      expect(fakes.providers.saves.last.preferences.minimaxOn, isFalse);
      expect(fakes.providers.value.voiceProviders, isEmpty);

      // Edge has no page, so its whole row is the switch.
      await tester.tap(find.text('Microsoft Edge'));
      await tester.pumpAndSettle();
      expect(fakes.providers.value.voiceProviders, {'edge'});
    });

    testWidgets('with no voice provider on, the banner turns Edge on', (
      tester,
    ) async {
      final fakes = await _open(
        tester,
        Fakes(providers: FakeProviders(_ready)),
      );
      expect(find.text('还没有开启配音服务商'), findsOneWidget);
      await tester.tap(find.text('开启 Microsoft Edge'));
      await tester.pumpAndSettle();
      expect(fakes.providers.saves.single.preferences.edgeOn, isTrue);
      expect(find.text('还没有开启配音服务商'), findsNothing);
    });

    testWidgets('a key without a model is not ready', (tester) async {
      await _open(
        tester,
        Fakes(
          providers: FakeProviders(const ProviderPreferences(hasLlmKey: true)),
        ),
      );
      expect(find.text('缺少模型'), findsOneWidget);
      expect(find.text('先配置大模型'), findsOneWidget);
    });
  });

  group('language model', () {
    Future<Fakes> openLlm(WidgetTester tester, [Fakes? fakes]) async {
      fakes = await _open(tester, fakes);
      await tester.tap(find.byKey(const ValueKey('provider-llm')));
      await tester.pumpAndSettle();
      return fakes;
    }

    testWidgets('saves the address, protocol, models and key, then returns', (
      tester,
    ) async {
      final fakes = await openLlm(tester);
      expect(find.text('保存'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('baseUrl')),
        ' https://api.deepseek.com/v1 ',
      );
      await tester.tap(find.text('Responses'));
      await tester.enterText(find.byKey(const ValueKey('key-llm')), 'sk-test');
      await tester.enterText(
        find.byKey(const ValueKey('profileModel')),
        'deepseek-chat',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final save = fakes.providers.saves.single;
      expect(save.preferences.baseUrl, 'https://api.deepseek.com/v1');
      expect(save.preferences.protocol, LlmProtocol.responses);
      expect(save.preferences.profileModel, 'deepseek-chat');
      expect(save.preferences.directorModel, '');
      expect(save.llmKey, 'sk-test');
      expect(save.minimaxKey, isNull);
      expect(save.bailianKey, isNull);
      // Back in settings, which now shows the model.
      expect(find.text('接口地址'), findsNothing);
      expect(find.text('已保存'), findsOneWidget);
      expect(find.text('deepseek-chat · api.deepseek.com'), findsOneWidget);
    });

    testWidgets('a bad address shows beside its field', (tester) async {
      final fakes = await openLlm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('baseUrl')),
        'api.deepseek.com',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('请输入以 https:// 或 http:// 开头的地址'), findsOneWidget);
      expect(fakes.providers.saves, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('baseUrl')),
        'https://api.deepseek.com',
      );
      await tester.pumpAndSettle();
      expect(find.text('请输入以 https:// 或 http:// 开头的地址'), findsNothing);
    });

    testWidgets('the save bar comes and goes with changes', (tester) async {
      await openLlm(tester);
      final field = find.byKey(const ValueKey('profileModel'));
      await tester.enterText(field, 'm');
      await tester.pumpAndSettle();
      expect(find.text('保存'), findsOneWidget);
      await tester.enterText(field, '');
      await tester.pumpAndSettle();
      expect(find.text('保存'), findsNothing);
    });

    testWidgets('a failed save stays and says so', (tester) async {
      final fakes = Fakes()..providers.failWith = Exception('sk-secret 401');
      await openLlm(tester, fakes);
      await tester.enterText(find.byKey(const ValueKey('key-llm')), 'sk-x');
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text('没能保存'), findsOneWidget);
      expect(find.text('接口地址'), findsOneWidget);
      // Nothing of the cause reaches the screen.
      expect(find.textContaining('sk-secret'), findsNothing);
    });

    testWidgets('leaving with unsaved edits asks first', (tester) async {
      final fakes = await openLlm(tester);
      await tester.enterText(
        find.byKey(const ValueKey('profileModel')),
        'deepseek-chat',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(find.text('放弃未保存的修改？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(find.text('接口地址'), findsOneWidget);

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃修改'));
      await tester.pumpAndSettle();
      expect(find.text('接口地址'), findsNothing);
      expect(find.text('先配置大模型'), findsOneWidget);
      expect(fakes.providers.saves, isEmpty);
    });
  });

  group('keys', () {
    testWidgets('a stored key is replaced only on request', (tester) async {
      final fakes = await _open(
        tester,
        Fakes(providers: FakeProviders(_ready)),
      );
      await tester.tap(find.byKey(const ValueKey('provider-llm')));
      await tester.pumpAndSettle();
      expect(find.text('已保存'), findsOneWidget);
      expect(find.byKey(const ValueKey('key-llm')), findsNothing);

      await tester.tap(find.text('更换'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('key-llm')), 'sk-new');
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(fakes.providers.saves.single.llmKey, 'sk-new');
    });

    testWidgets('a replacement left empty keeps the stored key', (
      tester,
    ) async {
      await _open(tester, Fakes(providers: FakeProviders(_ready)));
      await tester.tap(find.byKey(const ValueKey('provider-llm')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('更换'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('key-llm')), findsOneWidget);

      // Moving on to another field folds it back.
      await tester.tap(find.byKey(const ValueKey('profileModel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('key-llm')), findsNothing);
      expect(find.text('更换'), findsOneWidget);
      expect(find.text('保存'), findsNothing);
    });

    testWidgets('pasting fills the key, which can then be shown', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? {'text': '  sk-pasted\n'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _open(tester);
      await tester.tap(find.byKey(const ValueKey('provider-minimax')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('粘贴'));
      await tester.pumpAndSettle();

      final field = find.byKey(const ValueKey('key-minimax'));
      expect(tester.widget<TextField>(field).controller!.text, 'sk-pasted');
      expect(tester.widget<TextField>(field).obscureText, isTrue);
      await tester.tap(find.text('显示'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).obscureText, isFalse);
    });

    testWidgets('deleting a key asks, then deletes it at once', (tester) async {
      final fakes = await _open(
        tester,
        Fakes(
          providers: FakeProviders(
            const ProviderPreferences(hasMinimaxKey: true),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('provider-minimax')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('deleteKey')));
      await tester.pumpAndSettle();
      expect(find.text('删除这个密钥？'), findsOneWidget);

      await tester.tap(_inDialog('删除密钥'));
      await tester.pumpAndSettle();
      final save = fakes.providers.saves.single;
      expect(save.minimaxKey, '');
      expect(save.llmKey, isNull);
      expect(save.bailianKey, isNull);
      expect(find.text('密钥已删除'), findsOneWidget);
      expect(find.byKey(const ValueKey('deleteKey')), findsNothing);
      expect(find.byKey(const ValueKey('key-minimax')), findsOneWidget);
    });
  });

  testWidgets('Bailian saves its region with its key', (tester) async {
    final fakes = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('provider-bailian')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新加坡'));
    await tester.enterText(find.byKey(const ValueKey('key-bailian')), 'bl-key');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final save = fakes.providers.saves.single;
    expect(save.preferences.region, ProviderRegion.singapore);
    expect(save.bailianKey, 'bl-key');
    expect(save.minimaxKey, isNull);
    expect(save.llmKey, isNull);
    expect(find.text('配音 · 新加坡'), findsOneWidget);
  });

  group('generate while listening', () {
    Future<Fakes> openWith(
      WidgetTester tester, [
      GenerationPreferences prefs = const GenerationPreferences(),
    ]) async {
      final fakes = await _open(
        tester,
        Fakes(generation: FakeGeneration(GenerationState(preferences: prefs))),
      );
      // The whole group, from its header down, on screen.
      await _reveal(tester, find.text('合成提前量'));
      await tester.ensureVisible(find.text('边听边生成'));
      await tester.pumpAndSettle();
      return fakes;
    }

    testWidgets('the whole row turns automatic generation on', (tester) async {
      final fakes = await openWith(tester);
      await tester.tap(find.text('自动生成配音'));
      await tester.pumpAndSettle();
      expect(fakes.generation.saved.single.automatic, isTrue);
      expect(
        tester.widget<Switch>(find.byKey(const ValueKey('autoGenerate'))).value,
        isTrue,
      );
    });

    testWidgets('each lookahead carries the other along', (tester) async {
      final fakes = await openWith(tester);
      await tester.tap(find.byTooltip('增加合成提前量'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('增加合成提前量'));
      await tester.pumpAndSettle();
      expect(fakes.generation.saved.last.synthesis, 3);
      expect(fakes.generation.saved.last.directing, 3);

      await tester.tap(find.byTooltip('减少导演提前量'));
      await tester.pumpAndSettle();
      expect(fakes.generation.saved.last.directing, 2);
      expect(fakes.generation.saved.last.synthesis, 2);
      expect(find.text('2 章'), findsNWidgets(2));
    });

    testWidgets('lookaheads stop at 0 and 20', (tester) async {
      await openWith(
        tester,
        const GenerationPreferences(directing: 20, synthesis: 0),
      );
      expect(_button(tester, '增加导演提前量').onPressed, isNull);
      expect(_button(tester, '减少合成提前量').onPressed, isNull);
      expect(_button(tester, '减少导演提前量').onPressed, isNotNull);
      expect(_button(tester, '增加合成提前量').onPressed, isNotNull);
      expect(find.text('20 章'), findsOneWidget);
      expect(find.text('0 章'), findsOneWidget);
    });

    testWidgets('a failed save says so', (tester) async {
      final fakes = await openWith(tester);
      fakes.generation.saveFailure = Exception();
      await tester.tap(find.byKey(const ValueKey('autoGenerate')));
      await tester.pumpAndSettle();
      expect(find.text('没能保存生成设置，请再试一次'), findsOneWidget);
    });
  });

  group('exclusive voices', () {
    testWidgets('recasting waits until it is asked for', (tester) async {
      final fakes = await _open(tester);
      await _tap(tester, find.byKey(const ValueKey('exclusiveVoices')));
      final recast = find.widgetWithText(PsButton, '重新选角');
      expect(tester.widget<PsButton>(recast).onPressed, isNull);

      await tester.tap(find.byTooltip('增加专属音色'));
      await tester.pumpAndSettle();
      expect(fakes.casts.exclusiveCount, 20);
      expect(find.text('21'), findsOneWidget);

      await tester.tap(recast);
      await tester.pumpAndSettle();
      expect(fakes.casts.exclusiveCount, 21);
      expect(find.text('已按 21 个专属音色重新选角'), findsOneWidget);
      expect(find.text('21 个'), findsOneWidget);
    });

    testWidgets('a failed recast stays in the sheet', (tester) async {
      final fakes = await _open(tester);
      fakes.casts.countFailure = Exception();
      await _tap(tester, find.byKey(const ValueKey('exclusiveVoices')));
      await tester.tap(find.byTooltip('减少专属音色'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PsButton, '重新选角'));
      await tester.pumpAndSettle();
      expect(find.text('没能重新选角，请再试一次'), findsOneWidget);
      expect(fakes.casts.exclusiveCount, 20);
    });
  });

  testWidgets('night mode applies to the whole app', (tester) async {
    await _open(tester);
    await _tap(tester, find.text('开'));
    expect(
      Theme.of(tester.element(find.text('外观'))).brightness,
      Brightness.dark,
    );
  });

  group('storage', () {
    final books = [
      const BookStorageUsage(
        bookId: 'small',
        title: 'Small',
        totalBytes: 50 * _mb,
        audioBytes: 0,
      ),
      const BookStorageUsage(
        bookId: 'large',
        title: '阿Q正传',
        totalBytes: 300 * _mb,
        audioBytes: 200 * _mb,
      ),
    ];

    testWidgets('settings shows the total and opens the books', (tester) async {
      await _open(tester, Fakes(audioStorage: FakeAudioStorage(books)));
      await _reveal(tester, find.byKey(const ValueKey('storage')));
      expect(find.text('350 MB'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('storage')));
      await tester.pumpAndSettle();
      expect(find.text('共占用'), findsOneWidget);
      expect(find.text('音频 200 MB'), findsOneWidget);
      // Largest first; nothing to clear in a book without audio.
      expect(
        tester.getTopLeft(find.text('阿Q正传')).dy,
        lessThan(tester.getTopLeft(find.text('Small')).dy),
      );
      expect(find.text('共 50.0 MB · 没有音频'), findsOneWidget);
      final clears = tester.widgetList<PsButton>(
        find.widgetWithText(PsButton, '清理音频'),
      );
      expect([for (final b in clears) b.onPressed != null], [true, false]);
    });

    testWidgets('clearing asks first, then frees the audio', (tester) async {
      final fakes = await _open(
        tester,
        Fakes(audioStorage: FakeAudioStorage(books)),
      );
      await _tap(tester, find.byKey(const ValueKey('storage')));
      await tester.tap(find.widgetWithText(PsButton, '清理音频').first);
      await tester.pumpAndSettle();
      expect(find.text('清理《阿Q正传》的音频？'), findsOneWidget);
      await tester.tap(_inDialog('清理音频'));
      await tester.pumpAndSettle();

      expect(fakes.audioStorage.cleared, ['large']);
      expect(find.text('已清理《阿Q正传》的音频'), findsOneWidget);
      expect(find.text('共 100 MB · 没有音频'), findsOneWidget);
    });

    testWidgets('a failed reading can be retried', (tester) async {
      final storage = FakeAudioStorage(books)..usageFailure = Exception();
      await _open(tester, Fakes(audioStorage: storage));
      await _tap(tester, find.byKey(const ValueKey('storage')));
      expect(find.text('没能读取存储空间'), findsOneWidget);

      storage.usageFailure = null;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('阿Q正传'), findsOneWidget);
    });
  });

  group('feedback', () {
    testWidgets('exporting runs once at a time', (tester) async {
      final fakes = await _open(tester);
      final export = find.byKey(const ValueKey('exportDiagnostics'));
      await _reveal(tester, export);
      // The spinner turns until the export finishes, so nothing settles.
      await tester.tap(export);
      await tester.pump();
      expect(find.text('正在准备报告…'), findsOneWidget);
      await tester.tap(export);
      await tester.pump();
      expect(fakes.diagnostics!.exports, 1);

      fakes.diagnostics!.finishExport();
      await tester.pumpAndSettle();
      expect(find.text('不含密钥和书的正文'), findsOneWidget);
    });

    testWidgets('a failed feedback page can be retried', (tester) async {
      final fakes = await _open(tester);
      final report = find.byKey(const ValueKey('reportProblem'));
      await _reveal(tester, report);
      await tester.tap(report);
      await tester.pump();
      fakes.diagnostics!.finishFeedback(Exception('/private/path'));
      await tester.pumpAndSettle();
      expect(find.text('没能打开反馈页面'), findsOneWidget);
      expect(find.textContaining('/private/path'), findsNothing);

      await tester.tap(find.text('重试'));
      await tester.pump();
      expect(fakes.diagnostics!.feedbacks, 2);
    });

    testWidgets('without diagnostics the group is left out', (tester) async {
      await _open(tester, Fakes(withDiagnostics: false));
      await _reveal(tester, find.text('开源许可'));
      expect(find.text('导出诊断报告'), findsNothing);
    });
  });

  testWidgets('the English interface reads in English', (tester) async {
    reduceMotion(tester);
    await pumpApp(
      tester,
      MemoryBookshelf(),
      Fakes(),
      locale: const Locale('en'),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Set up a language model first'), findsOneWidget);
    expect(find.byType(SettingsPage), findsOneWidget);
  });
}
