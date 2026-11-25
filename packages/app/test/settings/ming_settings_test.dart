import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show Endian;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagestage_app/application/ming.dart';
import 'package:pagestage_app/application/provider_gateway.dart';
import 'package:pagestage_app/design/design.dart';
import 'package:pagestage_app/l10n/app_localizations.dart';
import 'package:pagestage_app/settings/ming_settings_page.dart';

class _Device extends MingDevice {
  _Device() : super(const MingPreparation('idle', 0, 7, 0, ''));
  int starts = 0;
  @override
  Future<void> initialize() async {
    starts++;
    value = const MingPreparation('copying', 0, 7, 0, '');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('distinguishes saved Ming synthesis failures from network failures', () {
    for (final code in ['ming_unavailable', 'ming_synthesis']) {
      expect(
        providerReason(ProviderErrorKind.unavailable, code),
        'localSynthesisFailed',
      );
    }
    expect(providerReason(ProviderErrorKind.unavailable), 'network');
  });

  test(
    'ships selectable voices with distinct speaker rows and supports saved demo bindings',
    () async {
      const path = 'android/app/src/main/assets/ming';
      final rows =
          jsonDecode(await File('$path/voices.json').readAsString()) as List;
      const methods = MethodChannel('pagestage/ming');
      const events = MethodChannel('pagestage/ming/progress');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        methods,
        (call) async => {
          'available': true,
          'phase': 'ready',
          'done': 7,
          'total': 7,
          'percent': 100,
          'detail': '',
          'voices': rows,
        },
      );
      messenger.setMockMethodCallHandler(events, (_) async => null);
      final device = (await MingDevice.open())!;
      addTearDown(() {
        device.dispose();
        messenger.setMockMethodCallHandler(methods, null);
        messenger.setMockMethodCallHandler(events, null);
      });
      final catalog = MingTtsEngine(
        device,
      ).presets(ProviderConfiguration.fromValues({}));
      expect(catalog, hasLength(32));
      expect(catalog.map((p) => p.displayName).toSet(), hasLength(32));
      expect(catalog.where((p) => p.narratorCandidate), hasLength(6));
      for (final gender in ['male', 'female']) {
        expect(
          catalog
              .where((p) => p.gender == gender)
              .map((p) => p.ageGroup)
              .toSet(),
          {'child', 'teen', 'youngAdult', 'middleAged', 'senior'},
        );
      }
      final features = <String>{};
      final catalogRows = {for (final row in rows.cast<Map>()) row['id']: row};
      for (final p in catalog) {
        expect(p.languages, ['zh']);
        expect(p.styles, isNotEmpty);
        final bytes = await File(
          '$path/${p.binding.voiceId}.bin',
        ).readAsBytes();
        expect(bytes, hasLength(896 * 4));
        expect(
          sha256.convert(bytes).toString(),
          catalogRows[p.binding.voiceId]!['speakerSha256'],
        );
        final values = ByteData.sublistView(bytes);
        expect(
          List.generate(
            896,
            (i) => values.getFloat32(4 * i, Endian.little),
          ).every((x) => x.isFinite),
          isTrue,
        );
        expect(features.add(base64Encode(bytes)), isTrue);
        device.checkBinding(p.binding);
      }
      for (final id in ['edge_xiaoxiao', 'edge_yunxi']) {
        expect(catalog.any((p) => p.binding.voiceId == id), isFalse);
        device.checkBinding(
          VoiceBinding(
            provider: 'ming',
            model: MingTtsEngine.model,
            voiceId: id,
          ),
        );
      }
    },
  );

  test(
    'catalog voices use the same prepared graph across casts and batches',
    () async {
      const state = MingPreparation('ready', 7, 7, 100, '');
      final voices = [
        for (final id in ['first', 'second', 'third'])
          VoicePreset(
            id: 'ming:$id',
            languages: const ['zh'],
            binding: VoiceBinding(
              provider: 'ming',
              model: MingTtsEngine.model,
              voiceId: id,
            ),
          ),
      ];
      final device = MingDevice(state, voices: voices);
      final engine = MingTtsEngine(device);
      final config = ProviderConfiguration.fromValues(const {});
      final calls = <String>[];
      const channel = MethodChannel('pagestage/ming');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        final rows = (call.arguments as Map)['lines'] as List;
        expect(rows.map((row) => row['voice']), ['third', 'first']);
        return [Uint8List(4), Uint8List(4)];
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        device.dispose();
      });
      expect(engine.presets(config), hasLength(3));
      final adapter = engine.open(config).adapter as PairedTtsAdapter;
      TtsRequest line(VoicePreset voice) =>
          TtsRequest(text: '台词', language: 'zh', binding: voice.binding);
      await adapter.synthesizePair(line(voices[2]), line(voices[0]));
      expect(calls, ['synthesize']);
      expect(device.value.done, 7);
    },
  );
  testWidgets('manual initialization shows measured completion checkpoints', (
    tester,
  ) async {
    final device = _Device();
    var enabled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: PsTheme.light,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MingSettingsPage(
          device: device,
          enable: () async {
            enabled = true;
          },
        ),
      ),
    );
    expect(device.starts, 0);
    expect(find.text('0%  ·  0/7'), findsOneWidget);
    await tester.tap(find.text('初始化'));
    await tester.pump();
    expect(enabled, isTrue);
    expect(device.starts, 1);
    device.value = const MingPreparation('compiling', 5, 7, 46, 'flowPair');
    await tester.pump();
    await tester.pump(const Duration(seconds: 40));
    expect(find.text('46%  ·  5/7'), findsOneWidget);
    expect(find.textContaining('双句语音生成'), findsOneWidget);
    device.value = const MingPreparation('ready', 7, 7, 100, '');
    await tester.pump();
    expect(find.text('100%  ·  7/7'), findsOneWidget);
    expect(find.text('试听双人对话'), findsOneWidget);
  });
}
