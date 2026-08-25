import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/utils/formatting.dart';
import '../../../db/app_database.dart';
import '../../history/providers/history_providers.dart';
import '../../profile/ui/widgets/week_dot_strip.dart';
import '../../sessions/data/session_models.dart';
import '../../sessions/data/session_repository.dart';
import '../data/template_models.dart';
import '../domain/workout_day.dart';
import '../providers/template_providers.dart';
import 'start_workout_action.dart';

/// S-003 — the day launchpad. Answers one question, *what am I doing today?*,
/// and gets you into a session in as few taps as possible.
///
/// Deliberately **not** a routine list any more: routines live in the Library
/// (S-004) with their own detail screen since T-011, and keeping a second copy
/// here made the two tabs near-duplicates.
class WorkoutScreen extends ConsumerWidget {
  const WorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final today = DateTime.now();

    final history = ref.watch(historyProvider).valueOrNull ?? const [];
    final routines =
        ref.watch(templateSummariesProvider).valueOrNull ?? const [];

    final todays = sessionsOn(history, day: today);
    final suggestions = suggestedRoutines(routines);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(DateFormat('MMMM d').format(today)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // The shell keeps every tab alive in an IndexedStack, so this FAB and
        // Explore's are heroes in one subtree. Sharing the default tag makes a
        // route push throw "multiple heroes that share the same tag".
        heroTag: 'workout-start-fab',
        onPressed: () => startAdHocWorkout(context, ref),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Start new workout'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          WeekDotStrip(
            today: today,
            trainedDays: {
              for (final s in history) s.session.endedAt ?? s.session.startedAt,
            },
          ),
          Divider(color: semantic.line, height: 32),
          if (todays.isEmpty) ...[
            Text('No workouts today', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            const _StartRow(),
          ] else ...[
            Text('Workouts', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final s in todays) _SessionCard(session: s),
            const SizedBox(height: 8),
            const _StartRow(label: 'Log another workout'),
          ],
          // The suggestion disappears once you have trained today. The
          // reference does this too, and it is the better behaviour: a stale
          // "do this next" prompt after the work is done is one more decision
          // for no reason.
          if (todays.isEmpty && suggestions.isNotEmpty) ...[
            Divider(color: semantic.line, height: 32),
            Text('Suggested routines', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final s in suggestions.take(3)) _SuggestionRow(summary: s),
          ],
        ],
      ),
    );
  }
}

/// The full-width row CTA S-003 uses instead of a button: a whole tappable
/// row, so it reads as the surface's one obvious next move.
class _StartRow extends ConsumerWidget {
  const _StartRow({this.label = 'Start new workout'});

  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    return InkWell(
      onTap: () => startAdHocWorkout(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: semantic.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Add exercises and start logging',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: semantic.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: semantic.muted),
          ],
        ),
      ),
    );
  }
}

/// One session logged today: name, when, and the two numbers worth seeing.
class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final workout = session.session;
    final endedAt = workout.endedAt;
    final duration = endedAt == null
        ? Duration.zero
        : endedAt.difference(workout.startedAt) -
            Duration(seconds: workout.pausedSeconds);
    final volume = session.completedVolume;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(workout.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Today at ${DateFormat.jm().format(endedAt ?? workout.startedAt)}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: semantic.muted),
                ),
              ],
            ),
          ),
          _Stat(label: 'Duration', value: mmss(duration)),
          const SizedBox(width: 20),
          _Stat(
            label: 'Volume',
            value: '${volume.round()} ${workout.weightUnit}',
          ),
          PopupMenuButton<String>(
            onSelected: (_) => _confirmDelete(context, ref, workout),
            itemBuilder: (_) => const [
              PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  /// Deleting a logged workout also re-derives records, `Previous` and every
  /// volume total, since all of those are computed from completed sessions
  /// rather than stored. That is correct but invisible, so the copy says it.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    WorkoutSession workout,
  ) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete this workout?',
      message: 'Its sets, and any records it set, will be removed from your '
          'history.',
      confirmLabel: 'Delete workout',
    );
    if (!ok) return;
    await ref.read(sessionRepositoryProvider).deleteSession(workout.id);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: AppTheme.columnHeader.copyWith(color: semantic.muted)),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

/// A suggested routine: tapping opens its detail screen (S-030), the play
/// button starts it outright — the same pair of affordances the Library gives
/// a routine, so a routine behaves the same wherever it is offered.
class _SuggestionRow extends ConsumerWidget {
  const _SuggestionRow({required this.summary});

  final TemplateSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final last = summary.lastPerformedAt;

    return InkWell(
      onTap: () => context.push('/templates/${summary.template.id}/detail'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(summary.template.name,
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    last == null
                        ? 'Never performed'
                        : 'Last performed: ${relativeDay(last)}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: semantic.muted),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Start ${summary.template.name}',
              onPressed: () =>
                  startWorkout(context, ref, summary.template.id),
            ),
          ],
        ),
      ),
    );
  }
}
