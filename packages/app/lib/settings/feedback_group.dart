import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';

enum _Action { export, feedback }

/// Exporting a diagnostic report and reporting a problem. Each runs once at
/// a time; a failure says so in fixed words and can be retried.
class FeedbackGroup extends StatefulWidget {
  const FeedbackGroup({super.key, required this.diagnostics});

  final Diagnostics diagnostics;

  @override
  State<FeedbackGroup> createState() => _FeedbackGroupState();
}

class _FeedbackGroupState extends State<FeedbackGroup> {
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
    const spinner = SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    final exporting = _running.contains(_Action.export);
    final opening = _running.contains(_Action.feedback);
    final failed = _failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: PsSpace.s3,
      children: [
        PsListGroup(
          header: l.feedbackSection,
          footer: l.feedbackNote,
          children: [
            PsListRow(
              key: const ValueKey('exportDiagnostics'),
              title: l.exportDiagnostics,
              subtitle: exporting
                  ? l.exportingDiagnostics
                  : l.exportDiagnosticsNote,
              trailing: exporting ? spinner : null,
              chevron: !exporting,
              onTap: () => _run(_Action.export),
            ),
            PsListRow(
              key: const ValueKey('reportProblem'),
              title: l.reportProblem,
              subtitle: opening ? l.openingBrowser : l.reportProblemNote,
              trailing: opening ? spinner : null,
              external: !opening,
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
      ],
    );
  }
}
