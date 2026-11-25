import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../cast/cast_page.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/app_scope.dart';
import '../settings/open_settings.dart';
import '../settings/usage_page.dart';
import 'bookshelf.dart';
import 'prepare_sheet.dart';

/// How one book sounds: AI voices or the system voice, and how the AI
/// voices perform. Everything here applies to this book only.
Future<void> showVoiceSheet(
  BuildContext context, {
  required ShelfBook book,
  required List<ChapterEntry> chapters,
}) => showPsSheet<void>(
  context,
  scrollControlled: true,
  builder: (_) => VoiceSheet(book: book, chapters: chapters),
);

class VoiceSheet extends StatefulWidget {
  const VoiceSheet({super.key, required this.book, required this.chapters});

  final ShelfBook book;
  final List<ChapterEntry> chapters;

  @override
  State<VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<VoiceSheet> {
  BookVoice? _voice;
  BookUsage? _usage;
  BookPerformanceMode? _mode;
  BookExpressiveness? _expressiveness;
  var _busy = false;
  var _failed = false;

  Generation get _generation => AppScope.servicesOf(context)!.generation!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_voice == null) _load();
  }

  Future<void> _load() async {
    try {
      final generation = _generation;
      final voice = await generation.voice(widget.book.id);
      final mode = await generation.mode(widget.book.id);
      final expressiveness = await generation.expressiveness(widget.book.id);
      BookUsage? usage;
      try {
        usage = (await generation.usage())
            .where((u) => u.bookId == widget.book.id)
            .firstOrNull;
      } catch (_) {
        // Without it the sheet simply says nothing about spending.
      }
      if (!mounted) return;
      setState(() {
        _usage = usage;
        _voice = voice;
        _mode = mode;
        _expressiveness = expressiveness;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  Future<void> _setAi(bool on) => _run(() async {
    final generation = _generation;
    // Turning AI voices on is the moment to agree to sending the text, not
    // the middle of a chapter later.
    if (on && !await generation.allow(widget.book.id)) return;
    await generation.setAiVoice(widget.book.id, on);
  });

  void _openCast() {
    final services = AppScope.servicesOf(context)!;
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CastPage(
          services: services,
          book: widget.book,
          chapters: widget.chapters,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final voice = _voice;
    final note = PsType.caption.copyWith(
      color: p.ink2,
      fontWeight: FontWeight.w400,
    );
    return PsSheet(
      title: l.voiceSettings,
      subtitle: widget.book.title,
      onClose: () => Navigator.pop(context),
      // Taller than a small phone once AI voices are on: it scrolls.
      fill: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          PsSpace.s5,
          0,
          PsSpace.s5,
          PsSpace.s6 + MediaQuery.paddingOf(context).bottom,
        ),
        child: _content(l, p, voice, note),
      ),
    );
  }

  Widget _content(
    AppLocalizations l,
    PsPalette p,
    BookVoice? voice,
    TextStyle note,
  ) {
    return voice == null
        ? Padding(
            padding: const EdgeInsets.all(PsSpace.s6),
            child: Center(
              child: _failed
                  ? Text(l.voiceSettingsFailed)
                  : const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: PsSpace.s4,
            children: [
              if (voice.sample)
                PsBanner(
                  icon: PsIcons.voice,
                  title: l.sampleVoicedTitle,
                  body: l.sampleVoicedBody,
                )
              else ...[
                if (!voice.enabled)
                  PsBanner(
                    tone: PsBannerTone.amber,
                    title: l.aiVoicesOffEverywhere,
                    actionLabel: l.openSettings,
                    onAction: () => openSettings(context),
                  ),
                PsListGroup(
                  footer: l.aiVoiceForBookNote,
                  children: [
                    MergeSemantics(
                      child: PsListRow(
                        title: l.aiVoiceForBook,
                        trailing: Switch(
                          key: const ValueKey('bookAiVoice'),
                          value: voice.ai,
                          onChanged: _busy ? null : _setAi,
                        ),
                        onTap: _busy ? null : () => _setAi(!voice.ai),
                      ),
                    ),
                  ],
                ),
                if (voice.ai && voice.gap != null)
                  SetupGapBanner(gap: voice.gap!),
                if (voice.profileNeeded case final chapter?)
                  ProfileNeededBanner(
                    bookId: widget.book.id,
                    chapter: chapter,
                    profiledThrough: voice.profiledThrough,
                    onDone: _load,
                  ),
                if (voice.ai) ...[
                  _performance(l, p),
                  Text(l.performanceChangeNote, style: note),
                  PsListGroup(
                    children: [
                      PsListRow(
                        title: l.prepareAhead,
                        subtitle: l.prepareAheadNote,
                        chevron: true,
                        onTap: () {
                          final generation = _generation;
                          Navigator.pop(context);
                          showPrepareSheet(
                            context,
                            book: widget.book,
                            chapters: widget.chapters,
                            generation: generation,
                          );
                        },
                      ),
                      PsListRow(
                        key: const ValueKey('stopPreparing'),
                        title: l.stopPreparing,
                        subtitle: l.stopPreparingNote,
                        onTap: _busy
                            ? null
                            : () => _run(
                                () => _generation.stopPreparing(widget.book.id),
                              ),
                      ),
                    ],
                  ),
                ],
              ],
              if (_usage case final usage? when !voice.sample)
                Text(l.bookUsageLine(usageSummary(l, usage)), style: note),
              PsListGroup(
                children: [
                  PsListRow(
                    title: l.cast,
                    subtitle: l.castRowNote,
                    chevron: true,
                    onTap: _openCast,
                  ),
                ],
              ),
              if (_failed)
                PsBanner(
                  tone: PsBannerTone.danger,
                  title: l.saveFailed,
                  onClose: () => setState(() => _failed = false),
                ),
            ],
          );
  }

  /// Whether tags like 他说 are read, and how strongly the voices act.
  Widget _performance(AppLocalizations l, PsPalette p) {
    final mode = _mode ?? BookPerformanceMode.audiobook;
    final expressiveness = _expressiveness ?? BookExpressiveness.natural;
    void readTags(bool on) => _run(
      () => _generation.setMode(
        widget.book.id,
        on ? BookPerformanceMode.audiobook : BookPerformanceMode.drama,
      ),
    );
    return PsListGroup(
      children: [
        MergeSemantics(
          child: PsListRow(
            title: l.readDialogueTags,
            subtitle: l.readDialogueTagsNote,
            trailing: Switch(
              key: const ValueKey('readTags'),
              value: mode == BookPerformanceMode.audiobook,
              onChanged: _busy ? null : readTags,
            ),
            onTap: _busy
                ? null
                : () => readTags(mode != BookPerformanceMode.audiobook),
          ),
        ),
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
                l.expressiveness,
                style: PsType.rowTitle.copyWith(color: p.ink),
              ),
              Semantics(
                label: l.expressiveness,
                child: PsSegmentedControl<BookExpressiveness>(
                  key: const ValueKey('expressiveness'),
                  expand: true,
                  value: expressiveness,
                  onChanged: (value) => _run(
                    () => _generation.setExpressiveness(widget.book.id, value),
                  ),
                  segments: [
                    PsSegment(BookExpressiveness.plain, l.expressivenessPlain),
                    PsSegment(
                      BookExpressiveness.natural,
                      l.expressivenessNatural,
                    ),
                    PsSegment(
                      BookExpressiveness.dramatic,
                      l.expressivenessDramatic,
                    ),
                  ],
                ),
              ),
              Text(
                switch (expressiveness) {
                  BookExpressiveness.plain => l.expressivenessPlainNote,
                  BookExpressiveness.natural => l.expressivenessNaturalNote,
                  BookExpressiveness.dramatic => l.expressivenessDramaticNote,
                },
                style: PsType.caption.copyWith(
                  color: p.ink2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What AI voices still need, with the one button that sets it up.
class SetupGapBanner extends StatelessWidget {
  const SetupGapBanner({super.key, required this.gap});

  final VoiceSetupGap gap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.servicesOf(context);
    final free = services?.providers.value.voiceEngines
        .where((e) => e.ready && !e.on && e.settings.isEmpty)
        .firstOrNull;
    return switch (gap) {
      VoiceSetupGap.languageModel => PsBanner(
        tone: PsBannerTone.amber,
        icon: PsIcons.key,
        title: l.gapLanguageModelTitle,
        body: l.gapLanguageModelBody,
        actionLabel: l.setupAction,
        onAction: () => openEngine(context, 'llm'),
      ),
      VoiceSetupGap.voiceEngine => PsBanner(
        tone: PsBannerTone.amber,
        icon: PsIcons.voice,
        title: l.gapVoiceTitle,
        body: l.gapVoiceBody,
        actionLabel: free == null ? l.openSettings : l.turnOnEdge,
        onAction: free == null
            ? () => openSettings(context)
            : () => turnOnVoiceEngine(context, free.id),
      ),
    };
  }
}

/// Listening jumped far past the chapters whose characters are known:
/// finding them first sends many chapters, so it waits for a go-ahead.
class ProfileNeededBanner extends StatefulWidget {
  const ProfileNeededBanner({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.profiledThrough,
    this.onDone,
  });

  final String bookId;
  final int chapter;
  final int profiledThrough;
  final VoidCallback? onDone;

  @override
  State<ProfileNeededBanner> createState() => _ProfileNeededBannerState();
}

class _ProfileNeededBannerState extends State<ProfileNeededBanner> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final generation = AppScope.servicesOf(context)?.generation;
    return PsBanner(
      tone: PsBannerTone.amber,
      icon: PsIcons.cast,
      title: l.profileNeededTitle(widget.chapter),
      body: l.profileNeededBody(widget.profiledThrough + 1, widget.chapter),
      actionLabel: l.profileNeededAction,
      onAction: generation == null || _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                if (await generation.allow(widget.bookId)) {
                  await generation.profileThrough(
                    widget.bookId,
                    widget.chapter,
                  );
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
              widget.onDone?.call();
            },
    );
  }
}
