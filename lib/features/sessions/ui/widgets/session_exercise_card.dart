import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/semantic_colors.dart';
import '../../../../core/utils/constants.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/numeric_field.dart';
import '../../../../db/app_database.dart';
import '../../../exercises/ui/exercise_info_sheet.dart';
import '../../providers/active_session_controller.dart';
import 'duration_set_row.dart';
import 'strength_set_row.dart';

/// One exercise within the active session: header (name, info, rest chip,
/// expand toggle), then either an expanded body of set rows plus "Add set"
/// / "Do later", or a one-line collapsed summary.
class SessionExerciseCard extends ConsumerWidget {
  const SessionExerciseCard({
    super.key,
    this.cardKey,
    required this.entry,
    required this.expanded,
    required this.weightUnit,
    required this.currentSetId,
    required this.onToggleExpand,
    this.canDoLater = false,
  });

  final GlobalKey? cardKey;
  final SessionExerciseWithSets entry;
  final bool expanded;
  final String weightUnit;
  final String? currentSetId;
  final VoidCallback onToggleExpand;
  final bool canDoLater;

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
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    tooltip: 'Exercise info',
                    onPressed: () => showExerciseInfoSheet(
                      context,
                      name: exercise.name,
                      loggingType: exercise.loggingType,
                      description: exercise.description,
                      notes: exercise.notes,
                      imagePath: exercise.imagePath,
                    ),
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
                const SizedBox(height: 8),
                for (final set in entry.sets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: exercise.loggingType ==
                            LoggingType.strengthWeightRepsRir
                        ? StrengthSetRow(
                            set: set,
                            isCurrent: set.id == currentSetId,
                            weightUnit: weightUnit,
                            onToggleComplete: () => set.completedAt == null
                                ? controller.completeSet(set.id)
                                : controller.uncompleteSet(set.id),
                            onWeightChanged: (v) => controller.updateSetValues(
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
                          ),
                  ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => controller.addSet(exercise.id),
                      icon: const Icon(Icons.add),
                      label: const Text('Add set'),
                    ),
                    if (!entry.isComplete && canDoLater)
                      TextButton.icon(
                        onPressed: () => controller.doLater(exercise.id),
                        icon: const Icon(Icons.schedule),
                        label: const Text('Do later'),
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
