import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/app_scope.dart';
import '../listening/labels.dart';
import 'open_settings.dart';

/// A language model service the reader likely already has an account
/// with: choosing it fills the address, protocol and a model that answers
/// structured output. Anything else is entered by hand.
class LlmPreset {
  const LlmPreset(this.id, this.baseUrl, this.api, this.model, this.console);
  final String id;
  final String baseUrl;
  final String api;
  final String model;

  /// Where its API keys are made.
  final String console;

  static const all = [
    LlmPreset(
      'deepseek',
      'https://api.deepseek.com',
      'responses',
      'deepseek-flash',
      'platform.deepseek.com',
    ),
    LlmPreset(
      'bailian',
      'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'chat-completions',
      'qwen-plus',
      'bailian.console.aliyun.com',
    ),
    LlmPreset(
      'openai',
      'https://api.openai.com/v1',
      'chat-completions',
      'gpt-4.1-mini',
      'platform.openai.com',
    ),
  ];

  /// The preset serving [baseUrl], or null for one entered by hand.
  static LlmPreset? of(String baseUrl) {
    final host = Uri.tryParse(baseUrl.trim())?.host ?? '';
    return all.where((p) => Uri.parse(p.baseUrl).host == host).firstOrNull;
  }
}

/// One engine's page, built from the settings the engine declares: what it
/// does and can perform, its settings in groups, and its stored key. Any
/// engine added to the registries gets this page without a screen of its
/// own.
class EnginePage extends StatefulWidget {
  const EnginePage({super.key, required this.providers, required this.id});

  final Providers providers;

  /// The engine's id, as in [EngineView.id].
  final String id;

  @override
  State<EnginePage> createState() => _EnginePageState();
}

class _EnginePageState extends State<EnginePage> {
  late final EngineView _initial = _engine;
  late final _texts = {
    for (final setting in _initial.settings)
      if (setting.kind == EngineSettingKind.text)
        setting.name: TextEditingController(
          text: _initial.values[setting.name] ?? '',
        ),
  };
  late final _choices = {
    for (final setting in _initial.settings)
      if (setting.kind == EngineSettingKind.choice)
        setting.name: _initial.value(setting.name),
  };
  late final _keys = {
    for (final setting in _initial.settings)
      if (setting.kind == EngineSettingKind.secret) setting.name: _KeyDraft(),
  };

  /// Settings whose value needs fixing before it can be saved.
  final _invalid = <String>{};

  /// The last connection test: 'ok' or a reason code; null before one.
  String? _tested;
  var _testing = false;

  /// With the 百炼 preset, its key can voice too: one account for both.
  var _shareKey = true;

  Map<String, String> get _draftValues => {
    for (final entry in _texts.entries) entry.key: entry.value.text.trim(),
    ..._choices,
  };

  Map<String, String> get _draftSecrets => {
    for (final entry in _keys.entries) entry.key: ?entry.value.change,
  };

