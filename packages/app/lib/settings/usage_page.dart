import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/app_scope.dart';
import '../listening/labels.dart';

/// What each provider reported spending, per book, in its own units:
/// tokens for the language model, characters for voices. Nothing is
/// estimated or priced; the provider's bill is the reckoning.
class UsagePage extends StatefulWidget {
  const UsagePage({super.key, required this.generation});

  final Generation generation;

  @override
  State<UsagePage> createState() => _UsagePageState();
}

class _UsagePageState extends State<UsagePage> {
  List<BookUsage>? _usage;
  Map<String, String> _titles = const {};
  var _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_usage == null && !_failed) _load();
  }

  Future<void> _load() async {
    final bookshelf = AppScope.of(context).bookshelf;
    try {
      final usage = await widget.generation.usage();
      final books = await bookshelf.books();
      if (!mounted) return;
      setState(() {
        _usage = usage;
        _titles = {for (final b in books) b.id: b.title};
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final usage = _usage;
    return Scaffold(
      body: Column(
        children: [
          PsNavBar(back: true, backLabel: l.settings, title: l.usage),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                bottom: PsSpace.s10 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                PsLargeTitle(l.usage),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: PsSpace.s4),
                  child: _failed
                      ? PsBanner(
                          tone: PsBannerTone.danger,
                          title: l.usageLoadFailed,
                        )
                      : usage == null
                      ? const Padding(
                          padding: EdgeInsets.all(PsSpace.s8),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : usage.isEmpty
                      ? Text(
                          l.usageEmpty,
                          style: PsType.body.copyWith(color: p.ink2),
                        )
                      : PsListGroup(
                          footer: l.usageNote,
                          children: [
                            for (final book in usage)
                              PsListRow(
                                title: book.bookId.isEmpty
                                    ? l.usageEarlier
                                    : _titles[book.bookId] ??
                                          l.usageDeletedBook,
                                subtitle: usageSummary(l, book),
                                subtitleMaxLines: 3,
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

/// 大模型 12.3 万 tokens · MiniMax 8,400 字, in the reader's language.
String usageSummary(AppLocalizations l, BookUsage usage) {
  final parts = [
    if (usage.tokens > 0)
      l.usageTokens(Labels.provider(l, 'llm'), compactCount(l, usage.tokens)),
    for (final entry in usage.characters.entries)
      l.usageCharacters(
        Labels.provider(l, entry.key),
        compactCount(l, entry.value),
      ),
  ];
  return parts.isEmpty ? l.usageNothingBilled : parts.join(' · ');
}

/// 8,400 or 12.3 万 in Chinese; 8.4K or 123K in English.
String compactCount(AppLocalizations l, int count) {
  final chinese = l.localeName.startsWith('zh');
  if (chinese) {
    if (count >= 100000000) {
      return '${(count / 100000000).toStringAsFixed(1)} 亿';
    }
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)} 万';
  } else {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return '$count';
}
