import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/widgets/numeric_field.dart';
import '../../../../db/app_database.dart';
import 'set_badge.dart';
import 'set_row_decoration.dart';

/// Quick-pick chips for a duration set's length. Deliberately distinct from
/// [kRestPresets] (rest-between-sets presets) — these are common hold/carry
/// times for a duration-logged exercise itself.
const _kDurationPresets = <int>[15, 30, 45, 60];

/// A single duration-only set row: number, a duration field, quick-pick
/// chips, and the same 56dp complete control as [StrengthSetRow]. Follows
/// the same ledger-line grammar with `SET / DURATION` columns.
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
    final numeralStyle = AppTheme.setNumeral.copyWith(color: theme.colorScheme.onSurface);

    final underline = isCurrent
        ? BoxDecoration(border: Border(bottom: BorderSide(color: semantic.line)))
        : const BoxDecoration();

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SetBadge(index: set.setIndex, isComplete: _isComplete, isCurrent: isCurrent),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Container(
            decoration: underline,
            child: NumericField(
              label: 'Duration (s)',
              value: set.durationSeconds,
              suffix: 's',
              dense: true,
              style: numeralStyle,
              onChanged: (v) => onDurationChanged(v?.toInt()),
            ),
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
        _DoneControl(isComplete: _isComplete, onPressed: onToggleComplete),
      ],
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: setRowDecoration(
          semantic,
          isCurrent: isCurrent,
          isComplete: _isComplete,
          currentEdgeColor: theme.colorScheme.onSurface,
        ),
        child: row,
      ),
    );
  }
}

/// 56x56 hit area (design system): an outlined ring while pending, a filled
/// chalk disc with an `ink` checkmark once complete. No Material checkbox.
/// Duplicated from [StrengthSetRow]'s private `_DoneControl` — same grammar,
/// kept private per-file to avoid growing the widgets/ export surface for a
/// single shared 20-line leaf.
class _DoneControl extends StatelessWidget {
  const _DoneControl({required this.isComplete, required this.onPressed});

  final bool isComplete;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    return Tooltip(
      message: isComplete ? 'Mark incomplete' : 'Complete set',
      child: SizedBox(
        width: 56,
        height: 56,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: isComplete
                ? Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: semantic.success,
                    ),
                    child: const Icon(Icons.check, size: 16, color: AppTheme.ink),
                  )
                : Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: semantic.muted, width: 1.5),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
