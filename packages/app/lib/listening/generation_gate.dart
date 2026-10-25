import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../cast/cast_page.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'app_scope.dart';

/// Asks what to do when playback reaches a chapter without generated audio:
/// generate it, read it with the system voice, or stop. One dialog per
/// request; dismissing it cancels. A request the service withdraws closes
/// without an answer.
class GenerationGate extends StatefulWidget {
  const GenerationGate({
    super.key,
    required this.generation,
    required this.navigatorKey,
    required this.child,
  });

  final Generation generation;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<GenerationGate> createState() => _GenerationGateState();
}

/// What the reader chose in the dialog; [profile] also cancels.
enum _Answer { generate, system, profile, cancel }

class _GenerationGateState extends State<GenerationGate> {
  int? _shown;
  Route<_Answer>? _route;
  final _settled = <int>{};

  @override
  void initState() {
    super.initState();
    widget.generation.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didUpdateWidget(GenerationGate old) {
    super.didUpdateWidget(old);
    if (old.generation != widget.generation) {
      old.generation.removeListener(_check);
      widget.generation.addListener(_check);
      _check();
    }
  }

  @override
  void dispose() {
    widget.generation.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted) return;
    final request = widget.generation.value.request;
    if (request?.id == _shown) return;
    final route = _route;
    if (_shown != null && route != null) {
      _settled.add(_shown!);
      _shown = null;
      _route = null;
      if (route.isActive) route.navigator?.removeRoute(route);
    }
    if (request != null && !_settled.contains(request.id)) _show(request);
  }

  Future<void> _show(GenerationRequest request) async {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
      return;
    }
    final context = navigator.context;
    final route = DialogRoute<_Answer>(
      context: context,
      barrierColor: context.ps.scrim,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (_) => GenerationDialog(request: request),
    );
    _shown = request.id;
    _route = route;
    final answer = await navigator.push(route) ?? _Answer.cancel;
    if (_route != route) return; // Withdrawn while open.
    _shown = null;
    _route = null;
    _settled.add(request.id);
    widget.generation.respond(request.id, switch (answer) {
      _Answer.generate => GenerationChoice.generate,
      _Answer.system => GenerationChoice.system,
      _Answer.profile || _Answer.cancel => GenerationChoice.cancel,
    });
    if (answer == _Answer.profile) await _openCast(request);
    _check();
  }

  /// The cast page with profiling preset to reach [request]'s chapter.
  Future<void> _openCast(GenerationRequest request) async {
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null || !mounted) return;
    final scope = AppScope.of(navigator.context);
    final services = scope.services;
    if (services == null) return;
    try {
      final book = (await scope.bookshelf.books())
          .where((b) => b.id == request.bookId)
          .firstOrNull;
      if (book == null || !navigator.mounted) return;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => CastPage(
            services: services,
            book: book,
            initialThrough: request.chapter,
          ),
        ),
      );
    } catch (_) {
      // The book has gone; nothing to profile.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Generate, system voice or cancel; out of the profiled range, generating
/// is replaced by a way to extend profiling.
class GenerationDialog extends StatelessWidget {
  const GenerationDialog({super.key, required this.request});

  final GenerationRequest request;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final chapter = l.chapterNumber(request.chapter);
    void answer(_Answer a) => Navigator.pop(context, a);
    return PsDialog(
      title: l.generationTitle(chapter),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: PsSpace.s3,
        children: [
          Text(
            request.bookTitle,
            style: PsType.subhead.copyWith(color: p.ink2),
          ),
          Text(
            request.canGenerate
                ? l.generationBody
                : l.generationOutOfRange(chapter),
          ),
        ],
      ),
      actions: [
        if (request.canGenerate) ...[
          PsButton(
            label: l.generateNow,
            icon: PsIcons.voice,
            variant: PsButtonVariant.primary,
            expand: true,
            onPressed: () => answer(_Answer.generate),
          ),
          PsButton(
            label: l.useSystemVoice,
            expand: true,
            onPressed: () => answer(_Answer.system),
          ),
        ] else ...[
          PsButton(
            label: l.useSystemVoice,
            variant: PsButtonVariant.primary,
            expand: true,
            onPressed: () => answer(_Answer.system),
          ),
          PsButton(
            label: l.extendProfilingTo(chapter),
            icon: PsIcons.cast,
            expand: true,
            onPressed: () => answer(_Answer.profile),
          ),
        ],
        PsButton(
          label: l.cancel,
          variant: PsButtonVariant.ghost,
          expand: true,
          onPressed: () => answer(_Answer.cancel),
        ),
      ],
    );
  }
}
