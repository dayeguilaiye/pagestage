import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/app_scope.dart';
import '../listening/chapter_picker.dart';
import '../listening/labels.dart';
import '../shelf/bookshelf.dart';
import 'voice_page.dart';

/// A book's cast and how far it has been profiled: start or extend
/// profiling, resume it after a pause, audition each voice.
class CastPage extends StatefulWidget {
  const CastPage({
    super.key,
    required this.services,
    required this.book,
    this.chapters = const [],
    this.initialThrough,
  });

  final AppServices services;
  final ShelfBook book;

  /// A chapter number to preselect for profiling, such as the chapter that
  /// could not be generated.
  final int? initialThrough;

  /// The table of contents, for choosing how far to profile. Loaded here
  /// when empty.
  final List<ChapterEntry> chapters;

  @override
  State<CastPage> createState() => _CastPageState();
}

class _CastPageState extends State<CastPage> {
  final _scroll = ScrollController();
  var _scrolled = false;

  CastState? _cast;
  var _loadFailed = false;
  var _loads = 0;
  late var _chapters = widget.chapters;

  /// The chapter number to profile through, once the reader or a default
  /// has picked one.
  late int? _through = widget.initialThrough;
  var _busy = false;
  var _actionFailed = false;
  var _auditionFailed = false;
  final _expanded = <String>{};

  Casts get _casts => widget.services.casts;
  Voices? get _voices => widget.services.voices;

  /// Providers that can design a voice; empty hides voice design.
  var _designProviders = const <String>[];

  @override
  void initState() {
    super.initState();
    _casts.addListener(_onCasts);
    _voices?.addListener(_onVoices);
    _scroll.addListener(_onScroll);
    _load();
    _loadDesignProviders();
  }

  void _onVoices() => setState(() {});

  Future<void> _loadDesignProviders() async {
    final voices = _voices;
    if (voices == null) return;
    try {
      final providers = await voices.designProviders(widget.book.id);
      if (mounted) setState(() => _designProviders = providers);
    } catch (_) {
      // Without design providers only presets are offered.
    }
  }

