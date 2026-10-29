import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/contracts.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';

/// Chooses how many characters get a voice of their own. Every profiled
/// book is recast when the count changes, which stops what is playing, so
/// the new count applies only when the reader asks for it.
Future<void> showExclusiveVoicesSheet(
  BuildContext context, {
  required Casts casts,
}) => showPsSheet<void>(
  context,
  builder: (_) => _ExclusiveVoicesSheet(casts: casts),
);

class _ExclusiveVoicesSheet extends StatefulWidget {
  const _ExclusiveVoicesSheet({required this.casts});

  final Casts casts;

  @override
  State<_ExclusiveVoicesSheet> createState() => _ExclusiveVoicesSheetState();
}

class _ExclusiveVoicesSheetState extends State<_ExclusiveVoicesSheet> {
  late var _count = widget.casts.exclusiveCount;
  var _busy = false;
  var _failed = false;

  /// More than this rarely finds enough distinct voices to go round; a
  /// count saved earlier above it still shows as it is.
  late final _max = math.max(50, widget.casts.exclusiveCount);

  void _set(int count) => setState(() {
    _count = count.clamp(0, _max);
    _failed = false;
  });

  Future<void> _recast() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.casts.setExclusiveCount(_count);
      if (!mounted) return;
      showPsToast(context, l.recastDone(_count));
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.ps;
    final note = PsType.caption.copyWith(
      color: p.ink2,
      fontWeight: FontWeight.w400,
    );
    return PsSheet(
      title: l.exclusiveVoices,
      subtitle: l.exclusiveVoicesNote,
      onClose: () => Navigator.pop(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: PsSpace.s3),
          Row(
            children: [
              PsIconButton(
                icon: PsIcons.minus,
                label: l.fewerVoices,
                variant: PsIconButtonVariant.outline,
                onPressed: _busy || _count <= 0 ? null : () => _set(_count - 1),
              ),
              Expanded(
                child: Text(
                  '$_count',
                  key: const ValueKey('exclusiveCount'),
                  textAlign: TextAlign.center,
                  style: PsType.figure.copyWith(color: p.ink),
                ),
              ),
              PsIconButton(
                icon: PsIcons.plus,
                label: l.moreVoices,
                variant: PsIconButtonVariant.outline,
                onPressed: _busy || _count >= _max
                    ? null
                    : () => _set(_count + 1),
              ),
            ],
          ),
          const SizedBox(height: PsSpace.s2),
          Semantics(
            label: l.exclusiveVoices,
            child: Slider(
              min: 0,
              max: _max.toDouble(),
              divisions: _max,
              value: _count.toDouble(),
              semanticFormatterCallback: (v) => '${v.round()}',
              onChanged: _busy ? null : (v) => _set(v.round()),
            ),
          ),
          const SizedBox(height: PsSpace.s4),
          Text(l.exclusiveVoicesRecastNote, style: note),
          const SizedBox(height: PsSpace.s5),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(bottom: PsSpace.s3),
              child: Text(
                l.recastFailed,
                style: note.copyWith(color: p.danger),
              ),
            ),
          PsButton(
            label: l.recast,
            variant: PsButtonVariant.primary,
            expand: true,
            loading: _busy,
            onPressed: _count == widget.casts.exclusiveCount ? null : _recast,
          ),
        ],
      ),
    );
  }
}
