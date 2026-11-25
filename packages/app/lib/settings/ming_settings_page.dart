import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pagestage_core/pagestage_core.dart';
import 'package:path_provider/path_provider.dart';

import '../application/ming.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';

class MingSettingsPage extends StatefulWidget {
  const MingSettingsPage({
    super.key,
    required this.device,
    required this.enable,
  });
  final MingDevice device;
  final Future<void> Function() enable;

  @override
  State<MingSettingsPage> createState() => _MingSettingsPageState();
}

class _MingSettingsPageState extends State<MingSettingsPage> {
  AudioPlayer? _player;
  bool _starting = false, _listening = false, _failed = false;

  Future<void> _initialize() async {
    setState(() {
      _starting = true;
      _failed = false;
    });
    try {
      await widget.enable();
      await widget.device.initialize();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _preview() async {
    setState(() {
      _listening = true;
      _failed = false;
    });
    try {
      final lines = ['你看，我抢到两张演唱会门票！周六一起去吧！', '太好了！我等这一场等了好久，终于能去了！'];
      TtsRequest request(int i) => TtsRequest(
        text: lines[i],
        language: 'zh',
        binding: widget.device.voices
            .firstWhere(
              (v) => v.binding.voiceId == const ['ps_chuzhi', 'ps_chenshi'][i],
            )
            .binding,
        delivery: const Delivery(emotion: Emotion.happy),
      );
      final (first, second) = await MingAdapter(
        widget.device,
      ).synthesizePair(request(0), request(1));
      if (!mounted) return;
      final rate = first.audio.sampleRate;
      final offset = first.audio.samples.length + rate ~/ 3;
      final pcm = Int16List(offset + second.audio.samples.length)
        ..setAll(0, first.audio.samples)
        ..setAll(offset, second.audio.samples);
      final directory =
          (await getExternalCacheDirectories())?.firstOrNull ??
          await getTemporaryDirectory();
      final file = File('${directory.path}/ming-preview.wav');
      await file.writeAsBytes(
        PcmAudio(samples: pcm, sampleRate: rate).toWav(),
        flush: true,
      );
      if (!mounted) return;
      final player = _player ??= AudioPlayer();
      await player.setFilePath(file.path);
      if (mounted) await player.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.mingTitle)),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: widget.device,
          builder: (context, state, _) {
            final module = switch (state.detail) {
              'prefill' => l.mingPrefill,
              'step' => l.mingStep,
              'flow' => l.mingFlow,
              'agg' => l.mingAgg,
              'dec' => l.mingDec,
              'flowPair' => l.mingFlowPair,
              'stepPair' => l.mingStepPair,
              _ => '',
            };
            final message = switch (state.phase) {
              'ready' => l.mingReady,
              'copying' => l.mingCopying,
              'compiling' => l.mingCompiling(module),
              'error' =>
                state.detail == 'storage'
                    ? l.mingStorageError
                    : l.mingInitError,
              _ => l.mingBeforeInit,
            };
            return ListView(
              padding: const EdgeInsets.all(PsSpace.s5),
              children: [
                Text(
                  l.mingDescription,
                  style: PsType.body.copyWith(color: context.ps.ink2),
                ),
                const SizedBox(height: PsSpace.s8),
                Text(
                  message,
                  style: PsType.rowTitle.copyWith(color: context.ps.ink),
                ),
                const SizedBox(height: PsSpace.s3),
                LinearProgressIndicator(value: state.percent / 100),
                const SizedBox(height: PsSpace.s2),
                Text(
                  '${state.percent}%  ·  ${state.done}/${state.total}',
                  key: const ValueKey('ming-progress'),
                  style: PsType.subhead,
                ),
                const SizedBox(height: PsSpace.s6),
                if (state.ready)
                  PsButton(
                    label: l.mingPreview,
                    expand: true,
                    loading: _listening,
                    onPressed: _listening ? null : _preview,
                  )
                else if (!state.working)
                  PsButton(
                    label: state.phase == 'error'
                        ? l.mingRetry
                        : l.mingInitialize,
                    expand: true,
                    loading: _starting,
                    variant: PsButtonVariant.primary,
                    onPressed: _starting ? null : _initialize,
                  ),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.only(top: PsSpace.s3),
                    child: Text(l.mingActionError),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
