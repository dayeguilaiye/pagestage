import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagestage_app/application/package_controller.dart';
import 'package:pagestage_app/playback/just_audio_engine.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/test/support/generation_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native packages import, play and open the system share sheet', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    final support = await getApplicationSupportDirectory();
    await support.create(recursive: true);
    final directory = await support.createTemp('packages-test-');
    final source = LocalStore('${directory.path}/source/db.sqlite');
    final target = LocalStore('${directory.path}/target/db.sqlite');
    final engine = JustAudioEngine();
    try {
      final input = await File(
        '${directory.path}/book.txt',
      ).writeAsString('Chapter 1\nA journey begins.\nThe wind rises.\n');
      final book = await Library(source).importTxt(input.path, title: '远行');
      await Profiler(source, GenerationLlm()).profile(book, throughChapter: 1);
      await Casting(source).recommend(book, providers: {'minimax'});
      final tts = _ToneTts();
      final scheduler = await Scheduler.open(
        store: source,
        profileLlm: GenerationLlm(),
        directorLlm: GenerationLlm(),
        ttsAdapters: {'minimax': tts},
      );
      try {
        await scheduler.enqueue(book.id, TaskKind.synthesize, through: 1);
        await scheduler.idle;
      } finally {
        await scheduler.close();
      }

      final exports = Directory('${support.path}/exports');
      final package = await PackageController(
        source,
        directory: exports,
      ).export(book.id, audio: true);
      final imported = await Library(
        target,
        pickFile: () async => package.path,
      ).importBook();
      expect(imported, isA<PackageImported>());
      expect((imported as PackageImported).audioChapters, 1);
      final audio = (await AudioRepository(target).get(book.id, 1))!;
      expect(audio.imported, isTrue);
      final script = (await ScriptRepository(target).get(book.id, 1))!;
      expect(await AudioRepository(target).isComplete(script), isTrue);
      await engine.load(audio.path!, audio.duration);
      await engine.play();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(engine.state.error, isNull);
      expect(engine.state.position, greaterThan(Duration.zero));
      await engine.pause();

      final scriptPackage = await PackageController(
        target,
        directory: exports,
      ).export(book.id, audio: false);
      final summary = await BookPackages(target).inspect(scriptPackage.path);
      expect(summary.scriptChapters, [1]);
      expect(summary.audioChapters, isEmpty);
      const sharing = NativeFileSharing();
      // The native bridge must allow the export directory and reject other files.
      await expectLater(
        sharing.share(input.path),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'share_failed',
          ),
        ),
      );
      await sharing.share(scriptPackage.path);
      await Future<void>.delayed(const Duration(seconds: 1));
      debugPrint(
        'PACKAGES_RESULT ${Platform.operatingSystem}: offline export/import, '
        'native playback, share path validation and system share sheet passed',
      );
    } finally {
      await engine.dispose();
      await source.close();
      await target.close();
      await directory.delete(recursive: true);
    }
  });
}

class _ToneTts extends GenerationTts {
  @override
  Future<TtsAudio> synthesize(TtsRequest request) async => TtsAudio(
    audio: PcmAudio(
      samples: Int16List.fromList(
        List.generate(
          24000,
          (i) => (sin(i / 24000 * 2 * pi * 220) * 1000).round(),
        ),
      ),
      sampleRate: 24000,
    ),
  );
}
