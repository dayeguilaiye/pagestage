import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'storage_page.dart';

/// The reader's own service accounts and the cast-wide voice setting. Keys
/// are never shown again once saved; a blank key field keeps the stored key.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.services});

  final AppServices services;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// A secret the reader may replace, remove or leave alone.
class _Secret {
  final text = TextEditingController();
  var removed = false;
  var visible = false;

  /// What to pass to [Providers.save]: null keeps the stored key, an empty
  /// string removes it.
  String? get change {
    if (removed) return '';
    final value = text.text.trim();
    return value.isEmpty ? null : value;
  }

  void reset() {
    text.clear();
    removed = false;
    visible = false;
  }
}

class _SettingsPageState extends State<SettingsPage> {
  final _scroll = ScrollController();
  var _scrolled = false;

  late final ProviderPreferences _initial = _providers.value;
  late final _baseUrl = TextEditingController(text: _initial.baseUrl);
  late final _profileModel = TextEditingController(text: _initial.profileModel);
  late final _directorModel = TextEditingController(
    text: _initial.directorModel,
  );
  late var _protocol = _initial.protocol;
  late var _region = _initial.region;
  final _llmKey = _Secret();
  final _minimaxKey = _Secret();
  final _bailianKey = _Secret();

  var _saving = false;
  var _saveFailed = false;
  var _urlInvalid = false;
  var _countFailed = false;

