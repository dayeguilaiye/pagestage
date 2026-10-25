import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/shelf/memory_bookshelf.dart';

import '../support/fake_services.dart';

final _export = find.byKey(const ValueKey('exportDiagnostics'));
final _feedback = find.byKey(const ValueKey('reportProblem'));

Future<Fakes> _openSettings(
  WidgetTester tester, {
  bool withDiagnostics = true,
  Locale locale = const Locale('zh', 'CN'),
}) async {
  final fakes = Fakes(withDiagnostics: withDiagnostics);
  await pumpApp(tester, MemoryBookshelf(), fakes, locale: locale);
  await tester.tap(
    find.byTooltip(locale.languageCode == 'zh' ? '设置' : 'Settings'),
  );
  await tester.pumpAndSettle();
  return fakes;
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  final list = find.byType(Scrollable).first;
  final position = tester.state<ScrollableState>(list).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('exporting runs once at a time and finishes quietly', (
    tester,
  ) async {
    final fakes = await _openSettings(tester);
    await _scrollToEnd(tester);
    final diagnostics = fakes.diagnostics!;

    await tester.tap(_export);
    await tester.pump();
    expect(diagnostics.exports, 1);
    expect(find.text('正在准备报告…'), findsOneWidget);

    // Tapping again while the share sheet opens does not start another.
    await tester.tap(_export);
    await tester.pump();
    expect(diagnostics.exports, 1);

    diagnostics.finishExport();
    await tester.pumpAndSettle();
    expect(find.text('正在准备报告…'), findsNothing);
    expect(find.text('没能导出诊断报告'), findsNothing);
  });

  testWidgets('a failed export shows fixed words and can be retried', (
    tester,
  ) async {
    final fakes = await _openSettings(tester);
    await _scrollToEnd(tester);
    final diagnostics = fakes.diagnostics!;

    await tester.tap(_export);
    await tester.pump();
    diagnostics.finishExport(
      Exception('/data/user/0/app/report.zip: sk-secret permission denied'),
    );
    await tester.pumpAndSettle();
    expect(find.text('没能导出诊断报告'), findsOneWidget);
    expect(find.textContaining('sk-secret'), findsNothing);
    expect(find.textContaining('/data'), findsNothing);

    await _scrollToEnd(tester);
    await tester.tap(find.text('重试'));
    await tester.pump();
    expect(diagnostics.exports, 2);
    expect(find.text('没能导出诊断报告'), findsNothing);
    diagnostics.finishExport();
    await tester.pumpAndSettle();
  });

  testWidgets('feedback opens once and explains a failure', (tester) async {
    final fakes = await _openSettings(tester);
    await _scrollToEnd(tester);
    final diagnostics = fakes.diagnostics!;

    await tester.tap(_feedback);
    await tester.tap(_feedback);
    await tester.pump();
    expect(diagnostics.feedbacks, 1);
    expect(find.text('正在打开浏览器…'), findsOneWidget);
    // Exporting is independent of an open feedback request.
    await tester.tap(_export);
    await tester.pump();
    expect(diagnostics.exports, 1);

    diagnostics.finishFeedback(StateError('no browser'));
    diagnostics.finishExport();
    await tester.pumpAndSettle();
    expect(find.text('没能打开反馈页面'), findsOneWidget);
    expect(find.textContaining('no browser'), findsNothing);
  });

  testWidgets('the report is explained before anything is shared', (
    tester,
  ) async {
    await _openSettings(tester);
    await _scrollToEnd(tester);
    expect(find.textContaining('应用版本、系统与设备信息、近期的错误和崩溃'), findsOneWidget);
    expect(find.textContaining('任何密钥，以及书的正文'), findsOneWidget);
    expect(find.textContaining('不会自动上传'), findsOneWidget);
  });

  testWidgets('English explains the report too', (tester) async {
    await _openSettings(tester, locale: const Locale('en'));
    await _scrollToEnd(tester);
    expect(find.text('Export a diagnostic report'), findsOneWidget);
    expect(
      find.textContaining('Nothing is uploaded automatically'),
      findsOneWidget,
    );
  });

  testWidgets('without diagnostics there is no section', (tester) async {
    await _openSettings(tester, withDiagnostics: false);
    await _scrollToEnd(tester);
    expect(_export, findsNothing);
    expect(find.text('诊断与反馈'), findsNothing);
  });
}
