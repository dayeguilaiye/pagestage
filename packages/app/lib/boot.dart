import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'application/app_services.dart';
import 'application/bundled_examples.dart';
import 'application/diagnostics.dart';
import 'design/design.dart';
import 'l10n/app_localizations.dart';
import 'storage.dart';

/// Shows the app's first frame at once and opens everything behind it. If
/// opening fails, the reader sees what happened and what they can do,
/// never a blank screen.
class PagestageBoot extends StatefulWidget {
  const PagestageBoot({super.key, this.open = openPagestage});

  /// Opens the app's storage and services; replaced in tests.
  final Future<PagestageApp> Function(DiagnosticLog? Function() diagnostics)
  open;

  @override
  State<PagestageBoot> createState() => _PagestageBootState();
}

/// The diagnostics journal, once the app's directory is known; the zone
/// guarding `main` records into it too.
DiagnosticLog? bootDiagnostics;

/// Opens storage, installs the examples on first run and starts the
/// services. Examples that fail to install never stop the app opening.
Future<PagestageApp> openPagestage(
  DiagnosticLog? Function() diagnostics,
) async {
  final root = await getApplicationSupportDirectory();
  final log = bootDiagnostics ??= DiagnosticLog(
    Directory('${root.path}/diagnostics'),
  )..install();
  await log.collectNative();
  final storage = await AppStorage.open(directory: root);
  try {
    try {
      await installBundledExamples(storage.store);
    } catch (error, stack) {
      unawaited(log.record(error, stack));
    }
    final services = await AppServices.open(storage, diagnostics: log);
    return PagestageApp(
      bookshelf: storage.library,
      readingSettings: storage.readingSettings,
      services: services,
    );
  } catch (_) {
    await storage.close();
    rethrow;
  }
}

class _PagestageBootState extends State<PagestageBoot> {
  PagestageApp? _app;
  var _failed = false;
  var _opening = false;

  @override
  void initState() {
    super.initState();
    _opening = true;
    _open();
  }

  void _start() {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    _open();
  }

  Future<void> _open() async {
    try {
      final app = await widget.open(() => bootDiagnostics);
      if (mounted) setState(() => _app = app);
    } catch (error, stack) {
      unawaited(bootDiagnostics?.record(error, stack));
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = _app;
    if (app != null) return app;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: PsTheme.light,
      darkTheme: PsTheme.dark,
      supportedLocales: PagestageApp.locales,
      localeListResolutionCallback: PagestageApp.resolveLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      home: _failed
          ? StartupErrorPage(
              retrying: _opening,
              onRetry: _start,
              diagnostics: bootDiagnostics,
            )
          : const _Splash(),
    );
  }
}

/// The paper and the mark while the shelf opens, the same as the native
/// launch screen, so opening looks like one step.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.ps.paper,
    body: const Center(child: PsMark(size: 56, quiet: true)),
  );
}

/// What to do when the app could not open: try again, or send the
/// diagnostic report. Books and keys stay where they are.
class StartupErrorPage extends StatelessWidget {
  const StartupErrorPage({
    super.key,
    required this.onRetry,
    this.retrying = false,
    this.diagnostics,
  });

  final VoidCallback onRetry;
  final bool retrying;
  final Diagnostics? diagnostics;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final diagnostics = this.diagnostics;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PsSpace.s6),
            child: PsEmptyState(
              title: l.startupFailedTitle,
              body: l.startupFailedBody,
              actions: [
                PsButton(
                  label: l.retry,
                  variant: PsButtonVariant.primary,
                  expand: true,
                  loading: retrying,
                  onPressed: retrying ? null : onRetry,
                ),
                if (diagnostics != null) ...[
                  PsButton(
                    label: l.exportDiagnostics,
                    expand: true,
                    onPressed: () => diagnostics.export(),
                  ),
                  PsButton(
                    label: l.reportProblem,
                    variant: PsButtonVariant.ghost,
                    expand: true,
                    onPressed: () => diagnostics.feedback(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