  Providers get _providers => widget.services.providers;
  Casts get _casts => widget.services.casts;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    for (final c in [
      _baseUrl,
      _profileModel,
      _directorModel,
      _llmKey.text,
      _minimaxKey.text,
      _bailianKey.text,
    ]) {
      c.addListener(_changed);
    }
    _providers.addListener(_changed);
  }

  @override
  void dispose() {
    _providers.removeListener(_changed);
    _scroll.dispose();
    for (final c in [
      _baseUrl,
      _profileModel,
      _directorModel,
      _llmKey.text,
      _minimaxKey.text,
      _bailianKey.text,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  void _onScroll() {
    final scrolled = _scroll.offset > 40;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  bool get _dirty {
    final saved = _providers.value;
    return _baseUrl.text.trim() != saved.baseUrl ||
        _profileModel.text.trim() != saved.profileModel ||
        _directorModel.text.trim() != saved.directorModel ||
        _protocol != saved.protocol ||
        _region != saved.region ||
        _llmKey.change != null ||
        _minimaxKey.change != null ||
        _bailianKey.change != null;
  }

  static bool _validUrl(String text) {
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final url = _baseUrl.text.trim();
    if (!_validUrl(url)) {
      setState(() => _urlInvalid = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _urlInvalid = false;
      _saving = true;
      _saveFailed = false;
    });
    final saved = _providers.value;
    try {
      await _providers.save(
        ProviderPreferences(
          baseUrl: url,
          protocol: _protocol,
          profileModel: _profileModel.text.trim(),
          directorModel: _directorModel.text.trim(),
          region: _region,
          hasLlmKey: saved.hasLlmKey,
          hasMinimaxKey: saved.hasMinimaxKey,
          hasBailianKey: saved.hasBailianKey,
        ),
        llmKey: _llmKey.change,
        minimaxKey: _minimaxKey.change,
        bailianKey: _bailianKey.change,
      );
      if (!mounted) return;
      setState(() {
        _llmKey.reset();
        _minimaxKey.reset();
        _bailianKey.reset();
      });
      showPsToast(context, l.settingsSaved);
    } catch (_) {
      // The cause may quote a key or a server reply, so none of it is shown.
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setCount(int count) async {
    setState(() => _countFailed = false);
    try {
      await _casts.setExclusiveCount(count);
    } catch (_) {
      if (mounted) setState(() => _countFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final saved = _providers.value;
    return Scaffold(
      body: Column(
        children: [
          PsNavBar(
            back: true,
            backLabel: l.shelfTitle,
            title: l.settings,
            showTitle: _scrolled,
            divider: _scrolled,
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: EdgeInsets.only(
                bottom: PsSpace.s8 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                PsLargeTitle(l.settings, subtitle: l.settingsSubtitle),
                _Section(
                  title: l.llmSection,
                  note: l.llmSectionNote,
                  children: [
                    _Field(
                      label: l.baseUrl,
                      child: TextField(
                        key: const ValueKey('baseUrl'),
                        controller: _baseUrl,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          hintText: 'https://api.openai.com/v1',
                          errorText: _urlInvalid ? l.baseUrlInvalid : null,
                        ),
                        onChanged: (_) {
                          if (_urlInvalid) setState(() => _urlInvalid = false);
                        },
                      ),
                    ),
                    _Field(
                      label: l.protocol,
                      child: PsSegmentedControl<LlmProtocol>(
                        expand: true,
                        value: _protocol,
                        onChanged: (v) => setState(() => _protocol = v),
                        segments: [
                          PsSegment(
                            LlmProtocol.chatCompletions,
                            l.protocolChatCompletions,
                          ),
                          PsSegment(LlmProtocol.responses, l.protocolResponses),
                        ],
                      ),
                    ),
                    _Field(
                      label: l.profileModel,
                      helper: l.profileModelHelp,
                      child: TextField(
                        key: const ValueKey('profileModel'),
                        controller: _profileModel,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                    ),
                    _Field(
                      label: l.directorModel,
                      helper: l.directorModelHelp,
                      child: TextField(
                        key: const ValueKey('directorModel'),
                        controller: _directorModel,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          hintText: _profileModel.text.trim().isEmpty
                              ? l.sameAsProfileModel
                              : _profileModel.text.trim(),
                        ),
                      ),
                    ),
                    _SecretField(
                      id: 'llm',
                      label: l.llmKey,
                      secret: _llmKey,
                      stored: saved.hasLlmKey,
                      onChanged: _changed,
                    ),
                  ],
                ),
                _Section(
                  title: 'MiniMax',
                  note: l.minimaxSectionNote,
                  children: [
                    _SecretField(
                      id: 'minimax',
                      label: l.minimaxKey,
                      secret: _minimaxKey,
                      stored: saved.hasMinimaxKey,
                      onChanged: _changed,
                    ),
                  ],
                ),
                _Section(
                  title: l.bailianSection,
                  note: l.bailianSectionNote,
                  children: [
                    _SecretField(
                      id: 'bailian',
                      label: l.bailianKey,
                      secret: _bailianKey,
                      stored: saved.hasBailianKey,
                      onChanged: _changed,
                    ),
                    _Field(
                      label: l.region,
                      child: PsSegmentedControl<ProviderRegion>(
                        expand: true,
                        value: _region,
                        onChanged: (v) => setState(() => _region = v),
                        segments: [
                          PsSegment(ProviderRegion.beijing, l.regionBeijing),
                          PsSegment(
                            ProviderRegion.singapore,
                            l.regionSingapore,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    PsSpace.s5,
                    0,
                    PsSpace.s5,
                    PsSpace.s10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: PsSpace.s3,
                    children: [
                      if (_saveFailed)
                        PsBanner(
                          tone: PsBannerTone.danger,
                          title: l.settingsSaveFailed,
                          body: l.settingsSaveFailedBody,
                          onClose: () => setState(() => _saveFailed = false),
                        ),
                      PsButton(
                        label: l.saveSettings,
                        variant: PsButtonVariant.primary,
                        expand: true,
                        loading: _saving,
                        onPressed: _dirty ? _save : null,
                      ),
                    ],
                  ),
                ),
                if (widget.services.generation case final generation?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PsSpace.s5,
                      0,
                      PsSpace.s5,
                      PsSpace.s8,
                    ),
                    child: GenerationSettings(generation: generation),
                  ),
                ListenableBuilder(
                  listenable: _casts,
                  builder: (context, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PsSpace.s5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: PsSpace.s3,
                      children: [
                        PsListGroup(
                          header: l.castSection,
                          footer: l.exclusiveVoicesNote,
                          children: [
                            PsListRow(
                              title: l.exclusiveVoices,
                              trailing: _Stepper(
                                value: _casts.exclusiveCount,
                                onChanged: _setCount,
                              ),
                            ),
                          ],
                        ),
                        if (_countFailed)
                          PsBanner(
                            tone: PsBannerTone.danger,
                            title: l.exclusiveVoicesFailed,
                            onClose: () => setState(() => _countFailed = false),
                          ),
                      ],
                    ),
                  ),
                ),
                if (widget.services.audioStorage case final storage?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PsSpace.s5,
                      PsSpace.s8,
                      PsSpace.s5,
                      0,
                    ),
                    child: PsListGroup(
                      header: l.storageSection,
                      children: [
                        PsListRow(
                          title: l.storage,
                          subtitle: l.storageRowNote,
                          chevron: true,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => StoragePage(storage: storage),
                            ),
                          ),
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

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.note});

  final String title;
  final String? note;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PsSpace.s5,
        PsSpace.s2,
        PsSpace.s5,
        PsSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: context.psHeading(PsType.title3.copyWith(color: p.ink)),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(note!, style: PsType.subhead.copyWith(color: p.ink2)),
            ),
          const SizedBox(height: PsSpace.s4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: PsSpace.s5,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.helper});

  final String label;
  final String? helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          label,
          style: PsType.subhead.copyWith(
            color: p.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
        Semantics(label: label, child: child),
        if (helper != null)
          Text(helper!, style: PsType.caption.copyWith(color: p.ink2)),
      ],
    );
  }
}

/// A masked key field. With a key stored, blank means keep it; removing it
/// is a separate, undoable choice that takes effect on save.
class _SecretField extends StatelessWidget {
  const _SecretField({
    required this.id,
    required this.label,
    required this.secret,
    required this.stored,
    required this.onChanged,
  });

  /// Names the field for tests: llm, minimax or bailian.
  final String id;
  final String label;
  final _Secret secret;
  final bool stored;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final removed = secret.removed;
    final status = removed
        ? l.keyWillBeRemoved
        : stored
        ? l.keyStored
        : l.keyNotSet;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Row(
          spacing: PsSpace.s2,
          children: [
            PsIcon(PsIcons.key, size: 16, color: p.ink2),
            Expanded(
              child: Text(
                label,
                style: PsType.subhead.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            PsTag(
              status,
              tone: removed
                  ? PsTagTone.danger
                  : stored
                  ? PsTagTone.jade
                  : PsTagTone.neutral,
            ),
          ],
        ),
        Semantics(
          label: label,
          child: TextField(
            key: ValueKey('key-$id'),
            controller: secret.text,
            enabled: !removed,
            obscureText: !secret.visible,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(
              hintText: removed
                  ? l.keyRemovedHint
                  : stored
                  ? l.keyStoredHint
                  : l.keyHint,
              suffixIcon: removed
                  ? null
                  : TextButton(
                      onPressed: () {
                        secret.visible = !secret.visible;
                        onChanged();
                      },
                      child: Text(secret.visible ? l.hideKey : l.showKey),
                    ),
            ),
          ),
        ),
        if (stored)
          Align(
            alignment: Alignment.centerLeft,
            child: PsButton(
              label: removed ? l.undoRemoveKey : l.removeKey,
              variant: PsButtonVariant.ghost,
              small: true,
              icon: removed ? null : PsIcons.trash,
              onPressed: () {
                secret.removed = !removed;
                if (secret.removed) secret.text.clear();
                onChanged();
              },
            ),
          ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.onChanged,
    this.max = 200,
    this.fewerLabel,
    this.moreLabel,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int max;
  final String? fewerLabel;
  final String? moreLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: PsSpace.s2,
      children: [
        PsIconButton(
          icon: PsIcons.minus,
          label: fewerLabel ?? l.fewerVoices,
          variant: PsIconButtonVariant.outline,
          size: PsControlSize.sm,
          iconSize: 16,
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: PsType.numeralLg.copyWith(color: p.ink),
          ),
        ),
        PsIconButton(
          icon: PsIcons.plus,
          label: moreLabel ?? l.moreVoices,
          variant: PsIconButtonVariant.outline,
          size: PsControlSize.sm,
          iconSize: 16,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// Generating while listening: whether to start without asking, and how
/// many chapters ahead to direct and to synthesize. Applies at once.
class GenerationSettings extends StatefulWidget {
  const GenerationSettings({super.key, required this.generation});

  final Generation generation;

  static const maxAhead = 20;

  @override
  State<GenerationSettings> createState() => _GenerationSettingsState();
}

class _GenerationSettingsState extends State<GenerationSettings> {
  var _failed = false;

  Future<void> _save(GenerationPreferences next) async {
    setState(() => _failed = false);
    try {
      await widget.generation.savePreferences(next);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: widget.generation,
      builder: (context, state, _) {
        final prefs = state.preferences;
        GenerationPreferences patch({
          bool? automatic,
          int? directing,
          int? synthesis,
        }) {
          final d = (directing ?? prefs.directing).clamp(
            0,
            GenerationSettings.maxAhead,
          );
          // Audio can only be made for chapters already directed.
          final s = (synthesis ?? prefs.synthesis).clamp(0, d);
          return GenerationPreferences(
            automatic: automatic ?? prefs.automatic,
            directing: d,
            synthesis: s,
          );
        }

        String ahead(int n) => n == 0 ? l.aheadOff : l.aheadChapters(n);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: PsSpace.s3,
          children: [
            PsListGroup(
              header: l.generationSection,
              footer: l.generationSectionNote,
              children: [
                PsListRow(
                  title: l.autoGenerate,
                  subtitle: l.autoGenerateNote,
                  trailing: Switch(
                    value: prefs.automatic,
                    onChanged: (v) => _save(patch(automatic: v)),
                  ),
                ),
                PsListRow(
                  title: l.directingAhead,
                  subtitle: ahead(prefs.directing),
                  trailing: _Stepper(
                    value: prefs.directing,
                    max: GenerationSettings.maxAhead,
                    fewerLabel: l.fewerDirectingAhead,
                    moreLabel: l.moreDirectingAhead,
                    onChanged: (v) => _save(patch(directing: v)),
                  ),
                ),
                PsListRow(
                  title: l.synthesisAhead,
                  subtitle: ahead(prefs.synthesis),
                  trailing: _Stepper(
                    value: prefs.synthesis,
                    max: prefs.directing,
                    fewerLabel: l.fewerSynthesisAhead,
                    moreLabel: l.moreSynthesisAhead,
                    onChanged: (v) => _save(patch(synthesis: v)),
                  ),
                ),
              ],
            ),
            if (_failed)
              PsBanner(
                tone: PsBannerTone.danger,
                title: l.generationSettingsFailed,
                onClose: () => setState(() => _failed = false),
              ),
          ],
        );
      },
    );
  }
}
