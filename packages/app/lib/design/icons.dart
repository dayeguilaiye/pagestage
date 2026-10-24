// Paths mirror the Icon component in the pagestage design system: 24px grid,
// 1.6 stroke, round caps and joins. Solid parts fill with currentColor.
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum PsIcons {
  play(
    r'<path d="M8 5.8v12.4c0 .8.9 1.3 1.6.9l9.8-6.2c.6-.4.6-1.3 0-1.7L9.6 4.9C8.9 4.5 8 5 8 5.8z" fill="currentColor" stroke="none"/>',
  ),
  pause(
    r'<rect x="6.5" y="5" width="3.6" height="14" rx="1.2" fill="currentColor" stroke="none"/><rect x="13.9" y="5" width="3.6" height="14" rx="1.2" fill="currentColor" stroke="none"/>',
  ),
  lineBack(
    r'<path d="M11.5 7.5v9L5 12z" fill="currentColor"/><path d="M19.5 7.5v9L13 12z" fill="currentColor"/>',
  ),
  lineForward(
    r'<path d="M12.5 7.5v9L19 12z" fill="currentColor"/><path d="M4.5 7.5v9L11 12z" fill="currentColor"/>',
  ),
  chapterBack(
    r'<path d="M6.5 6.5v11"/><path d="M18 7v10l-8-5z" fill="currentColor"/>',
  ),
  chapterForward(
    r'<path d="M17.5 6.5v11"/><path d="M6 7v10l8-5z" fill="currentColor"/>',
  ),
  moon(r'<path d="M19.5 14.6A8 8 0 0 1 9.4 4.5a8 8 0 1 0 10.1 10.1z"/>'),
  list(
    r'<path d="M9 7h11M9 12h11M9 17h11"/><circle cx="4.75" cy="7" r="1.1" fill="currentColor" stroke="none"/><circle cx="4.75" cy="12" r="1.1" fill="currentColor" stroke="none"/><circle cx="4.75" cy="17" r="1.1" fill="currentColor" stroke="none"/>',
  ),
  cast(
    r'<circle cx="9" cy="8.5" r="3.2"/><path d="M3.2 19.5c.6-3.2 2.9-5.2 5.8-5.2s5.2 2 5.8 5.2"/><path d="M14.6 5.6a3 3 0 1 1 1.6 5.6"/><path d="M17.2 14.5c2 .5 3.3 2.2 3.7 5"/>',
  ),
  voice(r'<path d="M4 10v4M8 7v10M12 4v16M16 8v8M20 10.5v3"/>'),
  pen(
    r'<path d="M12 20.5 6 10.6 8.6 4h6.8L18 10.6z"/><path d="M12 20.5v-7.2"/><circle cx="12" cy="11.6" r="1.6"/>',
  ),
  settings(
    r'<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2.1"/><circle cx="9" cy="17" r="2.1"/>',
  ),
  import(
    r'<path d="M4 14v4.5c0 .8.7 1.5 1.5 1.5h13c.8 0 1.5-.7 1.5-1.5V14"/><path d="M12 4v11M7.5 10.5 12 15l4.5-4.5"/>',
  ),
  book(
    r'<path d="M12 6.6C10.4 5.3 8 4.7 4 4.7v13.6c4 0 6.4.6 8 1.9 1.6-1.3 4-1.9 8-1.9V4.7c-4 0-6.4.6-8 1.9z"/><path d="M12 6.6v13.6"/>',
  ),
  more(
    r'<circle cx="5.5" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.6" fill="currentColor" stroke="none"/><circle cx="18.5" cy="12" r="1.6" fill="currentColor" stroke="none"/>',
  ),
  chevronLeft(r'<path d="M14.5 5.5 8 12l6.5 6.5"/>'),
  chevronRight(r'<path d="M9.5 5.5 16 12l-6.5 6.5"/>'),
  chevronDown(r'<path d="M5.5 9.5 12 16l6.5-6.5"/>'),
  check(r'<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
  close(r'<path d="M6.5 6.5l11 11M17.5 6.5l-11 11"/>'),
  plus(r'<path d="M12 5v14M5 12h14"/>'),
  minus(r'<path d="M5 12h14"/>'),
  key(
    r'<circle cx="8" cy="15.5" r="4"/><path d="M10.9 12.6 19.5 4M16.5 7l2.5 2.5M14.2 9.3l2 2"/>',
  ),
  alert(
    r'<path d="M10.3 4.7 3.3 17.1c-.8 1.4.2 3 1.7 3h14c1.5 0 2.5-1.6 1.7-3L13.7 4.7c-.8-1.3-2.6-1.3-3.4 0z"/><path d="M12 9.6v4.6"/><circle cx="12" cy="17" r="1" fill="currentColor" stroke="none"/>',
  ),
  textSize(
    r'<path d="M2.8 19 7.7 5.5h.6L13.2 19M4.6 14.6h7.2"/><path d="M14.6 19l3.4-8.4 3.4 8.4M15.8 16.2h4.4"/>',
  ),
  trash(
    r'<path d="M4.5 7h15M9.5 7V4.8c0-.4.4-.8.8-.8h3.4c.4 0 .8.4.8.8V7"/><path d="M6.6 7l.8 12.1c.1.8.7 1.4 1.5 1.4h6.2c.8 0 1.4-.6 1.5-1.4L17.4 7"/><path d="M10 11v6M14 11v6"/>',
  ),
  playFrom(
    r'<path d="M4 7h11M4 12h7M4 17h11"/><path d="M15.5 10v6.8l5.5-3.4z" fill="currentColor"/>',
  );

  const PsIcons(this.body);
  final String body;

  String get svg =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
      'stroke="currentColor" stroke-width="1.6" stroke-linecap="round" '
      'stroke-linejoin="round">$body</svg>';
}

class PsIcon extends StatelessWidget {
  const PsIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final PsIcons icon;
  final double? size;

  /// Defaults to the ambient [IconTheme] colour.
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    return SvgPicture.string(
      icon.svg,
      width: s,
      height: s,
      theme: SvgTheme(
        currentColor: color ?? theme.color ?? const Color(0xFF000000),
      ),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
