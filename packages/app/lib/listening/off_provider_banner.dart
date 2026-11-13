import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../settings/provider_pages.dart';
import 'app_scope.dart';
import 'labels.dart';

/// The voice engines among [used] that are switched off or not ready, in
/// the order settings lists them; engines this build no longer has come
/// last.
List<String> offVoiceProviders(
  ProviderPreferences preferences,
  Iterable<String?> used,
) {
  final on = preferences.voiceProviders;
  final wanted = used.nonNulls.where((id) => id.isNotEmpty).toSet();
  final known = [for (final engine in preferences.voiceEngines) engine.id];
  return [
    for (final provider in known)
      if (wanted.contains(provider) && !on.contains(provider)) provider,
    ...wanted.where((id) => !known.contains(id)),
  ];
}

/// Some of [bookId]'s voices come from [provider], which is switched off or
/// has no key, so they cannot be generated. Offers both ways out: turn the
/// provider on, or rematch those speakers among the providers that are on.
/// Either way, generation paused for the book then goes on.
class OffProviderBanner extends StatefulWidget {
  const OffProviderBanner({
    super.key,
    required this.bookId,
    required this.provider,
    this.speakers = const [],
  });

  final String bookId;
  final String provider;

  /// Who speaks with those voices, when known.
  final List<String> speakers;

  @override
  State<OffProviderBanner> createState() => _OffProviderBannerState();
}

class _OffProviderBannerState extends State<OffProviderBanner> {
  var _busy = false;
  String? _failure;

  Future<void> _run(
    AppServices services,
    String failure,
    Future<bool> Function() fix,
  ) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      if (!await fix()) return;
      final generation = services.generation;
      if (generation != null &&
          generation.value.failures.any((f) => f.bookId == widget.bookId)) {
        await generation.resume(widget.bookId);
      }
    } catch (_) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Turns the switch on, or opens the engine's page for what it needs
  /// first.
  Future<bool> _turnOn(Providers providers) async {
    if (providers.value.canSwitchOn(widget.provider)) {
      await providers.switchVoice(widget.provider, true);
      return true;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EnginePage(providers: providers, id: widget.provider),
      ),
    );
    return providers.value.voiceProviders.contains(widget.provider);
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.servicesOf(context);
    if (services == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: services.providers,
      builder: (context, preferences, _) {
        final name = Labels.inline(l, widget.provider);
        final keyed = preferences.canSwitchOn(widget.provider);
        // An engine this build cannot offer can only be rematched away from.
        final engine = preferences.engine(widget.provider);
        final offered =
            engine != null && engine.status != EngineStatus.unavailable;
        final names = widget.speakers;
        final separator = l.chapterListSeparator;
        final who = names.length <= 3
            ? names.join(separator)
            : l.speakersAndMore(
                names.take(3).join(separator),
                names.length,
                names.length - 3,
              );
        return PsBanner(
          tone: _failure == null ? PsBannerTone.amber : PsBannerTone.danger,
          title:
              _failure ??
              Labels.sentence(
                keyed
                    ? l.offProviderTitle(name)
                    : l.offProviderNoKeyTitle(name),
              ),
          body: Labels.sentence(
            names.isEmpty
                ? l.offProviderBody(name)
                : l.offProviderSpeakers(who, name),
          ),
          actionLabel: !offered
              ? null
              : Labels.sentence(
                  keyed ? l.turnOnProvider(name) : l.addProviderKey(name),
                ),
          onAction: _busy || !offered
              ? null
              : () => _run(
                  services,
                  l.saveFailed,
                  () => _turnOn(services.providers),
                ),
          // Nothing to rematch with until some provider is on.
          secondaryActionLabel: preferences.voiceProviders.isEmpty
              ? null
              : l.rematchVoices,
          onSecondaryAction: _busy
              ? null
              : () => _run(services, l.rematchFailed, () async {
                  await services.casts.rematch(widget.bookId);
                  return true;
                }),
        );
      },
    );
  }
}
