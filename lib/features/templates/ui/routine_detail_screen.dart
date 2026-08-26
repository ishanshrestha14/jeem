import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/initials_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/template_models.dart';
import '../data/template_repository.dart';
import '../providers/template_providers.dart';
import 'start_workout_action.dart';

/// S-030 — the read-only view of one routine: what it holds, when you last did
/// it, and one large button to start it.
///
/// This is the surface between *finding* a routine and *doing* it, and it is
/// why tapping a routine no longer opens the editor. You start a routine many
/// times for every time you edit it, so starting is the primary action here
/// and editing is demoted to the overflow menu.
class RoutineDetailScreen extends ConsumerWidget {
  const RoutineDetailScreen({super.key, required this.templateId});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routine = ref.watch(templateProvider(templateId));

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<_RoutineAction>(
            onSelected: (action) =>
                _handleAction(context, ref, action, templateId),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _RoutineAction.edit, child: Text('Edit')),
              PopupMenuItem(
                  value: _RoutineAction.duplicate, child: Text('Duplicate')),
              PopupMenuItem(
                  value: _RoutineAction.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: routine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          // Deleted while the screen was open: pop rather than render a shell
          // of a routine that no longer exists.
          if (data == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) Navigator.of(context).maybePop();
            });
            return const SizedBox.shrink();
          }
          return _Body(routine: data, templateId: templateId);
        },
      ),
      bottomNavigationBar: routine.valueOrNull == null
          ? null
          : _StartBar(
              templateId: templateId,
              enabled: routine.valueOrNull!.canStart,
            ),
    );
  }
}

/// Everything you can do to a routine as a whole.
///
/// All three live here because this is the surface dedicated to one routine.
/// Duplicate and Delete were on the old Workout tab's routine cards until
/// [T-013] retired that screen, which left them with no home at all — the
/// regression this menu closes.
enum _RoutineAction { edit, duplicate, delete }

Future<void> _handleAction(
  BuildContext context,
  WidgetRef ref,
  _RoutineAction action,
  String templateId,
) async {
  final repo = ref.read(templateRepositoryProvider);
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  switch (action) {
    case _RoutineAction.edit:
      context.push('/templates/$templateId');

    case _RoutineAction.duplicate:
      final copy = await repo.duplicateTemplate(templateId);
      messenger.showSnackBar(
        SnackBar(content: Text('Duplicated as "${copy.name}"')),
      );

    case _RoutineAction.delete:
      final ok = await confirmDestructive(
        context,
        title: 'Delete this routine?',
        message: 'Sessions you have already logged from it are not affected — '
            'they keep their own copy of what you did.',
        confirmLabel: 'Delete routine',
      );
      if (!ok) return;
      await repo.deleteTemplate(templateId);
      // Nothing left to show. The stream would emit null and this screen pops
      // itself anyway, but popping here keeps it immediate.
      navigator.maybePop();
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.routine, required this.templateId});

  final TemplateWithExercises routine;
  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    // `lastPerformedAt` lives on the summary rather than the routine itself —
    // it is derived from session history, and the Library already watches it
    // for its "Recent" sort, so this costs no new query.
    final summary = ref
        .watch(templateSummariesProvider)
        .valueOrNull
        ?.where((s) => s.template.id == templateId)
        .firstOrNull;
    final lastPerformed = summary?.lastPerformedAt;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(routine.template.name, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          lastPerformed == null
              ? 'Never performed'
              : 'Last performed: ${relativeDay(lastPerformed)}',
          style: theme.textTheme.bodyMedium?.copyWith(color: semantic.muted),
        ),
        const SizedBox(height: 16),
        _StatsTile(totalSets: routine.totalSets),
        const SizedBox(height: 16),
        if (routine.exercises.isEmpty)
          const EmptyState(
            icon: Icons.fitness_center,
            title: 'No exercises yet',
            message: 'Add exercises to this routine before starting it.',
          )
        else
          for (final e in routine.exercises) _ExerciseRow(exercise: e),
      ],
    );
  }
}

/// The bordered stat row under the name. Total sets only: the reference also
/// shows an estimated duration and an anatomical figure, neither of which we
/// have — and its figure must not be copied (S-030, open questions).
class _StatsTile extends StatelessWidget {
  const _StatsTile({required this.totalSets});

  final int totalSets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(color: semantic.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('Total sets',
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: semantic.muted)),
          const SizedBox(height: 4),
          Text('$totalSets', style: theme.textTheme.headlineSmall),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final TemplateExerciseWithExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final image = exercise.exercise.imagePath;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // The initials tile is the default rather than a fallback: most
          // exercises carry no image, and a ragged column of blanks reads
          // worse than a consistent one of tiles.
          if (image == null)
            InitialsTile(name: exercise.name)
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(image),
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => InitialsTile(name: exercise.name),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  exercise.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  describeTemplateExercise(exercise),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: semantic.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartBar extends ConsumerWidget {
  const _StartBar({required this.templateId, required this.enabled});

  final String templateId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        height: 56,
        child: FilledButton(
          onPressed:
              enabled ? () => startWorkout(context, ref, templateId) : null,
          child: const Text('Start workout'),
        ),
      ),
    );
  }
}