  Future<void> _openVoices(CastMember member, VoiceTab tab) async {
    final l = AppLocalizations.of(context);
    final chosen = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VoicePage(
          voices: _voices!,
          bookId: widget.book.id,
          member: member,
          designProviders: _designProviders,
          tab: tab,
        ),
      ),
    );
    if (chosen == true && mounted) {
      showPsToast(context, l.voiceChanged(member.name));
      await _load();
    }
  }

  var _askedForChapters = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Inherited lookups are not allowed in initState; ask once, here.
    if (_chapters.isEmpty && !_askedForChapters) {
      _askedForChapters = true;
      _loadChapters(AppScope.of(context).bookshelf);
    }
  }

  @override
  void dispose() {
    _casts.removeListener(_onCasts);
    _voices?.removeListener(_onVoices);
    // Stopping notifies other pages, which cannot rebuild mid-unmount.
    final casts = _casts;
    if (casts.auditioning != null) Future.microtask(casts.stopAudition);
    _scroll.dispose();
    super.dispose();
  }

  /// The sample playing changes at once; the cast reloads behind it.
  void _onCasts() {
    setState(() {});
    _load();
  }

  void _onScroll() {
    final scrolled = _scroll.offset > 40;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  Future<void> _loadChapters(Bookshelf bookshelf) async {
    try {
      final chapters = await bookshelf.chapters(widget.book.id);
      if (mounted) setState(() => _chapters = chapters);
    } catch (_) {
      // Without the contents the chapter picker stays disabled.
    }
  }

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final cast = await _casts.load(widget.book.id);
      if (!mounted || load != _loads) return;
      setState(() {
        _cast = cast;
        _loadFailed = false;
        final floor = _floor(cast);
        if (_through == null || _through! <= floor) {
          _through = _defaultThrough(cast);
        }
      });
    } catch (_) {
      if (!mounted || load != _loads) return;
      setState(() => _loadFailed = true);
    }
  }

  int _count(CastState cast) =>
      cast.chapterCount > 0 ? cast.chapterCount : _chapters.length;

  bool _working(CastState cast) =>
      cast.status == ProfilingStatus.queued ||
      cast.status == ProfilingStatus.running;

  /// Profiling must reach past this chapter to add anything.
  int _floor(CastState cast) => math.max(
    cast.profiledThrough,
    _working(cast) || cast.status == ProfilingStatus.paused
        ? cast.targetChapter
        : 0,
  );

  int _defaultThrough(CastState cast) {
    final count = _count(cast);
    return math.min(count, _floor(cast) + 10);
  }

  Future<void> _pickThrough(CastState cast) async {
    final l = AppLocalizations.of(context);
    final current = _chapters.indexWhere((c) => c.number == _through);
    final index = await pickChapter(
      context,
      title: l.profileThrough,
      subtitle: widget.book.title,
      chapters: _chapters,
      current: current < 0 ? null : current,
    );
    if (index != null && mounted) {
      setState(() => _through = _chapters[index].number);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _actionFailed = false;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) setState(() => _actionFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  Future<void> _audition(CastMember member) async {
    if (_casts.auditioning == member.id) {
      await _casts.stopAudition();
      return;
    }
    setState(() => _auditionFailed = false);
    try {
      await _casts.audition(widget.book.id, member.id);
    } catch (_) {
      if (mounted) setState(() => _auditionFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cast = _cast;
    return Scaffold(
      body: Column(
        children: [
          PsNavBar(
            back: true,
            backLabel: null,
            title: l.cast,
            showTitle: _scrolled,
            divider: _scrolled,
          ),
          Expanded(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(
                  child: PsLargeTitle(l.cast, subtitle: widget.book.title),
                ),
                if (cast == null && _loadFailed)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(PsSpace.s5),
                      child: PsBanner(
                        tone: PsBannerTone.danger,
                        title: l.castLoadFailed,
                        actionLabel: l.retry,
                        onAction: _load,
                      ),
                    ),
                  )
                else if (cast == null)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(PsSpace.s8),
                      child: Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(child: _profiling(cast, l)),
                  SliverToBoxAdapter(child: _castHeader(cast, l)),
                  if (cast.members.isEmpty)
                    SliverToBoxAdapter(child: _empty(cast, l))
                  else
                    SliverList.builder(
                      itemCount: cast.members.length,
                      itemBuilder: (context, i) => _member(cast.members[i], l),
                    ),
                ],
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: PsSpace.s8 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profiling(CastState cast, AppLocalizations l) {
    final p = context.ps;
    final count = _count(cast);
    final through = _through ?? 0;
    final floor = _floor(cast);
    final whole = count > 0 && cast.profiledThrough >= count;
    final canProfile = !_busy && count > 0 && through > floor;
    final tag = switch (cast.status) {
      ProfilingStatus.idle => null,
      ProfilingStatus.queued => PsTag(l.statusQueued),
      ProfilingStatus.running => PsTag(l.statusRunning, tone: PsTagTone.amber),
      ProfilingStatus.paused => PsTag(l.statusPaused, tone: PsTagTone.danger),
      ProfilingStatus.complete => PsTag(l.statusComplete, tone: PsTagTone.jade),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.s5, 0, PsSpace.s5, PsSpace.s8),
      child: Container(
        padding: const EdgeInsets.all(PsSpace.s4),
        decoration: BoxDecoration(
          color: p.paperRaised,
          borderRadius: BorderRadius.circular(PsRadius.md),
          border: Border.all(color: p.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: PsSpace.s2,
              children: [
                Expanded(
                  child: Text(
                    l.profiling,
                    style: PsType.headline.copyWith(color: p.ink),
                  ),
                ),
                ?tag,
              ],
            ),
            const SizedBox(height: PsSpace.s3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: PsSpace.s2,
              children: [
                Text(
                  '${cast.profiledThrough}',
                  style: PsType.style(
                    PsFonts.mono,
                    28,
                    34,
                    FontWeight.w500,
                  ).copyWith(color: p.ink),
                ),
                Text(
                  '/ $count',
                  style: PsType.numeralLg.copyWith(color: p.ink2),
                ),
                Flexible(
                  child: Text(
                    l.chaptersProfiled,
                    overflow: TextOverflow.ellipsis,
                    style: PsType.subhead.copyWith(color: p.ink2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PsSpace.s2),
            _ProfileBar(
              done: count == 0 ? 0 : cast.profiledThrough / count,
              target: count == 0 ? 0 : cast.targetChapter / count,
            ),
            if (_working(cast) && cast.targetChapter > 0)
              Padding(
                padding: const EdgeInsets.only(top: PsSpace.s2),
                child: Text(
                  cast.status == ProfilingStatus.queued
                      ? l.profilingQueuedTo(cast.targetChapter)
                      : l.profilingRunningTo(cast.targetChapter),
                  style: PsType.subhead.copyWith(color: p.ink2),
                ),
              ),
            if (cast.status == ProfilingStatus.paused)
              Padding(
                padding: const EdgeInsets.only(top: PsSpace.s4),
                child: PsBanner(
                  tone: PsBannerTone.amber,
                  title: l.profilingPausedTitle,
                  body: l.profilingPausedBody(
                    Labels.provider(l, cast.provider),
                    Labels.pauseReason(l, cast.reason),
                  ),
                  actionLabel: l.resumeProfiling,
                  onAction: _busy
                      ? null
                      : () => _run(() => _casts.resume(widget.book.id)),
                ),
              ),
            if (_actionFailed)
              Padding(
                padding: const EdgeInsets.only(top: PsSpace.s4),
                child: PsBanner(
                  tone: PsBannerTone.danger,
                  title: l.profilingActionFailed,
                  onClose: () => setState(() => _actionFailed = false),
                ),
              ),
            const SizedBox(height: PsSpace.s4),
            if (whole)
              Text(
                l.profiledWholeBook,
                style: PsType.subhead.copyWith(color: p.ink2),
              )
            else ...[
              _ThroughRow(
                label: l.profileThrough,
                value: through > 0 ? l.chapterNumber(through) : '—',
                onTap: _chapters.isEmpty ? null : () => _pickThrough(cast),
              ),
              const SizedBox(height: PsSpace.s3),
              PsButton(
                label: cast.profiledThrough == 0 && !_working(cast)
                    ? l.startProfiling
                    : l.extendProfiling,
                variant: PsButtonVariant.primary,
                expand: true,
                loading: _busy,
                onPressed: canProfile
                    ? () => _run(
                        () => _casts.profile(widget.book.id, through: through),
                      )
                    : null,
              ),
              const SizedBox(height: PsSpace.s3),
              Text(
                l.profilingNote,
                style: PsType.caption.copyWith(
                  color: p.ink2,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _castHeader(CastState cast, AppLocalizations l) {
    final p = context.ps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.s5, 0, PsSpace.s5, PsSpace.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.castMembers(cast.members.length),
            style: PsType.subhead.copyWith(
              color: p.ink2,
              fontWeight: FontWeight.w500,
            ),
          ),
          for (final notice in _voices?.notices ?? const <VoiceRebuildNotice>[])
            if (notice.bookId == widget.book.id)
              Padding(
                padding: const EdgeInsets.only(top: PsSpace.s3),
                child: PsBanner(
                  key: ValueKey('notice-${notice.id}'),
                  tone: PsBannerTone.amber,
                  icon: PsIcons.voice,
                  title: l.voiceRebuiltTitle(notice.speakerName),
                  body: l.voiceRebuiltBody(Labels.provider(l, notice.provider)),
                  actionLabel: l.listenAgain,
                  onAction: () =>
                      _casts.audition(widget.book.id, notice.speakerId),
                  onClose: () => _voices!.dismissNotice(notice.id),
                ),
              ),
          if (_auditionFailed)
            Padding(
              padding: const EdgeInsets.only(top: PsSpace.s3),
              child: PsBanner(
                tone: PsBannerTone.danger,
                title: l.auditionFailed,
                onClose: () => setState(() => _auditionFailed = false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(CastState cast, AppLocalizations l) {
    final p = context.ps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.s5, PsSpace.s4, PsSpace.s5, 0),
      child: Text(
        _working(cast) ? l.castEmptyWorking : l.castEmpty,
        style: PsType.body.copyWith(color: p.ink2, height: 23 / 15),
      ),
    );
  }

  Widget _member(CastMember member, AppLocalizations l) {
    final expanded = _expanded.contains(member.id);
    final voice = [
      if (member.voiceName case final name? when name.isNotEmpty) name,
      if (member.provider case final provider? when provider.isNotEmpty)
        Labels.provider(l, provider),
    ];
    return Semantics(
      expanded: expanded,
      child: PsCastRow(
        key: ValueKey(member.id),
        name: member.name,
        narrator: member.kind == CastMemberKind.narrator,
        tag: member.kind == CastMemberKind.provisional
            ? l.castProvisional
            : null,
        subtitle: voice.isEmpty ? l.voiceNotAssigned : voice.join(' · '),
        auditioning: _casts.auditioning == member.id,
        onAudition: () => _audition(member),
        onTap: () => setState(
          () =>
              expanded ? _expanded.remove(member.id) : _expanded.add(member.id),
        ),
        details: expanded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: PsSpace.s4,
                children: [
                  _Profile(member),
                  if (_voices != null)
                    Wrap(
                      spacing: PsSpace.s2,
                      runSpacing: PsSpace.s2,
                      children: [
                        PsButton(
                          label: l.changeVoice,
                          small: true,
                          icon: PsIcons.voice,
                          onPressed: () =>
                              _openVoices(member, VoiceTab.presets),
                        ),
                        if (_designProviders.isNotEmpty)
                          PsButton(
                            label: l.designVoice,
                            small: true,
                            icon: PsIcons.pen,
                            onPressed: () =>
                                _openVoices(member, VoiceTab.design),
                          ),
                      ],
                    ),
                ],
              )
            : null,
      ),
    );
  }
}

/// Profiled chapters in ink, the chapters still to come in a lighter rule.
class _ProfileBar extends StatelessWidget {
  const _ProfileBar({required this.done, required this.target});
  final double done;
  final double target;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    Widget fill(double f, Color color) => FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: f.clamp(0, 1),
      child: ColoredBox(color: color),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PsRadius.full),
        child: SizedBox(
          height: 4,
          child: ColoredBox(
            color: p.rule,
            child: Stack(
              fit: StackFit.expand,
              children: [fill(target, p.ruleStrong), fill(done, p.ink)],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThroughRow extends StatelessWidget {
  const _ThroughRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PsRadius.sm),
        child: Container(
          constraints: const BoxConstraints(minHeight: PsSize.touch),
          padding: const EdgeInsets.symmetric(horizontal: PsSpace.s3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PsRadius.sm),
            border: Border.all(color: p.ruleStrong),
          ),
          child: Row(
            spacing: PsSpace.s2,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: PsType.rowTitle.copyWith(color: p.ink),
                ),
              ),
              Text(value, style: PsType.body.copyWith(color: p.ink2)),
              PsIcon(PsIcons.chevronDown, size: 18, color: p.ruleStrong),
            ],
          ),
        ),
      ),
    );
  }
}

/// The collapsed profile: who the speaker is and how they should sound.
class _Profile extends StatelessWidget {
  const _Profile(this.member);
  final CastMember member;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final rows = [
      (l.profileGender, member.gender),
      (l.profileAge, member.ageGroup),
      (l.profilePersonality, member.personality),
      (l.profileSpeakingStyle, member.speakingStyle),
      (l.profileVoice, member.voiceDescription),
    ].where((r) => r.$2.trim().isNotEmpty).toList();
    if (rows.isEmpty) {
      return Text(
        l.profileEmpty,
        style: PsType.subhead.copyWith(color: p.ink2),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PsSpace.s2,
      children: [
        for (final (label, value) in rows)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(label, style: PsType.caption.copyWith(color: p.ink2)),
              Text(
                value,
                style: PsType.body.copyWith(color: p.ink, height: 21 / 15),
              ),
            ],
          ),
      ],
    );
  }
}
