import 'package:flutter/material.dart';
import 'package:pagestage_core/pagestage_core.dart';

import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'chapter_player.dart';

/// Development-only listening screen for comparing native playback engines.
class PlaybackPrototypePage extends StatefulWidget {
  const PlaybackPrototypePage({
    super.key,
    required this.player,
    required this.chapter,
    required this.script,
    required this.title,
  });
  final ChapterPlayer player;
  final Chapter chapter;
  final Script script;
  final String title;
  @override
  State<PlaybackPrototypePage> createState() => _PlaybackPrototypePageState();
}

class _PlaybackPrototypePageState extends State<PlaybackPrototypePage> {
  late final _keys = [for (final _ in widget.script.lines) GlobalKey()];
  int? _selected;
  int _lastLine = -1;
  @override
  void initState() {
    super.initState();
    widget.player.addListener(_changed);
  }

  @override
  void dispose() {
    widget.player.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    setState(() {});
    final line = widget.player.currentLines.firstOrNull;
    if (line != null && line != _lastLine) {
      _lastLine = line;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _keys[line].currentContext;
        if (mounted && context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 250),
            alignment: 0.25,
          );
        }
      });
    }
  }

  Future<void> _lineMenu(int index) async {
    if (widget.player.queue.indexForLine(index) < 0) return;
    setState(() => _selected = index);
    final play = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          title: Text(AppLocalizations.of(context).playFromHere),
          onTap: () => Navigator.pop(context, true),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _selected = null);
    if (play == true) await widget.player.playFromLine(index);
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              for (final (index, line) in widget.script.lines.indexed)
                PsPassage(
                  key: _keys[index],
                  paragraphs: [
                    [
                      PsLine(
                        line.textIn(widget.chapter.text),
                        current:
                            !line.isNonStory &&
                            player.currentLines.contains(index),
                        skip: line.isNonStory,
                        selected: _selected == index,
                      ),
                    ],
                  ],
                  onLineTap: (_, _, _) => _lineMenu(index),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: l.previousLine,
                  onPressed: player.previous,
                  icon: const Icon(Icons.skip_previous),
                ),
                Text('${player.state.speed.toStringAsFixed(1)}×'),
                Expanded(
                  child: Slider(
                    value: player.state.speed,
                    min: 0.5,
                    max: 3,
                    divisions: 25,
                    onChanged: player.setSpeed,
                  ),
                ),
              ],
            ),
            PsMiniPlayer(
              book: widget.title,
              title: widget.chapter.title,
              playing: player.state.playing,
              buffering: player.state.buffering,
              progress: player.progress,
              onToggle: player.toggle,
              onNext: player.next,
            ),
          ],
        ),
      ),
    );
  }
}
