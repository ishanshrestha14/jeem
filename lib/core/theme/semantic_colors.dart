import 'package:flutter/material.dart';

@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.success,
    required this.rest,
    required this.warning,
    required this.danger,
    required this.muted,
  });

  final Color success;
  final Color rest;
  final Color warning;
  final Color danger;
  final Color muted;

  static const dark = SemanticColors(
    success: Color(0xFF4ADE80),
    rest: Color(0xFF38BDF8),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    muted: Color(0xFF94A3B8),
  );

  @override
  SemanticColors copyWith({
    Color? success,
    Color? rest,
    Color? warning,
    Color? danger,
    Color? muted,
  }) =>
      SemanticColors(
        success: success ?? this.success,
        rest: rest ?? this.rest,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        muted: muted ?? this.muted,
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
    );
  }
}
