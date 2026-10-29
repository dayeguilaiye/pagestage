import 'dart:async';

import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';

/// 1.2 MB, 340 KB, 2.1 GB.
String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 || value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

/// How much room the books take and how much of it is audio, which can be
/// cleared book by book. Clearing keeps the text, scripts and cast; audio is
/// made again when it is next needed.
class StoragePage extends StatefulWidget {
  const StoragePage({super.key, required this.storage});

  final AudioStorage storage;

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  final _scroll = ScrollController();
  var _scrolled = false;
  List<BookStorageUsage>? _books;
  var _loadFailed = false;
  var _loads = 0;
  Timer? _remeasure;
  String? _clearing;
  var _clearFailed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.storage.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _remeasure?.cancel();
    widget.storage.removeListener(_onChanged);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final scrolled = _scroll.offset > 40;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
  }

  /// Generation writes with every voiced line, and measuring walks every
  /// audio file, so changes wait and are measured together.
  void _onChanged() {
    _remeasure ??= Timer(const Duration(seconds: 2), () {
      _remeasure = null;
      _load();
    });
  }

  Future<void> _load() async {
    final load = ++_loads;
    try {
      final books = await widget.storage.usage();
      if (!mounted || load != _loads) return;
      setState(() {
        _books = [...books]
          ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted || load != _loads) return;
      setState(() => _loadFailed = true);
    }
  }

  Future<void> _clear(BookStorageUsage book) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => PsDialog(
        title: l.clearAudioTitle(book.title),
        body: Text(l.clearAudioBody(formatBytes(book.audioBytes))),
        actions: [
          PsButton(
            label: l.clearAudioConfirm,
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
    setState(() {
      _clearing = book.bookId;
      _clearFailed = false;
    });
    try {
      await widget.storage.clearAudio(book.bookId);
      if (mounted) showPsToast(context, l.audioCleared(book.title));
    } catch (_) {
      if (mounted) setState(() => _clearFailed = true);
    } finally {
      if (mounted) setState(() => _clearing = null);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final books = _books;
    return Scaffold(
      body: Column(
        children: [
          PsNavBar(
            back: true,
            backLabel: l.settings,
            title: l.storage,
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
                PsLargeTitle(l.storage),
                if (books == null && _loadFailed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PsSpace.s4),
                    child: PsBanner(
                      tone: PsBannerTone.danger,
                      title: l.storageLoadFailed,
                      actionLabel: l.retry,
                      onAction: _load,
                    ),
                  )
                else if (books == null)
                  const Padding(
                    padding: EdgeInsets.all(PsSpace.s8),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (books.isEmpty)
                  PsEmptyState(title: l.storageEmpty)
                else ...[
                  _Summary(
                    total: books.fold(0, (n, b) => n + b.totalBytes),
                    audio: books.fold(0, (n, b) => n + b.audioBytes),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PsSpace.s4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: PsSpace.s3,
                      children: [
                        if (_clearFailed)
                          PsBanner(
                            tone: PsBannerTone.danger,
                            title: l.clearAudioFailed,
                            onClose: () => setState(() => _clearFailed = false),
                          ),
                        PsListGroup(
                          header: l.storageBooks,
                          footer: l.clearAudioNote,
                          children: [
                            for (final book in books)
                              _BookRow(
                                key: ValueKey(book.bookId),
                                book: book,
                                clearing: _clearing == book.bookId,
                                onClear:
                                    book.audioBytes > 0 && _clearing == null
                                    ? () => _clear(book)
                                    : null,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PsSpace.s8,
                      PsSpace.s6,
                      PsSpace.s8,
                      0,
                    ),
                    child: Text(
                      l.storageCountNote,
                      style: PsType.caption.copyWith(
                        color: p.ink2,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The space in use in one large figure, and how much of it is audio.
class _Summary extends StatelessWidget {
  const _Summary({required this.total, required this.audio});

  final int total;
  final int audio;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final share = total <= 0 ? 0.0 : (audio / total).clamp(0.0, 1.0);
    Widget legend(Color color, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        Text(text, style: PsType.subhead.copyWith(color: p.ink2)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(PsSpace.s5, 0, PsSpace.s5, PsSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.storageTotal, style: PsType.subhead.copyWith(color: p.ink2)),
          Text(formatBytes(total), style: PsType.figure.copyWith(color: p.ink)),
          const SizedBox(height: PsSpace.s3),
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PsRadius.full),
              child: SizedBox(
                height: 6,
                child: ColoredBox(
                  color: p.ruleStrong,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: share,
                    child: ColoredBox(color: p.ink),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: PsSpace.s3),
          Wrap(
            spacing: PsSpace.s5,
            runSpacing: PsSpace.s1,
            children: [
              legend(p.ink, l.storageAudioPart(formatBytes(audio))),
              legend(
                p.ruleStrong,
                l.storageOtherPart(formatBytes(total - audio)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  const _BookRow({
    super.key,
    required this.book,
    required this.clearing,
    required this.onClear,
  });

  final BookStorageUsage book;
  final bool clearing;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final total = formatBytes(book.totalBytes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PsSpace.s4,
        PsSpace.s3,
        PsSpace.s3,
        PsSpace.s3,
      ),
      child: Row(
        spacing: PsSpace.s3,
        children: [
          PsBookCover(title: book.title, width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PsType.style(
                    psHasCjk(book.title) ? PsFonts.serif : PsFonts.serifEn,
                    16,
                    22,
                    FontWeight.w600,
                  ).copyWith(color: p.ink),
                ),
                Text(
                  book.audioBytes > 0
                      ? l.storageBookLine(total, formatBytes(book.audioBytes))
                      : l.storageBookNoAudio(total),
                  style: PsType.subhead.copyWith(color: p.ink2),
                ),
              ],
            ),
          ),
          PsButton(
            label: l.clearAudio,
            small: true,
            loading: clearing,
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
