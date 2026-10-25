import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import '../listening/labels.dart';

/// Asks the reader before book text leaves the phone. Shows one dialog per
/// pending request; dismissing it counts as cancelling. A request the
/// service withdraws or replaces closes without an answer.
class ConsentGate extends StatefulWidget {
  const ConsentGate({
    super.key,
    required this.consents,
    required this.navigatorKey,
    required this.child,
  });

  final Consents consents;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  /// The request on screen and its route.
  int? _shown;
  Route<bool>? _route;

  /// Requests already answered or withdrawn, never asked again.
  final _settled = <int>{};

  @override
  void initState() {
    super.initState();
    widget.consents.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(ConsentGate old) {
    super.didUpdateWidget(old);
    if (old.consents != widget.consents) {
      old.consents.removeListener(_check);
      widget.consents.addListener(_check);
      _check();
    }
  }

  @override
  void dispose() {
    widget.consents.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final request = widget.consents.value;
    if (request?.id == _shown) return;
    final route = _route;
    if (_shown != null && route != null) {
      // Settled elsewhere or replaced: close without answering.
      _settled.add(_shown!);
      _shown = null;
      _route = null;
      if (route.isActive) route.navigator?.removeRoute(route);
    }
    if (request != null && !_settled.contains(request.id)) _show(request);
  }

  Future<void> _show(ConsentRequest request) async {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
      return;
    }
    final context = navigator.context;
    final route = DialogRoute<bool>(
      context: context,
      barrierColor: context.ps.scrim,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (_) => ConsentDialog(request: request),
    );
    _shown = request.id;
    _route = route;
    final accepted = await navigator.push(route);
    if (_route != route) return; // Withdrawn while open.
    _shown = null;
    _route = null;
    _settled.add(request.id);
    widget.consents.respond(request.id, accepted: accepted ?? false);
    // A request may already be waiting behind this one.
    _check();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// What will be sent, to whom and why; accept or cancel.
class ConsentDialog extends StatelessWidget {
  const ConsentDialog({super.key, required this.request});

  final ConsentRequest request;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final label = PsType.caption.copyWith(color: p.ink2);
    final value = PsType.body.copyWith(color: p.ink, height: 20 / 15);
    return PsDialog(
      title: l.consentTitle(request.bookTitle),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Labels.consentContent(l, request.content)),
          const SizedBox(height: PsSpace.s4),
          Container(
            padding: const EdgeInsets.all(PsSpace.s3),
            decoration: BoxDecoration(
              color: p.paperSunken,
              borderRadius: BorderRadius.circular(PsRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: PsSpace.s2,
              children: [
                Text(l.consentProvider, style: label),
                Text(Labels.provider(l, request.provider), style: value),
                Text(l.consentEndpoint, style: label),
                SelectableText(
                  request.endpoint,
                  style: PsType.numeral.copyWith(color: p.ink, fontSize: 12),
                ),
                Text(l.consentContentLabel, style: label),
                Text(_contentName(l), style: value),
              ],
            ),
          ),
          const SizedBox(height: PsSpace.s3),
          Text(l.consentCancelNote),
        ],
      ),
      actions: [
        PsButton(
          label: l.consentAccept,
          variant: PsButtonVariant.primary,
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
    );
  }

  String _contentName(AppLocalizations l) => switch (request.content) {
    'chapterTextAndCast' => l.consentChapterTextAndCastName,
    'voiceSample' => l.consentVoiceSampleName,
    _ => l.consentBookContentName,
  };
}
