import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';

enum _Action { export, feedback }

/// Exporting a diagnostic report and reporting a problem. Each action runs
/// once at a time; a failure says so in fixed words and can be retried.
class DiagnosticsSection extends StatefulWidget {
  const DiagnosticsSection({super.key, required this.diagnostics});

  final Diagnostics diagnostics;

  @override
  State<DiagnosticsSection> createState() => _DiagnosticsSectionState();
}

class _DiagnosticsSectionState extends State<DiagnosticsSection> {
  final _running = <_Action>{};
  _Action? _failed;

  Future<void> _run(_Action action) async {
    // A second tap while the share sheet or browser is opening does nothing.
    if (_running.contains(action)) return;
    setState(() {
      _running.add(action);
      if (_failed == action) _failed = null;
    });
    try {
      await switch (action) {
        _Action.export => widget.diagnostics.export(),
        _Action.feedback => widget.diagnostics.feedback(),
      };
    } catch (_) {
      // The message may quote paths or system text; only fixed words show.
      if (mounted) setState(() => _failed = action);
    } finally {
      if (mounted) setState(() => _running.remove(action));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    Widget spinner() => const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    final failed = _failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PsSpace.s3,
      children: [
        PsListGroup(
          header: l.diagnosticsSection,
          iconInset: true,
          children: [
            PsListRow(
              key: const ValueKey('exportDiagnostics'),
              icon: PsIcons.import,
              title: l.exportDiagnostics,
              subtitle: _running.contains(_Action.export)
                  ? l.exportingDiagnostics
                  : l.exportDiagnosticsNote,
              trailing: _running.contains(_Action.export) ? spinner() : null,
              chevron: !_running.contains(_Action.export),
              onTap: () => _run(_Action.export),
            ),
            PsListRow(
              key: const ValueKey('reportProblem'),
              icon: PsIcons.pen,
              title: l.reportProblem,
              subtitle: _running.contains(_Action.feedback)
                  ? l.openingBrowser
                  : l.reportProblemNote,
              trailing: _running.contains(_Action.feedback) ? spinner() : null,
              chevron: !_running.contains(_Action.feedback),
              onTap: () => _run(_Action.feedback),
            ),
          ],
        ),
        if (failed != null)
          PsBanner(
            tone: PsBannerTone.danger,
            title: failed == _Action.export
                ? l.exportDiagnosticsFailed
                : l.reportProblemFailed,
            body: failed == _Action.export
                ? l.exportDiagnosticsFailedBody
                : l.reportProblemFailedBody,
            actionLabel: l.retry,
            onAction: () => _run(failed),
            onClose: () => setState(() => _failed = null),
          ),
        Container(
          padding: const EdgeInsets.all(PsSpace.s4),
          decoration: BoxDecoration(
            color: p.paperSunken,
            borderRadius: BorderRadius.circular(PsRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: PsSpace.s2,
            children: [
              Text(
                l.diagnosticsPrivacyTitle,
                style: PsType.subhead.copyWith(
                  color: p.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final line in [
                l.diagnosticsIncludes,
                l.diagnosticsExcludes,
                l.diagnosticsNoUpload,
              ])
                Text(line, style: PsType.subhead.copyWith(color: p.ink2)),
            ],
          ),
        ),
      ],
    );
  }
}
