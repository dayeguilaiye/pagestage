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

/// How much room each book takes and how much clearing its audio would
/// free. Clearing keeps the text, scripts and cast; audio is made again
/// when it is next needed.
class StoragePage extends StatefulWidget {
  const StoragePage({super.key, required this.storage});

  final AudioStorage storage;

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  List<BookStorageUsage>? _books;
  var _loadFailed = false;
  var _loads = 0;
  String? _clearing;
  var _clearFailed = false;

  @override
  void initState() {
    super.initState();
    widget.storage.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.storage.removeListener(_load);
    super.dispose();
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
    final books = _books;
    final total = books?.fold<int>(0, (sum, b) => sum + b.totalBytes) ?? 0;
    final audio = books?.fold<int>(0, (sum, b) => sum + b.audioBytes) ?? 0;
    return Scaffold(
      body: Column(
        children: [
          PsNavBar(back: true, backLabel: l.settings, title: l.storage),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: PsSpace.s8 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                PsLargeTitle(l.storage, subtitle: l.storageNote),
                if (books == null && _loadFailed)
                  Padding(
                    padding: const EdgeInsets.all(PsSpace.s5),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PsSpace.s5,
                      0,
                      PsSpace.s5,
                      PsSpace.s6,
                    ),
                    child: Row(
                      spacing: PsSpace.s4,
                      children: [
                        Expanded(
                          child: _Figure(
                            label: l.storageTotal,
                            value: formatBytes(total),
                          ),
                        ),
                        Expanded(
                          child: _Figure(
                            label: l.storageAudio,
                            value: formatBytes(audio),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_clearFailed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        PsSpace.s5,
                        0,
                        PsSpace.s5,
                        PsSpace.s4,
                      ),
                      child: PsBanner(
                        tone: PsBannerTone.danger,
                        title: l.clearAudioFailed,
                        onClose: () => setState(() => _clearFailed = false),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PsSpace.s5),
                    child: PsListGroup(
                      header: l.storageBooks,
                      footer: l.clearAudioNote,
                      children: [
                        for (final book in books)
                          PsListRow(
                            key: ValueKey(book.bookId),
                            title: book.title,
                            subtitle: l.storageBookLine(
                              formatBytes(book.totalBytes),
                              formatBytes(book.audioBytes),
                            ),
                            trailing: PsButton(
                              label: l.clearAudio,
                              small: true,
                              loading: _clearing == book.bookId,
                              onPressed:
                                  book.audioBytes > 0 && _clearing == null
                                  ? () => _clear(book)
                                  : null,
                            ),
                          ),
                      ],
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

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.ps;
    return Container(
      padding: const EdgeInsets.all(PsSpace.s4),
      decoration: BoxDecoration(
        color: p.paperRaised,
        borderRadius: BorderRadius.circular(PsRadius.md),
        border: Border.all(color: p.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: PsSpace.s1,
        children: [
          Text(label, style: PsType.caption.copyWith(color: p.ink2)),
          Text(
            value,
            style: PsType.style(
              PsFonts.mono,
              22,
              28,
              FontWeight.w500,
            ).copyWith(color: p.ink),
          ),
        ],
      ),
    );
  }
}
