import 'package:flutter/material.dart';

import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'reading_settings.dart';

/// Text size, line spacing and night mode. Changes apply to the page behind
/// at once; there is nothing to confirm.
class ReadingSettingsSheet extends StatelessWidget {
  const ReadingSettingsSheet({
    super.key,
    required this.settings,
    required this.bookTitle,
  });

  final ReadingSettings settings;
  final String bookTitle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: settings,
      builder: (context, preferences, _) {
        final p = context.ps;
        final glyph = PsType.style(PsFonts.serif, 14, 14, FontWeight.w400);
        return PsSheet(
          title: l.readingSettings,
          subtitle: bookTitle,
          onClose: () => Navigator.pop(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Label(l.textSize, first: true),
              Row(
                spacing: PsSpace.s1,
                children: [
                  ExcludeSemantics(
                    child: Text('A', style: glyph.copyWith(color: p.ink2)),
                  ),
                  Expanded(
                    child: Semantics(
                      label: l.textSize,
                      child: Slider(
                        min: ReadingPreferences.minFontSize,
                        max: ReadingPreferences.maxFontSize,
                        divisions:
                            (ReadingPreferences.maxFontSize -
                                    ReadingPreferences.minFontSize)
                                .round(),
                        value: preferences.fontSize,
                        semanticFormatterCallback: (v) => '${v.round()}',
                        onChanged: (v) => settings.update(
                          settings.value.copyWith(fontSize: v),
                        ),
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Text(
                      'A',
                      style: glyph.copyWith(fontSize: 22, color: p.ink2),
                    ),
                  ),
                ],
              ),
              _Label(l.lineSpacing),
              PsSegmentedControl<PsLineSpacing>(
                expand: true,
                value: preferences.lineSpacing,
                onChanged: (v) =>
                    settings.update(settings.value.copyWith(lineSpacing: v)),
                segments: [
                  PsSegment(PsLineSpacing.compact, l.lineSpacingCompact),
                  PsSegment(
                    PsLineSpacing.comfortable,
                    l.lineSpacingComfortable,
                  ),
                  PsSegment(PsLineSpacing.loose, l.lineSpacingLoose),
                ],
              ),
              _Label(l.nightMode),
              PsSegmentedControl<ThemeMode>(
                expand: true,
                value: preferences.themeMode,
                onChanged: (v) =>
                    settings.update(settings.value.copyWith(themeMode: v)),
                segments: [
                  PsSegment(ThemeMode.system, l.nightModeSystem),
                  PsSegment(ThemeMode.light, l.nightModeOff),
                  PsSegment(ThemeMode.dark, l.nightModeOn),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.first = false});
  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? PsSpace.s1 : 18, bottom: 10),
      child: Text(text, style: PsType.subhead.copyWith(color: context.ps.ink2)),
    );
  }
}
