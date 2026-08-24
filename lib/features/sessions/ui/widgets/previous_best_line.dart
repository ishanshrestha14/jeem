import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/utils/formatting.dart';
import '../../domain/previous_best.dart';

/// S-006's `Previous`, as one muted line per exercise: what you actually did
/// last time, read against the plan pre-filled in the rows below it.
///
/// The reference app puts this in a per-row column. Ours does not, for two
/// reasons: the value is the *best* set of the last session, so it is
/// identical down every row, and our set row carries a RIR column the
/// reference moved onto its keypad — a fifth numeric column would not fit a
/// phone without shrinking the values you are actually reading mid-set.
///
/// Renders nothing at all when there is no history. The spec's `—` belongs to
/// a table cell that must hold its column open; a header line has no column,
/// so an exercise you have never done simply has no line.
class PreviousBestLine extends StatelessWidget {
  const PreviousBestLine({
    super.key,
    required this.best,
    required this.weightUnit,
  });

  final PreviousBest? best;

  /// The *session's* unit, not a global setting — a session records the unit
  /// it was logged in, and this line is read beside that session's numbers.
  final String weightUnit;

  @override
  Widget build(BuildContext context) {
    final best = this.best;
    if (best == null) return const SizedBox.shrink();

    final semantic = Theme.of(context).extension<SemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Text(
        'Last · ${formatWeight(best.weight)}$weightUnit x ${best.reps}',
        style: AppTheme.body.copyWith(color: semantic.muted, fontSize: 13),
      ),
    );
  }
}
