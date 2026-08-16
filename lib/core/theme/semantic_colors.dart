import 'package:flutter/material.dart';

@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.success,
    required this.rest,
    required this.warning,
    required this.danger,
    required this.muted,
    required this.surfaceHigh,
    required this.line,
  });

  /// Completed state. Deliberately chalk, NOT green (design system: colour
  /// is scarce and means "live"; a tick in a paper log, not a status light).
  final Color success;

  /// The one saturated colour in the app: a running rest timer.
  final Color rest;

  /// Paused rest state only.
  final Color warning;

  /// Destructive actions only.
  final Color danger;

  /// Column headers, secondary labels, inactive digits.
  final Color muted;

  /// The current set row's background — the one surface a shade above
  /// [surface] itself.
  final Color surfaceHigh;

  /// Every hairline rule in the app. 1px, never thicker.
  final Color line;

  static const dark = SemanticColors(
    success: Color(0xFFEDEAE3),
    rest: Color(0xFF4CC9F0),
    warning: Color(0xFFFFB627),
    danger: Color(0xFFE63946),
    muted: Color(0xFF767C86),
    surfaceHigh: Color(0xFF1B1E24),
    line: Color(0xFF262A31),
  );

  @override
  SemanticColors copyWith({
    Color? success,
    Color? rest,
    Color? warning,
    Color? danger,
    Color? muted,
    Color? surfaceHigh,
    Color? line,
  }) =>
      SemanticColors(
        success: success ?? this.success,
        rest: rest ?? this.rest,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        muted: muted ?? this.muted,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        line: line ?? this.line,
      );

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      rest: Color.lerp(rest, other.rest, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}
