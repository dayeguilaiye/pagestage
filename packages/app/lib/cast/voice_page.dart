import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/labels.dart';

enum VoiceTab { presets, design }

/// Choose a new voice for one speaker: from the presets that suit the book,
/// or designed from a description. Every option is heard before it can be
/// chosen. Pops with true once a voice is chosen.
class VoicePage extends StatefulWidget {
  const VoicePage({
    super.key,
    required this.voices,
    required this.bookId,
    required this.member,
    this.designProviders = const [],
    this.tab = VoiceTab.presets,
  });

  final Voices voices;
  final String bookId;
  final CastMember member;

  /// Empty hides voice design.
  final List<String> designProviders;
  final VoiceTab tab;

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  late var _tab = widget.designProviders.isEmpty
      ? VoiceTab.presets
      : widget.tab;

  List<VoiceOption>? _presets;
  var _presetsFailed = false;

  late var _provider = widget.designProviders.firstOrNull;
  late final _description = TextEditingController(
    text: widget.member.voiceDescription,
  );
  List<VoiceOption> _candidates = const [];
  var _designing = false;
  var _designFailed = false;

  /// Options the reader has listened to, by id; only these can be chosen.
  final _heard = <String>{};
  String? _choosing;
  var _chooseFailed = false;
  var _auditionFailed = false;

  Voices get _voices => widget.voices;

  @override
  void initState() {
    super.initState();
    _voices.addListener(_onVoices);
    _description.addListener(_onVoices);
    _loadPresets();
    if (widget.designProviders.isNotEmpty) _loadCandidates();
  }

  @override
  void dispose() {
    _voices.removeListener(_onVoices);
    // Stopping notifies other pages, which cannot rebuild mid-unmount.
    final voices = _voices;
    if (voices.auditioning != null) Future.microtask(voices.stopAudition);
    _description.dispose();
    super.dispose();
  }

  void _onVoices() => setState(() {});

  Future<void> _loadPresets() async {
    setState(() => _presetsFailed = false);
    try {
      final presets = await _voices.presets(widget.bookId, widget.member.id);
      if (mounted) setState(() => _presets = presets);
    } catch (_) {
      if (mounted) setState(() => _presetsFailed = true);
    }
  }

  Future<void> _loadCandidates() async {
    try {
      final candidates = await _voices.candidates(
        widget.bookId,
        widget.member.id,
      );
      if (mounted) setState(() => _candidates = candidates);
    } catch (_) {
      // Earlier candidates are a convenience; designing again still works.
    }
  }

