import 'package:flutter/material.dart';

import 'tokens.dart';
import 'type.dart';

extension PsThemeContext on BuildContext {
  PsPalette get ps => Theme.of(this).extension<PsPalette>()!;
}

abstract final class PsTheme {
  static final light = build(PsPalette.light, Brightness.light);
  static final dark = build(PsPalette.dark, Brightness.dark);

  static ThemeData build(PsPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.vermilion,
      onPrimary: p.onVermilion,
      primaryContainer: p.vermilionSoft,
      onPrimaryContainer: p.vermilion,
      secondary: p.ink,
      onSecondary: p.paper,
      secondaryContainer: p.paperSunken,
      onSecondaryContainer: p.ink,
      tertiary: p.jade,
      onTertiary: p.paper,
      tertiaryContainer: p.jadeSoft,
      onTertiaryContainer: p.jade,
      error: p.danger,
      onError: p.paper,
      errorContainer: p.dangerSoft,
      onErrorContainer: p.danger,
      surface: p.paper,
      onSurface: p.ink,
      onSurfaceVariant: p.ink2,
      surfaceContainerLowest: p.paperRaised,
      surfaceContainerLow: p.paperRaised,
      surfaceContainer: p.paperRaised,
      surfaceContainerHigh: p.paperRaised,
      surfaceContainerHighest: p.paperSunken,
      outline: p.ruleStrong,
      outlineVariant: p.rule,
      scrim: p.scrim,
      shadow: const Color(0xFF000000),
      inverseSurface: p.ink,
      onInverseSurface: p.paper,
      inversePrimary: p.vermilionSoft,
      surfaceTint: Colors.transparent,
    );
    final text = TextTheme(
      displaySmall: PsType.display,
      headlineMedium: PsType.title1,
      headlineSmall: PsType.title2,
      titleLarge: PsType.title3,
      titleMedium: PsType.headline,
      titleSmall: PsType.label,
      bodyLarge: PsType.rowTitle,
      bodyMedium: PsType.body,
      bodySmall: PsType.subhead.copyWith(color: p.ink2),
      labelLarge: PsType.label,
      labelMedium: PsType.caption.copyWith(color: p.ink2),
      labelSmall: PsType.tag,
    ).apply(bodyColor: p.ink, displayColor: p.ink);
    final pill = WidgetStatePropertyAll<OutlinedBorder>(const StadiumBorder());
    WidgetStateProperty<Color?> pressed(Color color) =>
        WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.pressed) || s.contains(WidgetState.hovered)
              ? color
              : null,
        );
    ButtonStyle button({required Color fg, Color? bg, BorderSide? side}) =>
        ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? p.inkFaint : fg,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? (bg == null ? null : p.paperSunken)
                : bg,
          ),
          overlayColor: pressed(
            bg == null ? p.paperSunken : p.ink.withValues(alpha: 0.06),
          ),
          side: side == null
              ? null
              : WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.disabled)
                      ? BorderSide(color: p.rule)
                      : side,
                ),
          shape: pill,
          textStyle: WidgetStatePropertyAll(PsType.label),
          minimumSize: const WidgetStatePropertyAll(Size(64, PsSize.control)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: PsSpace.s5),
          ),
          iconSize: const WidgetStatePropertyAll(20),
          elevation: const WidgetStatePropertyAll(0),
          splashFactory: NoSplash.splashFactory,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [p],
      scaffoldBackgroundColor: p.paper,
      canvasColor: p.paper,
      fontFamily: PsFonts.sans,
      fontFamilyFallback: PsFonts.sansFallback,
      textTheme: text,
      splashFactory: NoSplash.splashFactory,
      highlightColor: p.paperSunken,
      hoverColor: p.paperSunken,
      dividerColor: p.rule,
      iconTheme: IconThemeData(color: p.ink, size: 24),
      dividerTheme: DividerThemeData(color: p.rule, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: p.paper,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: PsType.headline.copyWith(color: p.ink),
        iconTheme: IconThemeData(color: p.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button(fg: p.onVermilion, bg: p.vermilion),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button(
          fg: p.ink,
          side: BorderSide(color: p.ruleStrong),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: button(fg: p.ink)),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? p.inkFaint : p.ink,
          ),
          overlayColor: pressed(p.paperSunken),
          minimumSize: const WidgetStatePropertyAll(Size.square(PsSize.touch)),
          splashFactory: NoSplash.splashFactory,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStatePropertyAll(p.paperRaised),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : p.paperSunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.ink : p.ruleStrong,
        ),
        trackOutlineWidth: const WidgetStatePropertyAll(1),
        thumbIcon: const WidgetStatePropertyAll(null),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.ink,
        inactiveTrackColor: p.rule,
        thumbColor: p.paperRaised,
        overlayColor: Colors.transparent,
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 12,
          elevation: 1,
          pressedElevation: 2,
        ),
        trackShape: const RoundedRectSliderTrackShape(),
        showValueIndicator: ShowValueIndicator.never,
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: p.ink,
        disabledColor: p.paperSunken,
        labelStyle: PsType.body.copyWith(
          color: p.ink,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: PsType.body.copyWith(
          color: p.paper,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: p.ruleStrong),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.ink,
        linearTrackColor: p.rule,
        circularTrackColor: p.rule,
        linearMinHeight: 4,
        borderRadius: BorderRadius.circular(PsRadius.full),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.paperRaised,
        hintStyle: PsType.body.copyWith(color: p.ink2),
        helperStyle: PsType.subhead.copyWith(color: p.ink2),
        errorStyle: PsType.subhead.copyWith(color: p.danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        border: _field(p.ruleStrong, 1),
        enabledBorder: _field(p.ruleStrong, 1),
        focusedBorder: _field(p.ink, 2),
        errorBorder: _field(p.danger, 1),
        focusedErrorBorder: _field(p.danger, 2),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.vermilion,
        selectionColor: p.spotlight,
        selectionHandleColor: p.vermilion,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        barrierColor: p.scrim,
        insetPadding: const EdgeInsets.all(PsSpace.s6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PsRadius.lg),
        ),
        titleTextStyle: PsType.style(
          PsFonts.serif,
          20,
          28,
          FontWeight.w600,
        ).copyWith(color: p.ink),
        contentTextStyle: PsType.body.copyWith(color: p.ink2, height: 23 / 15),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.paperRaised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.paperRaised,
        modalBarrierColor: p.scrim,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: p.ruleStrong,
        dragHandleSize: const Size(36, 5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PsRadius.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: PsType.body.copyWith(
          color: p.paper,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: p.paper,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PsRadius.md),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.paperRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: p.shadowFloat.first.color,
        textStyle: PsType.body.copyWith(color: p.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PsRadius.md),
          side: BorderSide(color: p.rule),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.ink2,
        textColor: p.ink,
        titleTextStyle: PsType.rowTitle.copyWith(color: p.ink),
        subtitleTextStyle: PsType.subhead.copyWith(color: p.ink2),
        contentPadding: const EdgeInsets.symmetric(horizontal: PsSpace.s4),
        minVerticalPadding: PsSpace.s3,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(PsRadius.sm),
        ),
        textStyle: PsType.caption.copyWith(color: p.paper),
      ),
    );
  }

  static OutlineInputBorder _field(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(PsRadius.sm),
        borderSide: BorderSide(color: color, width: width),
      );
}
