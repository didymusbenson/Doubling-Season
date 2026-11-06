import 'package:flutter/material.dart';

ThemeData tableTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF91B79B),
        brightness: brightness,
        surface: dark ? const Color(0xFF171D1B) : const Color(0xFFF5F4EB),
      ).copyWith(
        // Tonal actions must remain distinct from the quiet drawer surfaces.
        // Keep identity/artwork colors independent from these shared UI roles.
        secondaryContainer: dark
            ? const Color(0xFF425F4C)
            : const Color(0xFFB7CEBD),
        onSecondaryContainer: dark
            ? const Color(0xFFF0FAF1)
            : const Color(0xFF152E1F),
        outline: dark ? const Color(0xFFA4B5A8) : const Color(0xFF58665C),
      );
  final controlSide = WidgetStateProperty.resolveWith<BorderSide?>(
    (states) => states.contains(WidgetState.disabled)
        ? null
        : BorderSide(color: scheme.outline),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0E1311)
        : const Color(0xFFE3E6DD),
    visualDensity: VisualDensity.standard,
    // Numeric controls in rules/utilities are Cards, not FilledButtons.
    // Give their actual painted surfaces a visible boundary in both themes;
    // elevation and near-identical Material tones are not a boundary.
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ).copyWith(side: controlSide),
    ),
    chipTheme: ChipThemeData(
      side: WidgetStateBorderSide.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.disabled)
              ? scheme.onSurface.withValues(alpha: .12)
              : scheme.outline,
        ),
      ),
      selectedColor: scheme.secondaryContainer,
      labelStyle: TextStyle(
        fontFamily: 'sans-serif',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurface.withValues(alpha: .38)
              : states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurface,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .5),
      thickness: 1,
      space: 1,
    ),
    fontFamily: 'sans-serif',
  );
}
