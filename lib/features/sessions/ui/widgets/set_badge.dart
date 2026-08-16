import 'package:flutter/material.dart';

import '../../../../core/theme/semantic_colors.dart';

/// The 32dp circular set-number badge shared by [StrengthSetRow] and
/// [DurationSetRow]: filled with `success` when complete, outlined with
/// `primary` when current, outlined with `muted` otherwise. All colours are
/// sourced from the theme (never literal) since this is the most-looked-at
/// element on the most-used screen in the app.
class SetBadge extends StatelessWidget {
  const SetBadge({
    super.key,
    required this.index,
    required this.isComplete,
    required this.isCurrent,
  });

  final int index;
  final bool isComplete;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final borderColor = isComplete
        ? semantic.success
        : (isCurrent ? theme.colorScheme.primary : semantic.muted);
    // `surface` (the app's near-black background) reads clearly against the
    // light `success` fill; `onSurface` is the normal body-text colour
    // against the transparent/unfilled badge.
    final digitColor =
        isComplete ? theme.colorScheme.surface : theme.colorScheme.onSurface;

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isComplete ? semantic.success : Colors.transparent,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(fontWeight: FontWeight.bold, color: digitColor),
      ),
    );
  }
}
