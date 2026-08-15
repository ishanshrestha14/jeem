import 'package:flutter/material.dart';

import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/widgets/numeric_field.dart';
import '../../../../db/app_database.dart';

/// Quick-pick chips for a duration set's length. Deliberately distinct from
/// [kRestPresets] (rest-between-sets presets) — these are common hold/carry
/// times for a duration-logged exercise itself.
const _kDurationPresets = <int>[15, 30, 45, 60];

/// A single duration-only set row: number badge, a duration field, quick-pick
/// chips, and the same 56dp complete button as [StrengthSetRow].
class DurationSetRow extends StatelessWidget {
  const DurationSetRow({
    super.key,
    required this.set,
    required this.isCurrent,
    required this.onToggleComplete,
    required this.onDurationChanged,
    this.onLongPress,
  });

  final SessionSet set;
  final bool isCurrent;
  final VoidCallback onToggleComplete;
  final ValueChanged<int?> onDurationChanged;
  final VoidCallback? onLongPress;

  bool get _isComplete => set.completedAt != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DurationBadge(
          index: set.setIndex,
          isComplete: _isComplete,
          isCurrent: isCurrent,
          success: semantic.success,
          primary: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: NumericField(
            label: 'Duration (s)',
            value: set.durationSeconds,
            suffix: 's',
            onChanged: (v) => onDurationChanged(v?.toInt()),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: Wrap(
            spacing: 6,
            children: [
              for (final preset in _kDurationPresets)
                ActionChip(
                  label: Text('${preset}s'),
                  onPressed: () => onDurationChanged(preset),
                ),
            ],
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

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({
    required this.index,
    required this.isComplete,
    required this.isCurrent,
    required this.success,
    required this.primary,
  });

  final int index;
  final bool isComplete;
  final bool isCurrent;
  final Color success;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isComplete ? success : Colors.transparent,
        border: Border.all(
          color: isComplete ? success : (isCurrent ? primary : Colors.grey),
          width: 2,
        ),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isComplete ? Colors.black : null,
        ),
      ),
    );
  }
}
