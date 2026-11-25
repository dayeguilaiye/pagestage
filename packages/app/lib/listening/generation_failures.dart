import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../cast/cast_page.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'app_scope.dart';
import '../settings/open_settings.dart';
import 'labels.dart';
import 'off_provider_banner.dart';

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
        final providers = AppScope.servicesOf(context)!.providers;
        return ValueListenableBuilder(
          valueListenable: providers,
          builder: (context, preferences, _) {
            // A voice provider still off or without its key gets its own
            // notice with the fixes; turned on since, it simply resumes.
            final off = offVoiceProviders(preferences, [
              for (final f in failures)
                if (f.reason == 'providerDisabled' || f.reason == 'missingKey')
                  f.provider,
            ]);
            final rest = [
              for (final f in failures)
                if (!off.contains(f.provider)) f,
            ];
            return Padding(
              padding: widget.padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: PsSpace.s3,
                children: [
                  for (final provider in off)
                    OffProviderBanner(
                      key: ValueKey('off-$provider'),
                      bookId: widget.bookId,
                      provider: provider,
                    ),
                  if (rest.isNotEmpty) _paused(context, generation, rest),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCast(BuildContext context) async {
    final scope = AppScope.of(context);
    final services = scope.services;
    if (services == null) return;
    try {
      final book = (await scope.bookshelf.books())
          .where((b) => b.id == widget.bookId)
          .firstOrNull;
      if (book == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CastPage(services: services, book: book),
        ),
      );
    } catch (_) {
      // The book has gone; nothing to fix.
    }
  }

  /// Says what stopped, that listening goes on in the system voice, and
  /// offers the one action that fixes this reason: a settings page for a
  /// key, waiting for a network error, agreeing for consent.
  Widget _paused(
    BuildContext context,
    Generation generation,
    List<GenerationFailure> failures,
  ) {
    final l = AppLocalizations.of(context);
    final first = failures.first;
    final lines = [
      for (final f in failures)
        f.profiling
            ? l.profilingPausedLine(
                Labels.provider(l, f.provider),
                Labels.pauseReason(l, f.reason),
              )
            : l.generationPausedLine(
                l.chapterNumber(f.chapter),
                Labels.provider(l, f.provider),
                Labels.pauseReason(l, f.reason),
              ),
    ];
    final providers = AppScope.servicesOf(context)?.providers;
    final engine = first.provider == 'llm'
        ? providers?.value.language?.id ?? 'llm'
        : first.provider;
    void resume() => _resume(generation);
    final (
      String label,
      VoidCallback action,
      String? note,
    ) = switch (first.reason) {
      'missingKey' ||
      'unauthorized' ||
      'requestRejected' ||
      'schemaUnsupported' ||
      'providerDisabled' ||
      'engineNotInstalled' ||
      'engineUnavailable' => (
        l.checkProviderSettings(Labels.inline(l, first.provider)),
        () => openEngine(context, engine),
        l.resumeAfterFixNote,
      ),
      'rateLimited' || 'network' => (l.retryNow, resume, l.retryingSoon),
      'consentNeeded' || 'consentDeclined' => (l.reviewAndAgree, resume, null),
      'voiceUnavailable' => (
        l.chooseVoices,
        () => _openCast(context),
        l.resumeAfterFixNote,
      ),
      _ => (l.resumeGeneration, resume, null),
    };
    return PsBanner(
      tone: _resumeFailed ? PsBannerTone.danger : PsBannerTone.amber,
      title: _resumeFailed ? l.generationResumeFailed : l.generationPausedTitle,
      body: [...lines, ?note, l.generationPausedNote].join('\n'),
      actionLabel: label,
      onAction: _resuming ? null : action,
      secondaryActionLabel: first.reason == 'quotaExceeded'
          ? l.useSystemVoiceForBook
          : null,
      onSecondaryAction: first.reason == 'quotaExceeded'
          ? () => generation.setAiVoice(widget.bookId, false)
          : null,
    );
  }
}
