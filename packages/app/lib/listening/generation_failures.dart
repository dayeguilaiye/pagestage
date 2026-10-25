import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'app_scope.dart';
import 'labels.dart';

/// Why generating [bookId]'s audio has paused, with a way to resume. Sits
/// in the page without interrupting what is playing; nothing when there is
/// no failure or no generation service.
class GenerationFailures extends StatefulWidget {
  const GenerationFailures({
    super.key,
    required this.bookId,
    this.padding = EdgeInsets.zero,
  });

  final String bookId;
  final EdgeInsets padding;

  @override
  State<GenerationFailures> createState() => _GenerationFailuresState();
}

class _GenerationFailuresState extends State<GenerationFailures> {
  var _resuming = false;
  var _resumeFailed = false;

  Future<void> _resume(Generation generation) async {
    setState(() {
      _resuming = true;
      _resumeFailed = false;
    });
    try {
      await generation.resume(widget.bookId);
    } catch (_) {
      if (mounted) setState(() => _resumeFailed = true);
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final generation = AppScope.servicesOf(context)?.generation;
    if (generation == null) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: generation,
      builder: (context, state, _) {
        final failures = [
          for (final f in state.failures)
            if (f.bookId == widget.bookId) f,
        ]..sort((a, b) => a.chapter.compareTo(b.chapter));
        if (failures.isEmpty) return const SizedBox.shrink();
        final l = AppLocalizations.of(context);
        return Padding(
          padding: widget.padding,
          child: PsBanner(
            tone: _resumeFailed ? PsBannerTone.danger : PsBannerTone.amber,
            title: _resumeFailed
                ? l.generationResumeFailed
                : l.generationPausedTitle,
            body: [
              for (final f in failures)
                l.generationPausedLine(
                  l.chapterNumber(f.chapter),
                  Labels.provider(l, f.provider),
                  Labels.pauseReason(l, f.reason),
                ),
            ].join('\n'),
            actionLabel: l.resumeGeneration,
            onAction: _resuming ? null : () => _resume(generation),
          ),
        );
      },
    );
  }
}