  Future<void> _design() async {
    final provider = _provider;
    final description = _description.text.trim();
    if (provider == null || description.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _designing = true;
      _designFailed = false;
    });
    try {
      final candidates = await _voices.design(
        widget.bookId,
        widget.member.id,
        provider: provider,
        description: description,
      );
      if (mounted) {
        setState(() {
          _candidates = candidates;
          _heard.removeWhere((id) => !candidates.any((c) => c.id == id));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _designFailed = true);
    } finally {
      if (mounted) setState(() => _designing = false);
    }
  }

  Future<void> _audition(VoiceOption option, {required bool candidate}) async {
    if (_voices.auditioning == option.id) {
      await _voices.stopAudition();
      return;
    }
    setState(() {
      _heard.add(option.id);
      _auditionFailed = false;
    });
    try {
      candidate
          ? await _voices.auditionCandidate(
              widget.bookId,
              widget.member.id,
              option.id,
            )
          : await _voices.auditionPreset(
              widget.bookId,
              widget.member.id,
              option.id,
            );
    } catch (_) {
      if (mounted) {
        setState(() {
          _heard.remove(option.id);
          _auditionFailed = true;
        });
      }
    }
  }

  Future<void> _choose(VoiceOption option, {required bool candidate}) async {
    setState(() {
      _choosing = option.id;
      _chooseFailed = false;
    });
    try {
      if (_voices.auditioning != null) await _voices.stopAudition();
      candidate
          ? await _voices.selectCandidate(
              widget.bookId,
              widget.member.id,
              option.id,
            )
          : await _voices.selectPreset(
              widget.bookId,
              widget.member.id,
              option.id,
            );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _chooseFailed = true);
    } finally {
      if (mounted) setState(() => _choosing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        children: [
          PsNavBar(back: true, title: widget.member.name),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: PsSpace.s8 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                PsLargeTitle(
                  l.changeVoiceTitle(widget.member.name),
                  subtitle: widget.member.voiceName == null
                      ? l.voiceNotAssigned
                      : l.currentVoice(widget.member.voiceName!),
                ),
                if (widget.designProviders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PsSpace.s5,
                      0,
                      PsSpace.s5,
                      PsSpace.s5,
                    ),
                    child: PsSegmentedControl<VoiceTab>(
                      expand: true,
                      value: _tab,
                      onChanged: (tab) => setState(() => _tab = tab),
                      segments: [
                        PsSegment(VoiceTab.presets, l.presetVoices),
                        PsSegment(VoiceTab.design, l.voiceDesign),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PsSpace.s5,
                    0,
                    PsSpace.s5,
                    PsSpace.s4,
                  ),
                  child: Text(
                    l.hearBeforeChoosing,
                    style: PsType.subhead.copyWith(color: context.ps.ink2),
                  ),
                ),
                for (final failed in [
                  if (_auditionFailed) l.auditionFailed,
                  if (_chooseFailed) l.chooseVoiceFailed,
                ])
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PsSpace.s5,
                      0,
                      PsSpace.s5,
                      PsSpace.s4,
                    ),
                    child: PsBanner(tone: PsBannerTone.danger, title: failed),
                  ),
                if (_tab == VoiceTab.presets)
                  ..._presetList(l)
                else
                  ..._designer(l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _presetList(AppLocalizations l) {
    final presets = _presets;
    if (presets == null && _presetsFailed) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PsSpace.s5),
          child: PsBanner(
            tone: PsBannerTone.danger,
            title: l.presetsLoadFailed,
            actionLabel: l.retry,
            onAction: _loadPresets,
          ),
        ),
      ];
    }
    if (presets == null) return const [_Loading()];
    if (presets.isEmpty) {
      return [_Note(l.presetsEmpty)];
    }
    return [
      for (final option in presets)
        _OptionRow(
          option: option,
          playing: _voices.auditioning == option.id,
          heard: _heard.contains(option.id),
          choosing: _choosing == option.id,
          onAudition: () => _audition(option, candidate: false),
          onChoose: _choosing == null
              ? () => _choose(option, candidate: false)
              : null,
        ),
    ];
  }

  List<Widget> _designer(AppLocalizations l) {
    final p = context.ps;
    final providers = widget.designProviders;
    final canDesign =
        !_designing && _provider != null && _description.text.trim().isNotEmpty;
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: PsSpace.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: PsSpace.s3,
          children: [
            Text(
              l.designProvider,
              style: PsType.subhead.copyWith(
                color: p.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (providers.length > 1)
              PsSegmentedControl<String>(
                expand: true,
                value: _provider ?? providers.first,
                onChanged: (v) => setState(() => _provider = v),
                segments: [
                  for (final provider in providers)
                    PsSegment(provider, Labels.provider(l, provider)),
                ],
              )
            else
              Text(
                Labels.provider(l, providers.single),
                style: PsType.body.copyWith(color: p.ink2),
              ),
            const SizedBox(height: PsSpace.s1),
            Text(
              l.voiceDescriptionLabel,
              style: PsType.subhead.copyWith(
                color: p.ink,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextField(
              key: const ValueKey('voiceDescription'),
              controller: _description,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(hintText: l.voiceDescriptionHint),
            ),
            PsButton(
              label: _candidates.isEmpty
                  ? l.designCandidates
                  : l.designCandidatesAgain,
              icon: PsIcons.voice,
              variant: PsButtonVariant.primary,
              expand: true,
              loading: _designing,
              onPressed: canDesign ? _design : null,
            ),
            if (_designing)
              Text(
                l.designing,
                textAlign: TextAlign.center,
                style: PsType.caption.copyWith(color: p.ink2),
              ),
            if (_designFailed)
              PsBanner(
                tone: PsBannerTone.danger,
                title: l.designFailed,
                body: l.designFailedBody,
                actionLabel: l.retry,
                onAction: canDesign ? _design : null,
              ),
            const SizedBox(height: PsSpace.s3),
          ],
        ),
      ),
      if (_candidates.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PsSpace.s5,
            PsSpace.s2,
            PsSpace.s5,
            PsSpace.s1,
          ),
          child: Text(
            l.candidates,
            style: PsType.subhead.copyWith(
              color: p.ink2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        for (final option in _candidates)
          _OptionRow(
            option: option,
            playing: _voices.auditioning == option.id,
            heard: _heard.contains(option.id),
            choosing: _choosing == option.id,
            onAudition: () => _audition(option, candidate: true),
            onChoose: _choosing == null
                ? () => _choose(option, candidate: true)
                : null,
          ),
      ],
    ];
  }
}

/// One voice: play it, then choose it.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.playing,
    required this.heard,
    required this.choosing,
    required this.onAudition,
    required this.onChoose,
  });

  final VoiceOption option;
  final bool playing;
  final bool heard;
  final bool choosing;
  final VoidCallback onAudition;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final detail = [
      Labels.provider(l, option.provider),
      if (option.description.trim().isNotEmpty) option.description.trim(),
    ].join(' · ');
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('voice-${option.id}'),
        onTap: onAudition,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.fromLTRB(
            PsSpace.s5,
            PsSpace.s3,
            PsSpace.s4,
            PsSpace.s3,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.rule)),
          ),
          child: Row(
            spacing: PsSpace.s3,
            children: [
              PsIconButton(
                icon: playing ? PsIcons.pause : PsIcons.play,
                label: playing ? l.stopAudition : l.audition,
                onPressed: onAudition,
                variant: PsIconButtonVariant.outline,
                size: PsControlSize.sm,
                iconSize: 16,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Row(
                      spacing: PsSpace.s2,
                      children: [
                        Flexible(
                          child: Text(
                            option.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PsType.style(
                              PsFonts.sans,
                              16,
                              22,
                              FontWeight.w600,
                            ).copyWith(color: p.ink),
                          ),
                        ),
                        if (option.selected)
                          PsTag(l.voiceInUse, tone: PsTagTone.jade),
                        if (playing) const PsEq(),
                      ],
                    ),
                    Text(
                      detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PsType.subhead.copyWith(color: p.ink2),
                    ),
                  ],
                ),
              ),
              if (!option.selected)
                PsButton(
                  label: l.chooseVoice,
                  small: true,
                  variant: heard
                      ? PsButtonVariant.primary
                      : PsButtonVariant.secondary,
                  loading: choosing,
                  onPressed: heard ? onChoose : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(PsSpace.s8),
    child: Center(
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: PsSpace.s5),
    child: Text(
      text,
      style: PsType.body.copyWith(color: context.ps.ink2, height: 23 / 15),
    ),
  );
}
