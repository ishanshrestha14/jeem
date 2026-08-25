import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/empty_state.dart';
import '../../library/ui/library_screen.dart' show InitialsTile;
import '../data/template_models.dart';
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
          PopupMenuButton<String>(
            onSelected: (_) => context.push('/templates/$templateId'),
            itemBuilder: (_) => const [
              PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
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
