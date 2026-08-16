import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/semantic_colors.dart';

/// The 28dp set-number cell shared by [StrengthSetRow] and [DurationSetRow].
///
/// Ledger-line grammar (docs/design/gymflow-design-system.md): this is plain
/// condensed digits, not a Material badge/chip. The *row* carries the
/// "current" treatment (surfaceHigh background + leading chalk bar); this
/// cell only dims once the set is complete, per "dim only the set-number
/// cell, not the values."
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
    final color = isComplete ? semantic.muted : theme.colorScheme.onSurface;

    return SizedBox(
      width: 28,
      child: Text(
        '${index + 1}',
        textAlign: TextAlign.center,
        style: AppTheme.setNumber.copyWith(color: color),
      ),
    );
  }
}
