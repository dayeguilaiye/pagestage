import 'package:flutter/material.dart';

import '../application/app_services.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/app_scope.dart';
import 'ming_settings_page.dart';
import 'provider_pages.dart';
import 'settings_page.dart';

/// Opens the settings page from anywhere a fix lives there.
Future<void> openSettings(BuildContext context) {
  final scope = AppScope.of(context);
  final services = scope.services;
  if (services == null) return Future.value();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsPage(
        services: services,
        readingSettings: scope.readingSettings,
      ),
    ),
  );
}

/// Opens one engine's page directly, such as the language model's when a
/// key is missing, so the fix is one tap from where the problem shows.
Future<void> openEngine(BuildContext context, String id) {
  final services = AppScope.servicesOf(context);
  if (services == null) return Future.value();
  final ming = services.ming;
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => id == 'ming' && ming != null
          ? MingSettingsPage(
              device: ming,
              enable: () => services.providers.switchVoice(id, true),
            )
          : EnginePage(providers: services.providers, id: id),
    ),
  );
}

/// Turns on a voice engine that needs no key, after the reader agrees to
/// what it will be sent. Says so when it could not.
Future<void> turnOnVoiceEngine(BuildContext context, String id) async {
  final services = AppScope.servicesOf(context);
  if (services == null) return;
  final l = AppLocalizations.of(context);
  try {
    if (!await agreeToEngine(services, id)) return;
    await services.providers.switchVoice(id, true);
  } catch (_) {
    if (context.mounted) showPsToast(context, l.saveFailed);
  }
}

/// Asks once, while an engine is being set up, to send book text to it.
/// A language engine's agreement is kept under `llm`, as generation asks.
Future<bool> agreeToEngine(AppServices services, String id) async {
  final endpoint = await services.providers.endpoint(id);
  if (endpoint == null) return true;
  final language =
      services.providers.value.engine(id)?.kind == EngineKind.language;
  return services.consents.request(
    provider: language ? 'llm' : id,
    endpoint: endpoint,
    content: 'chapterTextAndCast',
  );
}
