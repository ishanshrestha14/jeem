import 'package:flutter/material.dart';
import 'semantic_colors.dart';

/// The "logbook / instrument" design system (docs/design/gymflow-design-system.md).
/// Dark only, explicit `ColorScheme.dark` (never `.fromSeed` — seeded schemes
/// are what produce the generic Material look this reskin removes), and a
/// two-width type system: Barlow Condensed for every numeral, Barlow for
/// names/labels/body copy.
abstract final class AppTheme {
  static const ink = Color(0xFF0A0B0D);
  static const surface = Color(0xFF131519);
  static const chalk = Color(0xFFEDEAE3);
  static const dangerColor = Color(0xFFE63946);

  static ThemeData dark() {
    const semantic = SemanticColors.dark;

    final scheme = ColorScheme.dark(
      surface: surface,
      onSurface: chalk,
      primary: chalk,
      onPrimary: ink,
      secondary: semantic.muted,
      onSecondary: ink,
      error: dangerColor,
      onError: chalk,
      surfaceContainerHighest: semantic.surfaceHigh,
      outline: semantic.line,
      outlineVariant: semantic.line,
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: ink,
      extensions: const [semantic],
      textTheme: base.textTheme.apply(fontFamily: 'Barlow'),
      // Gym use: every tappable primary action clears 48dp.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          backgroundColor: chalk,
          foregroundColor: ink,
          textStyle: body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          side: BorderSide(color: semantic.line),
          foregroundColor: chalk,
        ),
      ),
      // No box chrome: no outlined `InputDecoration` anywhere by default —
      // set rows and sheets borrow this baseline and, where they need a
      // writing-line rule instead of a floating label, opt into `dense`
      // (see `NumericField`).
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        labelStyle: TextStyle(color: semantic.muted),
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: semantic.line),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: semantic.line,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
    );
  }

  /// Tabular figures — use for every timer and numeric readout so digits
  /// do not jitter as they change (PRD §16.4).
  static const tabularFigures = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // --- Type scale (docs/design/gymflow-design-system.md §Typography) ---
  // Colour is deliberately left to call sites (`.copyWith(color: ...)`)
  // since the same size/weight is reused against different token colours
  // (chalk / muted / rest / warning).

  static const restCountdownSheet = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontWeight: FontWeight.w700,
    fontSize: 64,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const restCountdownBar = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontWeight: FontWeight.w700,
    fontSize: 34,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const setNumeral = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontWeight: FontWeight.w600,
    fontSize: 22,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const setNumber = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );

  static const elapsedTime = TextStyle(
    fontFamily: 'BarlowCondensed',
    fontWeight: FontWeight.w600,
    fontSize: 20,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const exerciseName = TextStyle(
    fontFamily: 'Barlow',
    fontWeight: FontWeight.w600,
    fontSize: 17,
  );

  static const body = TextStyle(
    fontFamily: 'Barlow',
    fontWeight: FontWeight.w400,
    fontSize: 15,
  );

  static const columnHeader = TextStyle(
    fontFamily: 'Barlow',
    fontWeight: FontWeight.w600,
    fontSize: 11,
    letterSpacing: 1.2,
  );
}
