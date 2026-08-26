import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/numeric_field.dart';
import '../../../../db/app_database.dart';
import '../../../exercises/ui/exercise_info_sheet.dart';
import '../../providers/active_session_controller.dart';
import '../../providers/previous_best_provider.dart';
import 'duration_set_row.dart';
import 'previous_best_line.dart';
import 'strength_set_row.dart';

/// `SET / KG / REPS / RIR` (or `SET / DURATION`) column headers, rendered
/// once per exercise above its rows — never repeated per row (design
/// system). Mirrors the `[28][flex 3][flex 2][flex 3][56]` grammar the rows
/// themselves use so the labels land directly above their column.
class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders({required this.isDuration, required this.weightUnit});

  final bool isDuration;

  /// Read from `session.weightUnit` rather than hardcoded — this header
  /// otherwise lies outright the moment a session is started with anything
  /// other than 'kg' (e.g. 'lb').
  final String weightUnit;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final style = AppTheme.columnHeader.copyWith(color: semantic.muted);
    Widget label(String text) => Text(text, style: style);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        children: [
          SizedBox(width: 28, child: label('SET')),
          const SizedBox(width: 8),
          if (isDuration) ...[
            Expanded(flex: 3, child: Center(child: label('DURATION'))),
            const Expanded(flex: 4, child: SizedBox.shrink()),
          ] else ...[
            Expanded(flex: 3, child: Center(child: label(weightUnit.toUpperCase()))),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: Center(child: label('REPS'))),
            const SizedBox(width: 8),
            Expanded(flex: 3, child: Center(child: label('RIR'))),
          ],
          const SizedBox(width: 8),
          const SizedBox(width: 56),
        ],
      ),
    );
  }
}

/// 1px hairline separator between set rows, inset to start at the KG column
/// so the set-number gutter stays visually open (design system).
class _RowSeparator extends StatelessWidget {
  const _RowSeparator();

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(left: 40),
      child: Container(height: 1, color: semantic.line),
    );
  }
}

/// One exercise within the active session: header (name, info, rest chip,
/// expand toggle), then either an expanded body of set rows plus "Add set"
/// / "Do later", or a one-line collapsed summary.
class SessionExerciseCard extends ConsumerWidget {
  const SessionExerciseCard({
    super.key,
    this.cardKey,
    required this.entry,
    required this.expanded,
    this.keypadSortKeyBase,
    required this.weightUnit,
    required this.currentSetId,
    required this.onToggleExpand,
    this.onDoLater,
    this.onDoNext,
  });

  final GlobalKey? cardKey;
  final SessionExerciseWithSets entry;
  final bool expanded;

  /// Start of this exercise's slice of the keypad entry order. Sets take two
  /// slots each (weight, reps), so the base is spaced far enough apart that
  /// exercises never interleave. Null keeps the system keyboard.
  final int? keypadSortKeyBase;
  final String weightUnit;
  final String? currentSetId;
  final VoidCallback onToggleExpand;

  /// Non-null (and rendered as a "Do later" button) only on the current
  /// exercise card — sends it behind every other pending exercise in one
  /// tap (PRD §11.3).
  final VoidCallback? onDoLater;

  /// Non-null (and rendered as a "Do next" button) on upcoming, non-current
  /// pending cards — jumps that exercise straight to the front of the
  /// pending queue.
  final VoidCallback? onDoNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final controller = ref.read(activeSessionControllerProvider.notifier);
    final exercise = entry.exercise;

