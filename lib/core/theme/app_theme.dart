import 'package:flutter/material.dart';
import 'semantic_colors.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: Brightness.dark,
    ).copyWith(surface: const Color(0xFF0F1115));

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F1115),
      extensions: const [SemanticColors.dark],
      // Gym use: every tappable primary action clears 48dp.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      textTheme: base.textTheme.apply(fontFamilyFallback: const ['SF Pro']),
    );
  }

  /// Tabular figures — use for every timer and numeric readout so digits
  /// do not jitter as they change (PRD §16.4).
  static const tabularFigures = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