  Future<void> _test() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _testing = true;
      _tested = null;
    });
    String? result;
    try {
      result = await widget.providers.test(
        widget.id,
        values: _draftValues,
        secrets: _draftSecrets,
      );
    } catch (_) {
      result = 'network';
    }
    if (mounted) {
      setState(() {
        _testing = false;
        _tested = result ?? 'ok';
      });
    }
  }

  void _applyPreset(LlmPreset? preset) {
    setState(() {
      _tested = null;
      if (preset == null) return;
      _texts['baseUrl']?.text = preset.baseUrl;
      if (_choices.containsKey('api')) _choices['api'] = preset.api;
      _texts['profileModel']?.text = preset.model;
      _texts['directorModel']?.text = '';
    });
  }

  Future<void> _pickPreset(BuildContext row) async {
    final l = AppLocalizations.of(context);
    final box = row.findRenderObject()! as RenderBox;
    final choice = await showPsMenu<String>(
      context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      items: [
        for (final preset in LlmPreset.all)
          PsMenuItem(preset.id, _presetName(l, preset.id)),
        PsMenuItem('custom', l.presetCustom),
      ],
    );
    if (choice == null || !mounted) return;
    _applyPreset(LlmPreset.all.where((p) => p.id == choice).firstOrNull);
  }

  static String _presetName(AppLocalizations l, String id) => switch (id) {
    'deepseek' => 'DeepSeek',
    'bailian' => l.presetBailian,
    'openai' => 'OpenAI',
    _ => l.presetCustom,
  };

  EngineView get _engine => widget.providers.value.engine(widget.id)!;

  @override
  void initState() {
    super.initState();
    for (final Listenable field in [..._texts.values, ..._keys.values]) {
      field.addListener(_changed);
    }
    widget.providers.addListener(_changed);
  }

  @override
  void dispose() {
    widget.providers.removeListener(_changed);
    for (final field in _texts.values) {
      field.dispose();
    }
    for (final key in _keys.values) {
      key.dispose();
    }
    super.dispose();
  }

  void _changed() => setState(() {});

  bool get _dirty {
    final saved = _engine;
    return _texts.entries.any(
          (e) => e.value.text.trim() != (saved.values[e.key] ?? ''),
        ) ||
        _choices.entries.any((e) => e.value != saved.value(e.key)) ||
        _keys.values.any((key) => key.change != null);
  }

  /// Mirrors what [Providers.configure] accepts, so a bad address shows
  /// beside its field instead of failing the save.
  static bool _validUrl(String text) {
    final uri = Uri.tryParse(text);
    return uri != null &&
        const ['https', 'http', 'wss', 'ws'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  Future<bool> _save() async {
    final url = _texts['baseUrl']?.text.trim() ?? '';
    if (url.isNotEmpty && !_validUrl(url)) {
      setState(() => _invalid.add('baseUrl'));
      return false;
    }
    final services = AppScope.servicesOf(context);
    final key = _keys['key']?.change;
    final share =
        _shareKey &&
        key != null &&
        LlmPreset.of(url)?.id == 'bailian' &&
        widget.providers.value.engine('bailian') != null;
    await widget.providers.configure(
      widget.id,
      values: _draftValues,
      secrets: _draftSecrets,
    );
    if (share) {
      // A 百炼 key from the Beijing console voices there too.
      await widget.providers.configure(
        'bailian',
        values: {'region': 'beijing'},
        secrets: {'key': key},
      );
    }
    // Setting a provider up is when the reader agrees to what it will be
    // sent, instead of in the middle of listening later.
    if (services != null) {
      for (final id in [widget.id, if (share) 'bailian']) {
        await agreeToEngine(services, id);
      }
    }
    return true;
  }

  Widget _field(AppLocalizations l, EngineView engine, EngineSetting setting) {
    final label = Labels.engineSetting(l, setting.name);
    switch (setting.kind) {
      case EngineSettingKind.secret:
        return _KeyRow(
          id: engine.id,
          label: label,
          draft: _keys[setting.name]!,
          stored: engine.secrets.contains(setting.name),
        );
      case EngineSettingKind.choice:
        return _FieldRow(
          label: label,
          child: PsSegmentedControl<String>(
            expand: true,
            value: _choices[setting.name]!,
            onChanged: (v) => setState(() => _choices[setting.name] = v),
            segments: [
              for (final option in setting.options)
                PsSegment(option, Labels.engineOption(l, option)),
            ],
          ),
        );
      case EngineSettingKind.text:
        final url = setting.name == 'baseUrl';
        return _TextRow(
          id: setting.name,
          label: label,
          controller: _texts[setting.name]!,
          hint:
              setting.fallback ??
              (setting.name == 'directorModel'
                  ? l.sameAsProfileModel
                  : l.modelHint),
          keyboardType: url ? TextInputType.url : null,
          wrap: url,
          error: _invalid.contains(setting.name) ? l.baseUrlInvalid : null,
          onChanged: () {
            if (_invalid.remove(setting.name)) setState(() {});
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final engine = _engine;
    final language = engine.kind == EngineKind.language;
    // Models are chosen apart from how the engine is reached.
    final models = [
      for (final s in engine.settings)
        if (s.name.endsWith('Model')) s,
    ];
    final connection = [
      for (final s in engine.settings)
        if (!models.contains(s)) s,
    ];
    final note = switch (engine.status) {
      EngineStatus.unavailable => l.engineComingSoonNote,
      EngineStatus.notInstalled => l.engineNotInstalledNote,
      _ => switch (engine.id) {
        'llm' => l.llmPageNote,
        'minimax' => l.minimaxPageNote,
        'bailian' => l.bailianPageNote,
        'edge' => l.edgePageNote,
        _ => language ? l.llmPageNote : l.enginePageNote,
      },
    };
    final stored = engine.secrets;
    final preset = engine.id == 'llm'
        ? LlmPreset.of(_texts['baseUrl']?.text ?? '')
        : null;
    final p = context.ps;
    final caption = PsType.caption.copyWith(
      color: p.ink2,
      fontWeight: FontWeight.w400,
    );
    return _FormScaffold(
      title: Labels.engine(l, engine),
      note: note,
      dirty: _dirty,
      onSave: _save,
      deleteKeyBody: language ? l.deleteLlmKeyBody : l.deleteVoiceKeyBody,
      onDeleteKey: stored.isEmpty
          ? null
          : () => widget.providers.configure(
              widget.id,
              secrets: {for (final name in stored) name: ''},
            ),
      children: [
        if (!language && engine.status != EngineStatus.unavailable)
          _Abilities(engine: engine),
        if (engine.id == 'llm')
          PsListGroup(
            header: l.presetSection,
            footer: preset == null
                ? l.presetCustomNote
                : l.presetConsoleNote(preset.console),
            children: [
              Builder(
                builder: (row) => PsListRow(
                  key: const ValueKey('llmPreset'),
                  title: l.presetService,
                  detail: preset == null
                      ? l.presetCustom
                      : _presetName(l, preset.id),
                  chevron: true,
                  onTap: () => _pickPreset(row),
                ),
              ),
              if (preset?.id == 'bailian' &&
                  engine.secrets.isEmpty &&
                  widget.providers.value.engine('bailian') != null)
                MergeSemantics(
                  child: PsListRow(
                    title: l.shareBailianKey,
                    subtitle: l.shareBailianKeyNote,
                    trailing: Switch(
                      key: const ValueKey('shareKey'),
                      value: _shareKey,
                      onChanged: (v) => setState(() => _shareKey = v),
                    ),
                    onTap: () => setState(() => _shareKey = !_shareKey),
                  ),
                ),
            ],
          ),
        if (connection.isNotEmpty)
          PsListGroup(
            header: models.isEmpty ? null : l.connectionSection,
            footer: switch (engine.id) {
              'llm' => l.llmConnectionNote,
              'minimax' => l.minimaxKeyNote,
              'bailian' => l.bailianRegionNote,
              _ => null,
            },
            children: [for (final s in connection) _field(l, engine, s)],
          ),
        if (models.isNotEmpty)
          PsListGroup(
            header: l.modelsSection,
            footer: language ? l.modelsNote : null,
            children: [for (final s in models) _field(l, engine, s)],
          ),
        if (engine.settings.isNotEmpty &&
            engine.status != EngineStatus.unavailable &&
            engine.site == EngineSite.cloud)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: PsSpace.s2,
            children: [
              PsButton(
                key: const ValueKey('testConnection'),
                label: l.testConnection,
                icon: PsIcons.check,
                expand: true,
                loading: _testing,
                onPressed: _testing ? null : _test,
              ),
              if (_tested case final tested?)
                Text(
                  tested == 'ok' ? l.testConnectionOk : _testFailure(l, tested),
                  textAlign: TextAlign.center,
                  style: caption.copyWith(
                    color: tested == 'ok' ? p.jade : p.danger,
                  ),
                )
              else
                Text(
                  l.testConnectionNote,
                  textAlign: TextAlign.center,
                  style: caption,
                ),
            ],
          ),
      ],
    );
  }

  /// What a failed test means and what to change, by reason.
  static String _testFailure(AppLocalizations l, String reason) =>
      switch (reason) {
        'unauthorized' => l.testUnauthorized,
        'schemaUnsupported' => l.testSchemaUnsupported,
        'requestRejected' => l.testRequestRejected,
        'quotaExceeded' => l.testQuota,
        'missingKey' => l.testMissing,
        'rateLimited' => l.testRateLimited,
        _ => l.testNetwork,
      };
}

/// What a voice engine performs of the director's script, as plain labels:
/// the reader compares outcomes, never parameters.
class _Abilities extends StatelessWidget {
  const _Abilities({required this.engine});

  final EngineView engine;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    // Voice design is listed with the voices it adds to.
    final performed = [
      for (final trait in EngineTrait.values)
        if (engine.traits.contains(trait) && trait != EngineTrait.voiceDesign)
          trait,
    ];
    return PsListGroup(
      header: l.engineAbilities,
      footer: l.engineAbilitiesNote,
      children: [
        Padding(
          padding: const EdgeInsets.all(PsSpace.s4),
          child: Wrap(
            spacing: PsSpace.s2,
            runSpacing: PsSpace.s2,
            children: [
              if (engine.voiceCount > 0)
                PsTag(l.engineVoices(engine.voiceCount), icon: PsIcons.voice),
              if (engine.traits.contains(EngineTrait.voiceDesign))
                PsTag(l.traitVoiceDesign, icon: PsIcons.pen),
              for (final trait in performed)
                PsTag(Labels.trait(l, trait), tone: PsTagTone.jade),
              if (performed.isEmpty)
                Text(
                  l.engineAbilitiesPlain,
                  style: PsType.subhead.copyWith(color: p.ink2),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A provider's page: what it does, its fields in groups, deleting its key
/// last and apart, and a save bar that rises once something has changed.
/// Saving returns to settings; leaving with unsaved edits asks first.
class _FormScaffold extends StatefulWidget {
  const _FormScaffold({
    required this.title,
    required this.note,
    required this.dirty,
    required this.onSave,
    required this.deleteKeyBody,
    required this.onDeleteKey,
    required this.children,
  });

  final String title;
  final String note;
  final bool dirty;

  /// False when something entered needs fixing first, which the page then
  /// shows beside its field; throws when saving failed.
  final Future<bool> Function() onSave;

  /// What stops working once the key is gone.
  final String deleteKeyBody;

  /// Deletes the stored key at once; null while none is stored.
  final Future<void> Function()? onDeleteKey;
  final List<Widget> children;

  @override
  State<_FormScaffold> createState() => _FormScaffoldState();
}

class _FormScaffoldState extends State<_FormScaffold> {
  final _scroll = ScrollController();
  var _scrolled = false;
  var _saving = false;
  var _saveFailed = false;
  var _deleteFailed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scroll.offset > 40;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      if (!await widget.onSave() || !mounted) return;
      showPsToast(context, l.saved);
      Navigator.of(context).pop();
    } catch (_) {
      // The cause may quote a key or a server reply, so none of it shows.
      if (mounted) setState(() => _saveFailed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteKey() async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PsDialog(
        title: l.deleteKeyTitle,
        body: Text(widget.deleteKeyBody),
        actions: [
          PsButton(
            label: l.deleteKey,
            variant: PsButtonVariant.danger,
            expand: true,
            onPressed: () => Navigator.pop(context, true),
          ),
          PsButton(
            label: l.cancel,
            variant: PsButtonVariant.ghost,
            expand: true,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleteFailed = false);
    try {
      await widget.onDeleteKey!();
      if (mounted) showPsToast(context, l.keyDeleted);
    } catch (_) {
      if (mounted) setState(() => _deleteFailed = true);
    }
  }

  Future<bool> _discard() async {
    final l = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => PsDialog(
        title: l.discardTitle,
        actions: [
          PsButton(
            label: l.discardConfirm,
            variant: PsButtonVariant.danger,
            expand: true,
            onPressed: () => Navigator.pop(context, true),
          ),
          PsButton(
            label: l.keepEditing,
            variant: PsButtonVariant.ghost,
            expand: true,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _onPop(bool didPop, Object? _) async {
    if (didPop || _saving) return;
    if (await _discard() && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final bar = widget.dirty || _saveFailed;
    return PopScope(
      canPop: !widget.dirty,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        body: Column(
          children: [
            PsNavBar(
              back: true,
              backLabel: l.settings,
              title: widget.title,
              showTitle: _scrolled,
              divider: _scrolled,
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  bottom:
                      PsSpace.s10 +
                      (bar ? 0 : MediaQuery.paddingOf(context).bottom),
                ),
                children: [
                  PsLargeTitle(widget.title, subtitle: widget.note),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PsSpace.s4,
                      PsSpace.s4,
                      PsSpace.s4,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: PsSpace.s8,
                      children: [
                        ...widget.children,
                        if (widget.onDeleteKey != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: PsSpace.s3,
                            children: [
                              PsListGroup(
                                children: [
                                  PsListRow(
                                    key: const ValueKey('deleteKey'),
                                    title: l.deleteKey,
                                    destructive: true,
                                    onTap: _saving ? null : _deleteKey,
                                  ),
                                ],
                              ),
                              if (_deleteFailed)
                                PsBanner(
                                  tone: PsBannerTone.danger,
                                  title: l.keyDeleteFailed,
                                  onClose: () =>
                                      setState(() => _deleteFailed = false),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: PsMotion.base,
              curve: PsMotion.standard,
              alignment: Alignment.topCenter,
              child: !bar
                  ? const SizedBox(width: double.infinity)
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.paper,
                        border: Border(top: BorderSide(color: p.rule)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            PsSpace.s5,
                            PsSpace.s3,
                            PsSpace.s5,
                            PsSpace.s3,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: PsSpace.s3,
                            children: [
                              if (_saveFailed)
                                PsBanner(
                                  tone: PsBannerTone.danger,
                                  title: l.saveFailed,
                                  body: l.saveFailedBody,
                                  onClose: () =>
                                      setState(() => _saveFailed = false),
                                ),
                              PsButton(
                                label: l.save,
                                variant: PsButtonVariant.primary,
                                expand: true,
                                loading: _saving,
                                onPressed: widget.dirty ? _save : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One field of a provider form: a small label, the value or control under
/// it, and what is wrong with it, if anything.
class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.child,
    this.badge,
    this.error,
    this.onTap,
  });

  final String label;
  final Widget child;

  /// A [PsTag] at the end of the label line.
  final Widget? badge;
  final String? error;

  /// Tapping anywhere in the row, such as to focus its text field.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final message = error;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PsSpace.s4,
          PsSpace.s3,
          PsSpace.s4,
          PsSpace.s3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            SizedBox(
              height: 20,
              child: Row(
                spacing: PsSpace.s2,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: PsType.subhead.copyWith(
                        color: message == null ? p.ink2 : p.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ?badge,
                ],
              ),
            ),
            Semantics(label: label, child: child),
            if (message != null)
              Row(
                spacing: 6,
                children: [
                  PsIcon(PsIcons.alert, size: 14, color: p.danger),
                  Expanded(
                    child: Text(
                      message,
                      style: PsType.subhead.copyWith(color: p.danger),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// URLs, model names and keys are set in mono, as the reader copies them.
TextStyle _valueStyle(PsPalette p) =>
    PsType.style(PsFonts.mono, 14, 22, FontWeight.w400).copyWith(color: p.ink);

/// A text field without its own frame: the group around it is the frame.
/// The hint is a step lighter than ink-2 so it never passes for a value.
InputDecoration _bare(PsPalette p, String hint) => InputDecoration(
  hintText: hint,
  hintStyle: PsType.body.copyWith(color: p.inkWaiting, height: 22 / 15),
  isDense: true,
  filled: false,
  contentPadding: const EdgeInsets.symmetric(vertical: PsSpace.s1),
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
);

class _TextRow extends StatefulWidget {
  const _TextRow({
    required this.id,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.wrap = false,
    this.error,
    this.onChanged,
  });

  /// Names the field for tests.
  final String id;
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  /// Shows a long value whole, over up to three lines, such as an address.
  final bool wrap;
  final String? error;
  final VoidCallback? onChanged;

  @override
  State<_TextRow> createState() => _TextRowState();
}

class _TextRowState extends State<_TextRow> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return _FieldRow(
      label: widget.label,
      error: widget.error,
      onTap: _focus.requestFocus,
      child: TextField(
        key: ValueKey(widget.id),
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        minLines: 1,
        maxLines: widget.wrap ? 3 : 1,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enableSuggestions: false,
        style: _valueStyle(p),
        decoration: _bare(p, widget.hint),
        onChanged: (_) => widget.onChanged?.call(),
      ),
    );
  }
}

/// A key typed into the page. The stored key never comes back to the
/// screen: with one stored, nothing is typed until the reader chooses to
/// replace it, and leaving the field empty keeps it.
class _KeyDraft extends ChangeNotifier {
  _KeyDraft() {
    text.addListener(notifyListeners);
    focus.addListener(_onFocus);
  }

  final text = TextEditingController();
  final focus = FocusNode();
  var replacing = false;
  var visible = false;

  /// What to pass to [Providers.configure]: null keeps the stored key.
  String? get change {
    final value = text.text.trim();
    return value.isEmpty ? null : value;
  }

  void replace() {
    replacing = true;
    notifyListeners();
  }

  void toggleVisible() {
    visible = !visible;
    notifyListeners();
  }

  /// A replacement left empty folds back to the stored key.
  void _onFocus() {
    if (!focus.hasFocus && replacing && change == null) {
      replacing = false;
      visible = false;
      text.clear();
      notifyListeners();
    }
  }

  Future<void> paste() async {
    final pasted = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    final value = pasted?.trim() ?? '';
    if (value.isEmpty) return;
    text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void dispose() {
    text.dispose();
    focus.dispose();
    super.dispose();
  }
}

/// A masked key: dots and 更换 while one is stored, otherwise a field with
/// 粘贴, which turns into 显示 / 隐藏 once something is typed.
class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.id,
    required this.label,
    required this.draft,
    required this.stored,
  });

  /// The engine's id, naming the field for tests.
  final String id;
  final String label;
  final _KeyDraft draft;
  final bool stored;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        Widget action(String text, VoidCallback onPressed) => PsButton(
          label: text,
          variant: PsButtonVariant.ghost,
          small: true,
          onPressed: onPressed,
        );
        final editing = !stored || draft.replacing;
        return _FieldRow(
          label: label,
          badge: stored ? PsTag(l.keySaved, tone: PsTagTone.jade) : null,
          onTap: editing ? draft.focus.requestFocus : draft.replace,
          child: Row(
            spacing: PsSpace.s2,
            children: [
              Expanded(
                child: editing
                    ? TextField(
                        key: ValueKey('key-$id'),
                        controller: draft.text,
                        focusNode: draft.focus,
                        // Only once 更换 is chosen; never on arrival.
                        autofocus: stored,
                        obscureText: !draft.visible,
                        autocorrect: false,
                        enableSuggestions: false,
                        keyboardType: TextInputType.visiblePassword,
                        style: _valueStyle(p),
                        decoration: _bare(p, stored ? l.newKeyHint : l.keyHint),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: PsSpace.s1,
                        ),
                        child: Text(
                          '•' * 12,
                          semanticsLabel: l.keySaved,
                          style: _valueStyle(p).copyWith(color: p.ink2),
                        ),
                      ),
              ),
              if (!editing)
                action(l.replaceKey, draft.replace)
              else if (draft.text.text.isEmpty)
                action(l.pasteKey, draft.paste)
              else
                action(
                  draft.visible ? l.hideKey : l.showKey,
                  draft.toggleVisible,
                ),
            ],
          ),
        );
      },
    );
  }
}