    return Card(
      key: cardKey,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: entry.isComplete
              ? Border(left: BorderSide(color: semantic.success, width: 4))
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: AppTheme.exerciseName
                          .copyWith(color: theme.colorScheme.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'Exercise info',
                    // Opens the full detail screen (S-025), so an exercise has
                    // one surface everywhere — including History, which is
                    // worth reaching mid-workout.
                    //
                    // Falls back to the sheet when the session's snapshot has
                    // no `exerciseId`: a session outlives the exercise it was
                    // built from, and there is no detail screen for one that no
                    // longer exists. The snapshot still carries the text, so
                    // the sheet still says something useful.
                    onPressed: () {
                      final id = exercise.exerciseId;
                      if (id != null) {
                        context.push('/exercises/$id/detail');
                        return;
                      }
                      showExerciseInfoSheet(
                        context,
                        name: exercise.name,
                        loggingType: exercise.loggingType,
                        description: exercise.description,
                        notes: exercise.notes,
                        imagePath: exercise.imagePath,
                      );
                    },
                  ),
                  ActionChip(
                    label: Text(formatDurationSeconds(exercise.restSeconds)),
                    onPressed: () => _showRestSheet(context, controller),
                  ),
                  IconButton(
                    icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    tooltip: expanded ? 'Collapse' : 'Expand',
                    onPressed: onToggleExpand,
                  ),
                ],
              ),
              if (expanded) ...[
                // S-006's `Previous`, once per exercise rather than per row —
                // it is the best set of the last session, so it is the same
                // value on every row. Absent entirely when there is no
                // history for this exercise.
                PreviousBestLine(
                  best: ref.watch(previousBestProvider)[
                      exercise.exerciseId ?? exercise.name],
                  weightUnit: weightUnit,
                ),
                const SizedBox(height: 8),
                _ColumnHeaders(
                  isDuration: exercise.loggingType != LoggingType.strengthWeightRepsRir,
                  weightUnit: weightUnit,
                ),
                for (var i = 0; i < entry.sets.length; i++) ...[
                  if (i > 0) const _RowSeparator(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Builder(builder: (context) {
                      final set = entry.sets[i];
                      return exercise.loggingType ==
                              LoggingType.strengthWeightRepsRir
                          ? StrengthSetRow(
                              set: set,
                              isCurrent: set.id == currentSetId,
                              keypadSortKey: keypadSortKeyBase == null
                                  ? null
                                  : keypadSortKeyBase! + i * 2,
                              weightUnit: weightUnit,
                              onToggleComplete: () => set.completedAt == null
                                  ? controller.completeSet(set.id)
                                  : controller.uncompleteSet(set.id),
                              onWeightChanged: (v) =>
                                  controller.updateSetValues(
                                set.id,
                                weight: v,
                                clearWeight: v == null,
                              ),
                              onRepsChanged: (v) => controller.updateSetValues(
                                set.id,
                                reps: v,
                                clearReps: v == null,
                              ),
                              onRirChanged: (v) => controller.updateSetValues(
                                set.id,
                                rir: v,
                                clearRir: v == null,
                              ),
                              onLongPress: set.completedAt == null
                                  ? () => _handleLongPress(
                                      context, controller, set.id)
                                  : null,
                            )
                          : DurationSetRow(
                              set: set,
                              isCurrent: set.id == currentSetId,
                              onToggleComplete: () => set.completedAt == null
                                  ? controller.completeSet(set.id)
                                  : controller.uncompleteSet(set.id),
                              onDurationChanged: (v) =>
                                  controller.updateSetValues(
                                set.id,
                                durationSeconds: v,
                                clearDuration: v == null,
                              ),
                              onLongPress: set.completedAt == null
                                  ? () => _handleLongPress(
                                      context, controller, set.id)
                                  : null,
                            );
                    }),
                  ),
                ],
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => controller.addSet(exercise.id),
                      icon: const Icon(Icons.add),
                      label: const Text('Add set'),
                    ),
                    if (!entry.isComplete && onDoLater != null)
                      TextButton.icon(
                        onPressed: onDoLater,
                        icon: const Icon(Icons.schedule),
                        label: const Text('Do later'),
                      ),
                    if (!entry.isComplete && onDoNext != null)
                      TextButton.icon(
                        onPressed: onDoNext,
                        icon: const Icon(Icons.fast_forward),
                        label: const Text('Do next'),
                      ),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${entry.completedSetCount}/${entry.sets.length} sets · '
                    '${formatDurationSeconds(exercise.restSeconds)} rest',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLongPress(
    BuildContext context,
    ActiveSessionController controller,
    String setId,
  ) async {
    if (entry.sets.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add another set before removing this one'),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline),
          title: const Text('Remove set'),
          onTap: () => Navigator.of(ctx).pop('remove'),
        ),
      ),
    );
    if (action != 'remove') return;
    await controller.removeSet(setId);
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Set removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.addSet(entry.exercise.id),
        ),
      ),
    );
  }

  Future<void> _showRestSheet(
    BuildContext context,
    ActiveSessionController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _RestSheet(
        initialSeconds: entry.exercise.restSeconds,
        onChanged: (seconds) =>
            controller.setExerciseRest(entry.exercise.id, seconds),
      ),
    );
  }
}

class _RestSheet extends StatefulWidget {
  const _RestSheet({required this.initialSeconds, required this.onChanged});

  final int initialSeconds;
  final ValueChanged<int> onChanged;

  @override
  State<_RestSheet> createState() => _RestSheetState();
}

class _RestSheetState extends State<_RestSheet> {
  late int _seconds = widget.initialSeconds;

  void _apply(int seconds) {
    setState(() => _seconds = seconds);
    widget.onChanged(seconds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rest between sets', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            NumericField(
              label: 'Rest',
              value: _seconds,
              min: 0,
              max: 3600,
              suffix: 's',
              onChanged: (v) => _apply((v ?? 0).toInt()),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in kRestPresets)
                  ActionChip(
                    label: Text(formatDurationSeconds(preset)),
                    onPressed: () => _apply(preset),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
