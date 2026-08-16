import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../exercises/ui/exercise_info_sheet.dart';
import '../providers/active_session_controller.dart';
import 'widgets/rest_bar.dart';

/// Full-screen drag-to-reorder view for the "machine is occupied" flow
/// (PRD §11.3). Deliberately a pushed screen, not a bottom sheet — dragging
/// inside a sheet fights the sheet's own drag gesture.
///
/// Completed exercises are locked at the front (PRD §11.2): rendered in a
/// plain, non-reorderable list above a "Completed" divider, dimmed, with a
/// [Icons.lock_outline] trailing icon and no drag handle. Only the pending
/// sublist is reorderable, and `ReorderableListView.onReorder`'s indices are
/// passed straight through to `ActiveSessionController.reorder` — they are
/// already pending-relative and already in the "raw, pre-removal newIndex"
/// shape `reorderPending` expects; correcting them here would double-correct
/// downward drags.
///
/// Reordering never touches the rest timer (PRD §18.8) — this screen mounts
/// the same [RestBar] the session screen does, in the same
/// `bottomNavigationBar` slot, so a running rest keeps ticking undisturbed
/// while the user reorders. It shows no bottom nav — like `/session`, this
/// is a pushed full-screen route outside the tab shell.
class SessionReorderScreen extends ConsumerWidget {
  const SessionReorderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeSessionControllerProvider);
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (state) {
        if (state == null) return const Scaffold(body: SizedBox.shrink());
        return _ReorderScaffold(state: state);
      },
    );
  }
}

class _ReorderScaffold extends ConsumerWidget {
  const _ReorderScaffold({required this.state});

  final ActiveSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final controller = ref.read(activeSessionControllerProvider.notifier);
    final session = state.session;
    final completed =
        session.exercises.where((e) => e.isComplete).toList(growable: false);
    final pending = pendingExercises(session);

    return Scaffold(
      appBar: AppBar(title: const Text('Reorder exercises')),
      body: Column(
        children: [
          if (completed.isNotEmpty) ...[
            for (final entry in completed)
              ListTile(
                key: ValueKey('locked-${entry.exercise.id}'),
                title: Text(
                  entry.exercise.name,
                  style: AppTheme.exerciseName.copyWith(color: semantic.muted),
                ),
                trailing: Icon(Icons.lock_outline, color: semantic.muted),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Container(height: 1, color: semantic.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'COMPLETED',
                      style: AppTheme.columnHeader.copyWith(color: semantic.muted),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: semantic.line)),
                ],
              ),
            ),
          ],
          Expanded(
            child: pending.isEmpty
                ? Center(
                    child: Text(
                      'Nothing left to reorder',
                      style: AppTheme.body.copyWith(color: semantic.muted),
                    ),
                  )
                : ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: pending.length,
                    onReorder: (oldIndex, newIndex) =>
                        controller.reorder(oldIndex, newIndex),
                    itemBuilder: (context, i) {
                      final entry = pending[i];
                      final exercise = entry.exercise;
                      final setsLeft = entry.sets.length - entry.completedSetCount;
                      return ListTile(
                        key: ValueKey(exercise.id),
                        title: Text(
                          exercise.name,
                          style: AppTheme.exerciseName
                              .copyWith(color: Theme.of(context).colorScheme.onSurface),
                        ),
                        subtitle: Text(
                          '$setsLeft sets left · '
                          '${formatDurationSeconds(exercise.restSeconds)} rest',
                          style: AppTheme.body.copyWith(color: semantic.muted),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            ReorderableDragStartListener(
                              index: i,
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar:
          state.rest.isActive || state.restJustFinished ? const RestBar() : null,
    );
  }
}
