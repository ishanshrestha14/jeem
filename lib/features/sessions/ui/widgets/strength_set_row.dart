import 'package:flutter/material.dart';

import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/numeric_field.dart';
import '../../../../db/app_database.dart';
import 'set_badge.dart';

/// A single strength set row: number badge, weight, reps, RIR and a
/// 56dp complete button — sized for one-thumb use mid-workout (PRD §17).
///
/// Completed sets stay editable (PRD §17): fields are never disabled, only
/// dimmed. Nothing here blocks completion on missing weight/reps/RIR
/// (PRD §18.7) — [onToggleComplete] is always enabled.
class StrengthSetRow extends StatelessWidget {
  const StrengthSetRow({
    super.key,
    required this.set,
    required this.isCurrent,
    required this.weightUnit,
    required this.onToggleComplete,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onRirChanged,
    this.onLongPress,
  });

  final SessionSet set;
  final bool isCurrent;
  final String weightUnit;
  final VoidCallback onToggleComplete;
  final ValueChanged<double?> onWeightChanged;
  final ValueChanged<int?> onRepsChanged;
  final ValueChanged<double?> onRirChanged;
  final VoidCallback? onLongPress;

  bool get _isComplete => set.completedAt != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SetBadge(
          index: set.setIndex,
          isComplete: _isComplete,
          isCurrent: isCurrent,
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: NumericField(
            label: 'Weight',
            value: set.weight,
            allowDecimal: true,
            suffix: weightUnit,
            onChanged: (v) => onWeightChanged(v?.toDouble()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: NumericField(
            label: 'Reps',
            value: set.reps,
            onChanged: (v) => onRepsChanged(v?.toInt()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<double?>(
            initialValue: set.rir,
            decoration: const InputDecoration(labelText: 'RIR'),
            items: [
              for (final rir in kRirValues)
                DropdownMenuItem(value: rir, child: Text(formatRir(rir))),
            ],
            onChanged: onRirChanged,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          height: 56,
          child: IconButton(
            iconSize: 32,
            icon: Icon(
              _isComplete ? Icons.check_circle : Icons.check_circle_outline,
              color: _isComplete ? semantic.success : null,
            ),
            tooltip: _isComplete ? 'Mark incomplete' : 'Complete set',
            onPressed: onToggleComplete,
          ),
        ),
      ],
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isCurrent
              ? theme.colorScheme.surfaceContainerHigh
              : Colors.transparent,
          border: isCurrent
              ? Border.all(color: theme.colorScheme.primary, width: 2)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Opacity(opacity: _isComplete ? 0.6 : 1.0, child: row),
      ),
    );
  }
}
