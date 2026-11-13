import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../shelf/reading_settings.dart';
import 'exclusive_voices_sheet.dart';
import '../listening/labels.dart';
import 'feedback_group.dart';
import 'provider_pages.dart';
import 'storage_page.dart';

/// What the reader sets once for the whole app. Their own provider
/// accounts come first and each opens a page of its own; everything below
/// them applies the moment it changes.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.services,
    required this.readingSettings,
  });

  final AppServices services;
  final ReadingSettings readingSettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _scroll = ScrollController();
  var _scrolled = false;

  /// All books together, for the storage row; null until measured.
  int? _storageBytes;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _measureStorage();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Past the large title, the bar shows the small one.
    final scrolled = _scroll.offset > 40;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  /// Measured on arrival and on return from the storage page, not on every
  /// write while audio is being generated.
  Future<void> _measureStorage() async {
    final storage = widget.services.audioStorage;
    if (storage == null) return;
    try {
      final books = await storage.usage();
      if (!mounted) return;
      setState(
        () => _storageBytes = books.fold<int>(0, (n, b) => n + b.totalBytes),
      );
    } catch (_) {
      // The row goes without a figure.
    }
  }

  Future<void> _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = widget.services;
    final storage = services.audioStorage;
    final bytes = _storageBytes;
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
                bottom: PsSpace.s10 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                PsLargeTitle(l.settings),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PsSpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: PsSpace.s8,
                    children: [
                      _ProvidersGroup(
                        providers: services.providers,
                        open: _push,
                      ),
                      if (services.generation case final generation?)
                        _GenerationGroup(generation: generation),
                      _CastingGroup(casts: services.casts),
                      _AppearanceGroup(settings: widget.readingSettings),
                      if (storage != null)
                        PsListGroup(
                          header: l.storageSection,
                          children: [
                            PsListRow(
                              key: const ValueKey('storage'),
                              title: l.storage,
                              detail: bytes == null ? null : formatBytes(bytes),
                              chevron: true,
                              onTap: () async {
                                await _push(StoragePage(storage: storage));
                                await _measureStorage();
                              },
                            ),
                          ],
                        ),
                      if (services.diagnostics case final diagnostics?)
                        FeedbackGroup(diagnostics: diagnostics),
                      PsListGroup(
                        header: l.aboutSection,
                        children: [
                          PsListRow(
                            title: l.licenses,
                            chevron: true,
                            onTap: () => showLicensePage(
                              context: context,
                              applicationName: 'pagestage',
                              applicationIcon: const Padding(
                                padding: EdgeInsets.all(PsSpace.s4),
                                child: PsMark(size: 48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // The end of the page, as a book closes on its last mark.
                const Padding(
                  padding: EdgeInsets.only(top: PsSpace.s12),
                  child: Center(child: PsMark(size: 28, quiet: true)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The engines that do the work: the language model that profiles and
/// directs, then the voice engines with their switches, cloud and on-device
/// apart. The rows come from the engines this build registers. Until
/// profiling can run, or while no voice engine is on, a banner says what to
/// set up first.
class _ProvidersGroup extends StatefulWidget {
  const _ProvidersGroup({required this.providers, required this.open});

  final Providers providers;
  final Future<void> Function(Widget page) open;

  @override
  State<_ProvidersGroup> createState() => _ProvidersGroupState();
}

class _ProvidersGroupState extends State<_ProvidersGroup> {
  var _switchFailed = false;

  static String _host(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host.isEmpty ? url : host;
  }

  Future<void> _change(Future<void> Function() change) async {
    setState(() => _switchFailed = false);
    try {
      await change();
    } catch (_) {
      if (mounted) setState(() => _switchFailed = true);
    }
  }

  void _open(String id) =>
      widget.open(EnginePage(providers: widget.providers, id: id));

  /// Where a language engine stands, as a tag beside its name.
  Widget _languageTag(AppLocalizations l, EngineView engine) {
    switch (engine.status) {
      case EngineStatus.ready:
        return PsTag(l.providerReady, tone: PsTagTone.jade);
      case EngineStatus.unavailable:
        return PsTag(l.engineComingSoon);
      case EngineStatus.notInstalled:
        return PsTag(l.engineNotInstalled, tone: PsTagTone.amber);
      case EngineStatus.needsSetup:
        final hasKey = engine.secrets.isNotEmpty;
        final hasModel = engine.value('profileModel').isNotEmpty;
        return hasKey && !hasModel
            ? PsTag(l.llmNoModel, tone: PsTagTone.amber)
            : hasModel && !hasKey
            ? PsTag(l.llmNoKey, tone: PsTagTone.amber)
            : PsTag(l.providerNotSet);
    }
  }

  /// What a voice engine does, or what it still needs.
  String _voiceSubtitle(AppLocalizations l, EngineView engine) =>
      switch (engine.status) {
        EngineStatus.unavailable => l.engineComingSoon,
        EngineStatus.notInstalled => l.engineNotInstalled,
        EngineStatus.needsSetup => l.voiceNeedsKey,
        EngineStatus.ready => [
          if (engine.id == 'edge') l.edgeRole,
          for (final trait in EngineTrait.values)
            if (engine.traits.contains(trait)) Labels.trait(l, trait),
          if (engine.settings.any((s) => s.name == 'region'))
            Labels.engineOption(l, engine.value('region')),
        ].join(' · '),
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final providers = widget.providers;
    return ValueListenableBuilder(
      valueListenable: providers,
      builder: (context, prefs, _) {
        final language = prefs.language;
        // Choosing between language engines only shows once there is a
        // choice to make.
        final selectable = prefs.languageEngines
            .where((e) => e.status != EngineStatus.unavailable)
            .length;
        // A voice engine that asks for nothing can be turned on right here.
        final free = prefs.voiceEngines
            .where((e) => e.ready && !e.on && e.settings.isEmpty)
            .firstOrNull;
        Widget voiceRow(EngineView engine) => _VoiceRow(
          key: ValueKey('provider-${engine.id}'),
          provider: engine.id,
          title: Labels.provider(l, engine.id),
          subtitle: _voiceSubtitle(l, engine),
          on: engine.on && engine.ready,
          onChanged: engine.ready
              ? (v) => _change(() => providers.switchVoice(engine.id, v))
              : null,
          onOpen: engine.status == EngineStatus.unavailable
              ? null
              : () => _open(engine.id),
        );
        final cloud = prefs.voiceEngines
            .where((e) => e.site == EngineSite.cloud)
            .toList();
        final device = prefs.voiceEngines
            .where((e) => e.site == EngineSite.device)
            .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: PsSpace.s6,
          children: [
            if (!prefs.llmReady && language != null)
              PsBanner(
                icon: PsIcons.key,
                title: l.setupTitle,
                body: l.setupBody,
                actionLabel: l.setupAction,
                onAction: () => _open(language.id),
              )
            else if (prefs.voiceProviders.isEmpty)
              PsBanner(
                icon: PsIcons.voice,
                title: l.noVoiceTitle,
                body: l.noVoiceBody,
                actionLabel: free == null
                    ? null
                    : Labels.sentence(
                        l.turnOnProvider(Labels.inline(l, free.id)),
                      ),
                onAction: free == null
                    ? null
                    : () => _change(() => providers.switchVoice(free.id, true)),
              ),
            PsListGroup(
              header: l.llmSection,
              footer: l.llmSectionNote,
              children: [
                for (final engine in prefs.languageEngines)
                  PsListRow(
                    key: ValueKey('provider-${engine.id}'),
                    title: Labels.engine(l, engine),
                    badge: _languageTag(l, engine),
                    subtitle: engine.value('profileModel').isEmpty
                        ? null
                        : '${engine.value('profileModel')} · '
                              '${_host(engine.value('baseUrl'))}',
                    subtitleMaxLines: 1,
                    detail: engine.on && selectable > 1 ? l.engineInUse : null,
                    trailing:
                        !engine.on && engine.status != EngineStatus.unavailable
                        ? PsButton(
                            key: ValueKey('use-${engine.id}'),
                            label: l.useEngine,
                            small: true,
                            onPressed: () => _change(
                              () => providers.selectLanguage(engine.id),
                            ),
                          )
                        : null,
                    chevron: engine.status != EngineStatus.unavailable,
                    onTap: engine.status == EngineStatus.unavailable
                        ? null
                        : () => _open(engine.id),
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PsSpace.s3,
              children: [
                PsListGroup(
                  header: device.isEmpty ? l.voiceSection : l.voiceSectionCloud,
                  footer: l.voiceSectionNote,
                  children: [for (final engine in cloud) voiceRow(engine)],
                ),
                if (_switchFailed)
                  PsBanner(
                    tone: PsBannerTone.danger,
                    title: l.saveFailed,
                    onClose: () => setState(() => _switchFailed = false),
                  ),
              ],
            ),
            if (device.isNotEmpty)
              PsListGroup(
                header: l.voiceSectionDevice,
                footer: l.voiceSectionDeviceNote,
                children: [for (final engine in device) voiceRow(engine)],
              ),
          ],
        );
      },
    );
  }
}

/// A voice engine: its switch on the right and its page behind the rest of
/// the row. Until it has what it needs the switch stays off.
class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    super.key,
    required this.provider,
    required this.title,
    required this.subtitle,
    required this.on,
    required this.onChanged,
    this.onOpen,
  });

  /// The engine's id, naming the switch for tests.
  final String provider;
  final String title;
  final String subtitle;
  final bool on;

  /// Null while the switch cannot be turned on.
  final ValueChanged<bool>? onChanged;

  /// Opens the engine's page; null for an engine not offered yet.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    final change = onChanged;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  PsSpace.s4,
                  PsSpace.s3,
                  PsSpace.s3,
                  PsSpace.s3,
                ),
                child: Row(
                  spacing: PsSpace.s3,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 1,
                        children: [
                          Text(
                            title,
                            style: PsType.rowTitle.copyWith(color: p.ink),
                          ),
                          Text(
                            subtitle,
                            style: PsType.subhead.copyWith(color: p.ink2),
                          ),
                        ],
                      ),
                    ),
                    if (onOpen != null)
                      PsIcon(
                        PsIcons.chevronRight,
                        size: 20,
                        color: p.ruleStrong,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (onOpen != null) Container(width: 1, height: 32, color: p.rule),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PsSpace.s3),
            child: Semantics(
              label: title,
              child: Switch(
                key: ValueKey('switch-$provider'),
                value: on,
                onChanged: change,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether to generate without asking, and how far ahead of the listener
/// to direct and to synthesize. Each change is saved at once.
class _GenerationGroup extends StatefulWidget {
  const _GenerationGroup({required this.generation});

  final Generation generation;

  static const maxAhead = 20;

  @override
  State<_GenerationGroup> createState() => _GenerationGroupState();
}

class _GenerationGroupState extends State<_GenerationGroup> {
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
        void automatic(bool on) => _save(
          GenerationPreferences(
            automatic: on,
            directing: prefs.directing,
            synthesis: prefs.synthesis,
          ),
        );
        // Audio is made only for chapters already directed, so each
        // lookahead carries the other along instead of refusing.
        void directing(int n) => _save(
          GenerationPreferences(
            automatic: prefs.automatic,
            directing: n,
            synthesis: math.min(prefs.synthesis, n),
          ),
        );
        void synthesis(int n) => _save(
          GenerationPreferences(
            automatic: prefs.automatic,
            directing: math.max(prefs.directing, n),
            synthesis: n,
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: PsSpace.s3,
          children: [
            PsListGroup(
              header: l.generationSection,
              footer: l.generationSectionNote,
              children: [
                MergeSemantics(
                  child: PsListRow(
                    title: l.autoGenerate,
                    subtitle: l.autoGenerateNote,
                    trailing: Switch(
                      key: const ValueKey('autoGenerate'),
                      value: prefs.automatic,
                      onChanged: automatic,
                    ),
                    onTap: () => automatic(!prefs.automatic),
                  ),
                ),
                PsListRow(
                  title: l.directingAhead,
                  subtitle: l.directingAheadNote,
                  trailing: PsStepper(
                    value: prefs.directing,
                    max: _GenerationGroup.maxAhead,
                    unit: l.aheadUnit,
                    decreaseLabel: l.fewerDirectingAhead,
                    increaseLabel: l.moreDirectingAhead,
                    onChanged: directing,
                  ),
                ),
                PsListRow(
                  title: l.synthesisAhead,
                  subtitle: l.synthesisAheadNote,
                  trailing: PsStepper(
                    value: prefs.synthesis,
                    max: _GenerationGroup.maxAhead,
                    unit: l.aheadUnit,
                    decreaseLabel: l.fewerSynthesisAhead,
                    increaseLabel: l.moreSynthesisAhead,
                    onChanged: synthesis,
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

class _CastingGroup extends StatelessWidget {
  const _CastingGroup({required this.casts});

  final Casts casts;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: casts,
      builder: (context, _) => PsListGroup(
        header: l.castingSection,
        footer: l.exclusiveVoicesNote,
        children: [
          PsListRow(
            key: const ValueKey('exclusiveVoices'),
            title: l.exclusiveVoices,
            detail: l.exclusiveVoicesValue(casts.exclusiveCount),
            chevron: true,
            onTap: () => showExclusiveVoicesSheet(context, casts: casts),
          ),
        ],
      ),
    );
  }
}

/// Night mode for the whole app, the same choice the reading sheet offers.
class _AppearanceGroup extends StatelessWidget {
  const _AppearanceGroup({required this.settings});

  final ReadingSettings settings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, prefs, _) => PsListGroup(
        header: l.appearanceSection,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PsSpace.s4,
              PsSpace.s3,
              PsSpace.s4,
              PsSpace.s4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PsSpace.s3,
              children: [
                Text(
                  l.nightMode,
                  style: PsType.rowTitle.copyWith(color: p.ink),
                ),
                Semantics(
                  label: l.nightMode,
                  child: PsSegmentedControl<ThemeMode>(
                    expand: true,
                    value: prefs.themeMode,
                    onChanged: (v) =>
                        settings.update(settings.value.copyWith(themeMode: v)),
                    segments: [
                      PsSegment(ThemeMode.system, l.nightModeSystem),
                      PsSegment(ThemeMode.light, l.nightModeOff),
                      PsSegment(ThemeMode.dark, l.nightModeOn),
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
