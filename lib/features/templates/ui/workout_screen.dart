import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/template_models.dart';
import '../data/template_repository.dart';
import '../providers/template_providers.dart';
import 'start_workout_action.dart';

/// The Workout tab: the list of workout templates a session is started
/// from. Formerly `HomeScreen` (`home_screen.dart`) when this was the
/// Workouts destination — renamed to reflect its place in the Home / Workout
/// / History / Profile IA. Behaviour (template cards, FAB, overflow menu,
/// Start button and its disabled-with-helper-text state) is unchanged; only
/// the resume-in-progress banner moved to the Home tab (it reads
/// `activeSessionProvider` directly there) and the exercise library moved
/// behind the `EXERCISES` header action below rather than being a peer tab.
class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(templateSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: _ExercisesAction(
                // Explore is a tab now, so this switches branch rather than
                // pushing a second copy of the library on top of Workout.
                onTap: () => context.go('/explore'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/templates/new'),
        icon: const Icon(Icons.add),
        label: const Text('New workout'),
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.fitness_center,
              title: 'No workouts yet',
              message:
                  'Build a template with your exercises so you can start a workout in seconds.',
              actionLabel: 'Create your first workout',
              onAction: () => context.push('/templates/new'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: rows.length,
            itemBuilder: (_, i) => _TemplateCard(summary: rows[i]),
          );
        },
      ),
    );
  }
}

/// Header micro-label action that pushes the exercise library — exercises
/// are material for building workouts, not a peer destination, so they live
/// one tap away from here rather than in the bottom nav (docs/design/
/// gymflow-design-system.md micro-label style: 11px, w600, letterSpacing
/// 1.2, uppercase, `muted`).
class _ExercisesAction extends StatelessWidget {
  const _ExercisesAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<SemanticColors>()!.muted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          'EXERCISES',
          style: AppTheme.columnHeader.copyWith(color: muted),
        ),
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.summary});

  final TemplateSummary summary;

  String _pluralise(int count, String noun) =>
      count == 1 ? '1 $noun' : '$count ${noun}s';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.extension<SemanticColors>()!.muted;
    final template = summary.template;
    final canStart = summary.exerciseCount > 0;

    var metadata =
        '${_pluralise(summary.exerciseCount, 'exercise')} · ${_pluralise(summary.totalSets, 'set')}';
    if (summary.lastPerformedAt != null) {
      metadata +=
          ' · Last: ${DateFormat.MMMd().format(summary.lastPerformedAt!)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/templates/${template.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(template.name, style: theme.textTheme.titleLarge),
                  ),
                  PopupMenuButton<_TemplateAction>(
                    onSelected: (action) =>
                        _handleAction(context, ref, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _TemplateAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: _TemplateAction.duplicate,
                        child: Text('Duplicate'),
                      ),
                      PopupMenuItem(
                        value: _TemplateAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                metadata,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: canStart
                      ? () => startWorkout(context, ref, template.id)
                      : null,
                  child: const Text('Start'),
                ),
              ),
              if (!canStart) ...[
                const SizedBox(height: 4),
                Text(
                  'Add an exercise before you can start',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _TemplateAction action,
  ) async {
    final repo = ref.read(templateRepositoryProvider);
    switch (action) {
      case _TemplateAction.edit:
        context.push('/templates/${summary.template.id}');
      case _TemplateAction.duplicate:
        await repo.duplicateTemplate(summary.template.id);
      case _TemplateAction.delete:
        final confirmed = await confirmDestructive(
          context,
          title: 'Delete "${summary.template.name}"?',
          message:
              'This removes the workout template. This cannot be undone.',
          confirmLabel: 'Delete',
        );
        if (confirmed) {
          await repo.deleteTemplate(summary.template.id);
        }
    }
  }
}

enum _TemplateAction { edit, duplicate, delete }
