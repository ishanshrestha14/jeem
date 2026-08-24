import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/numeric_field.dart';
import '../../../../db/app_database.dart';
import 'set_badge.dart';

/// A single strength set row: number, weight, reps, RIR and a 56dp complete
/// control — sized for one-thumb use mid-workout (PRD §17). Ledger-line
/// grammar, not a card: `[28][flex 3][flex 2][flex 3][56]`
/// (docs/design/gymflow-design-system.md).
///
/// Completed sets stay editable (PRD §17): fields are never disabled, only
/// the set-number cell dims. Nothing here blocks completion on missing
/// weight/reps/RIR (PRD §18.7) — [onToggleComplete] is always enabled.
class StrengthSetRow extends StatelessWidget {
  const StrengthSetRow({
    super.key,
    required this.set,
    required this.isCurrent,
    this.keypadSortKey,
    required this.weightUnit,
    required this.onToggleComplete,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onRirChanged,
    this.onLongPress,
  });

  final SessionSet set;
  final bool isCurrent;

  /// Base position in the keypad's entry order; weight takes this slot and
  /// reps the next, so `Next` runs weight -> reps -> the following set's
  /// weight. Null keeps the system keyboard (the keypad is session-only).
  final int? keypadSortKey;
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
    final numeralStyle = AppTheme.setNumeral.copyWith(color: theme.colorScheme.onSurface);

    // A 1px writing line under the *current* row's numeric cells only — not
    // a box, and not drawn for any other row (rows are separated by the
    // hairline the parent list places between them instead).
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
            // `weightUnit` isn't rendered visually in the row itself — the
            // column header above already carries it once per exercise —
            // but it still belongs on the field's semantics so a screen
            // reader announces "Weight in kg" rather than just "Weight".
            child: Semantics(
              label: 'Weight in $weightUnit',
              child: NumericField(
                label: 'Weight',
                value: set.weight,
                // CMP-015: the routine's snapshotted plan, muted, while the
                // field is empty. Completing an untouched row logs it (see
                // `ActiveSessionController.completeSet`), so a set that goes
                // to plan costs one tap and no typing.
                hintText: set.plannedWeight == null
                    ? null
                    : formatWeight(set.plannedWeight),
                allowDecimal: true,
                keypadSortKey: keypadSortKey,
                keypadTag: set.id,
                // No `suffix` here: `dense: true` drops `suffixText`
                // entirely (design system — "no box chrome" in set rows),
                // so passing it would be a parameter silently ignored by
                // the field.
                dense: true,
                style: numeralStyle,
                onChanged: (v) => onWeightChanged(v?.toDouble()),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Container(
            decoration: underline,
            child: NumericField(
              label: 'Reps',
              value: set.reps,
              // A planned range hints as `8-10`; completion logs its lower
              // bound, which is what the row was asked for at minimum.
              hintText: formatPlannedReps(set.plannedReps, set.plannedRepsMax),
              keypadSortKey: keypadSortKey == null ? null : keypadSortKey! + 1,
              keypadTag: set.id,
              dense: true,
              style: numeralStyle,
              onChanged: (v) => onRepsChanged(v?.toInt()),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Container(
            decoration: underline,
            child: _RirControl(value: set.rir, style: numeralStyle, onChanged: onRirChanged),
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
        decoration: BoxDecoration(
          color: isCurrent ? semantic.surfaceHigh : Colors.transparent,
          border: isCurrent
              ? Border(left: BorderSide(color: theme.colorScheme.onSurface, width: 3))
              : null,
        ),
        child: row,
      ),
    );
  }
}

/// A non-null wrapper around a menu selection, so `showMenu`'s `null`
/// return (dismissal) can be distinguished from a genuine pick of the `—`
/// entry, whose underlying value is itself `null`.
class _RirChoice {
  const _RirChoice(this.value);

  final double? value;

  @override
  bool operator ==(Object other) => other is _RirChoice && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// RIR must not use `DropdownButtonFormField` — its internal decoration is
/// what overflows the row at ~7px of remaining width. This renders only the
/// value text (`2`, `1.5`, `—`), no arrow chrome, no border, and opens a
/// plain [showMenu] instead of carrying its own layout box.
class _RirControl extends StatelessWidget {
  const _RirControl({required this.value, required this.style, required this.onChanged});

  final double? value;
  final TextStyle style;
  final ValueChanged<double?> onChanged;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      topLeft & box.size,
      Offset.zero & overlay.size,
    );
    // `showMenu` returns `null` both when the user explicitly picks the
    // `—` entry (`kRirValues[0]` is itself `null`) and when the menu is
    // dismissed without a selection (tap outside / back button). Those are
    // not the same thing — a dismissal must leave the logged RIR untouched,
    // while picking `—` must clear it — so the item values are wrapped in
    // a non-null sentinel that only a genuine selection produces.
    final selected = await showMenu<_RirChoice>(
      context: context,
      position: position,
      items: [
        for (final rir in kRirValues)
          PopupMenuItem<_RirChoice>(
            value: _RirChoice(rir),
            child: Text(formatRir(rir)),
          ),
      ],
    );
    if (selected != null && selected.value != value) onChanged(selected.value);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      child: SizedBox(
        height: 48,
        child: Center(
          child: Text(formatRir(value), style: style),
        ),
      ),
    );
  }
}

/// 56x56 hit area (design system): an outlined ring while pending, a filled
/// chalk disc with an `ink` checkmark once complete. No Material checkbox.
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
