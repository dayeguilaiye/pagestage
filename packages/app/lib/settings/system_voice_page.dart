import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';

/// Which of the phone's own voices reads books without AI voices, one for
/// Chinese and one for English. Tapping a voice plays a sample and uses it.
class SystemVoicePage extends StatefulWidget {
  const SystemVoicePage({super.key, required this.speech});

  final SystemSpeech speech;

  @override
  State<SystemVoicePage> createState() => _SystemVoicePageState();
}

class _SystemVoicePageState extends State<SystemVoicePage> {
  Map<String, List<SystemVoice>>? _voices;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final voices = {
        for (final language in const ['zh', 'en'])
          language: await widget.speech.voices(language),
      };
      if (mounted) setState(() => _voices = voices);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _choose(String language, SystemVoice voice) async {
    await widget.speech.choose(language, voice.name);
    await widget.speech.preview(language, voice.name);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final voices = _voices;
    Widget? quality(SystemVoice voice) => switch (voice.quality) {
      2 => PsTag(l.voiceQualityPremium, tone: PsTagTone.jade),
      1 => PsTag(l.voiceQualityEnhanced, tone: PsTagTone.jade),
      _ => null,
    };
    return Scaffold(
      body: Column(
        children: [
          PsNavBar(back: true, backLabel: l.settings, title: l.systemVoice),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: PsSpace.s10 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                PsLargeTitle(l.systemVoice, subtitle: l.systemVoicePageNote),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PsSpace.s4),
                  child: _failed
                      ? PsBanner(
                          tone: PsBannerTone.danger,
                          title: l.errorNoSystemVoice,
                        )
                      : voices == null
                      ? const Padding(
                          padding: EdgeInsets.all(PsSpace.s8),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: PsSpace.s8,
                          children: [
                            for (final MapEntry(key: language, value: list)
                                in voices.entries)
                              PsListGroup(
                                header: language == 'zh'
                                    ? l.systemVoiceChinese
                                    : l.systemVoiceEnglish,
                                footer: list.any((v) => v.quality > 0)
                                    ? null
                                    : l.systemVoiceDownloadNote,
                                children: [
                                  if (list.isEmpty)
                                    PsListRow(title: l.systemVoiceNone)
                                  else
                                    for (final voice in list)
                                      PsListRow(
                                        key: ValueKey(
                                          'voice-$language-${voice.name}',
                                        ),
                                        title: voice.name,
                                        subtitle: voice.locale,
                                        badge: quality(voice),
                                        trailing: voice.selected
                                            ? PsIcon(
                                                PsIcons.check,
                                                size: 20,
                                                color: p.vermilion,
                                              )
                                            : null,
                                        onTap: () => _choose(language, voice),
                                      ),
                                ],
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
