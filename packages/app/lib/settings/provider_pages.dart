import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';

/// The paid voice providers, each with a key of its own.
enum VoiceProvider { minimax, bailian }

/// The language model's address, protocol, key and models.
class LlmSettingsPage extends StatefulWidget {
  const LlmSettingsPage({super.key, required this.providers});

  final Providers providers;

  @override
  State<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends State<LlmSettingsPage> {
  late final ProviderPreferences _initial = widget.providers.value;
  late final _baseUrl = TextEditingController(text: _initial.baseUrl);
  late final _profileModel = TextEditingController(text: _initial.profileModel);
  late final _directorModel = TextEditingController(
    text: _initial.directorModel,
  );
  late var _protocol = _initial.protocol;
  final _key = _KeyDraft();
  var _urlInvalid = false;

  List<TextEditingController> get _fields => [
    _baseUrl,
    _profileModel,
    _directorModel,
  ];

  @override
  void initState() {
    super.initState();
    for (final field in _fields) {
      field.addListener(_changed);
    }
    _key.addListener(_changed);
    widget.providers.addListener(_changed);
  }

  @override
  void dispose() {
    widget.providers.removeListener(_changed);
    for (final field in _fields) {
      field.dispose();
    }
    _key.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  bool get _dirty {
    final saved = widget.providers.value;
    return _baseUrl.text.trim() != saved.baseUrl ||
        _protocol != saved.protocol ||
        _profileModel.text.trim() != saved.profileModel ||
        _directorModel.text.trim() != saved.directorModel ||
        _key.change != null;
  }

  /// Mirrors what [Providers.save] accepts, so a bad address shows beside
  /// its field instead of failing the save.
  static bool _validUrl(String text) {
    final uri = Uri.tryParse(text);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  Future<bool> _save() async {
    final url = _baseUrl.text.trim();
    if (!_validUrl(url)) {
      setState(() => _urlInvalid = true);
      return false;
    }
    await widget.providers.save(
      widget.providers.value.copyWith(
        baseUrl: url,
        protocol: _protocol,
        profileModel: _profileModel.text.trim(),
        directorModel: _directorModel.text.trim(),
      ),
      llmKey: _key.change,
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final saved = widget.providers.value;
    return _FormScaffold(
      title: l.llm,
      note: l.llmPageNote,
      dirty: _dirty,
      onSave: _save,
      deleteKeyBody: l.deleteLlmKeyBody,
      onDeleteKey: saved.hasLlmKey
          ? () => widget.providers.save(widget.providers.value, llmKey: '')
          : null,
      children: [
        PsListGroup(
          header: l.connectionSection,
          footer: l.llmConnectionNote,
          children: [
            _TextRow(
              id: 'baseUrl',
              label: l.baseUrl,
              controller: _baseUrl,
              hint: const ProviderPreferences().baseUrl,
              keyboardType: TextInputType.url,
              wrap: true,
              error: _urlInvalid ? l.baseUrlInvalid : null,
              onChanged: () {
                if (_urlInvalid) setState(() => _urlInvalid = false);
              },
            ),
            _FieldRow(
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
            _KeyRow(
              id: 'llm',
              label: l.apiKey,
              draft: _key,
              stored: saved.hasLlmKey,
            ),
          ],
        ),
        PsListGroup(
          header: l.modelsSection,
          footer: l.modelsNote,
          children: [
            _TextRow(
              id: 'profileModel',
              label: l.profileModel,
              controller: _profileModel,
              hint: l.modelHint,
            ),
            _TextRow(
              id: 'directorModel',
              label: l.directorModel,
              controller: _directorModel,
              hint: l.sameAsProfileModel,
            ),
          ],
        ),
      ],
    );
  }
}

/// A paid voice provider's key and, for Bailian, its region.
class VoiceProviderPage extends StatefulWidget {
  const VoiceProviderPage({
    super.key,
    required this.provider,
    required this.providers,
  });

  final VoiceProvider provider;
  final Providers providers;

  @override
  State<VoiceProviderPage> createState() => _VoiceProviderPageState();
}

class _VoiceProviderPageState extends State<VoiceProviderPage> {
  late var _region = widget.providers.value.region;
  final _key = _KeyDraft();

  bool get _bailian => widget.provider == VoiceProvider.bailian;

  bool _stored(ProviderPreferences saved) =>
      _bailian ? saved.hasBailianKey : saved.hasMinimaxKey;

  @override
  void initState() {
    super.initState();
    _key.addListener(_changed);
    widget.providers.addListener(_changed);
  }

  @override
  void dispose() {
    widget.providers.removeListener(_changed);
    _key.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  bool get _dirty =>
      _key.change != null ||
      (_bailian && _region != widget.providers.value.region);

  Future<bool> _save() async {
    await widget.providers.save(
      widget.providers.value.copyWith(region: _region),
      minimaxKey: _bailian ? null : _key.change,
      bailianKey: _bailian ? _key.change : null,
    );
    return true;
  }

  Future<void> _deleteKey() => widget.providers.save(
    widget.providers.value,
    minimaxKey: _bailian ? null : '',
    bailianKey: _bailian ? '' : null,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final stored = _stored(widget.providers.value);
    return _FormScaffold(
      title: _bailian ? l.providerBailian : 'MiniMax',
      note: _bailian ? l.bailianPageNote : l.minimaxPageNote,
      dirty: _dirty,
      onSave: _save,
      deleteKeyBody: l.deleteVoiceKeyBody,
      onDeleteKey: stored ? _deleteKey : null,
      children: [
        PsListGroup(
          footer: _bailian ? l.bailianRegionNote : l.minimaxKeyNote,
          children: [
            if (_bailian)
              _FieldRow(
                label: l.region,
                child: PsSegmentedControl<ProviderRegion>(
                  expand: true,
                  value: _region,
                  onChanged: (v) => setState(() => _region = v),
                  segments: [
                    PsSegment(ProviderRegion.beijing, l.regionBeijing),
                    PsSegment(ProviderRegion.singapore, l.regionSingapore),
                  ],
                ),
              ),
            _KeyRow(
              id: widget.provider.name,
              label: l.apiKey,
              draft: _key,
              stored: stored,
            ),
          ],
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

  /// What to pass to [Providers.save]: null keeps the stored key.
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

  /// Names the field for tests: llm, minimax or bailian.
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
