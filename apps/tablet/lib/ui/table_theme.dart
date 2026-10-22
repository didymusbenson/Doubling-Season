import 'package:flutter/material.dart';

ThemeData tableTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF91B79B),
    brightness: brightness,
    surface: dark ? const Color(0xFF171D1B) : const Color(0xFFF5F4EB),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0E1311)
        : const Color(0xFFE3E6DD),
    visualDensity: VisualDensity.standard,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 600),
    ),
    fontFamily: 'sans-serif',
  );
}
