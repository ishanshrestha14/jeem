import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../history/providers/history_providers.dart';
import '../../sessions/data/session_models.dart';
import '../../templates/data/template_models.dart';
import '../../templates/providers/template_providers.dart';
import '../../templates/ui/start_workout_action.dart';

/// The Home tab: a dashboard built ONLY from data that exists today.
///
/// Deliberately does not render a streak, a chart, or any other placeholder
/// metric — a dashboard showing a hardcoded zero or a fake sparkline is
/// worse than one that shows less. Every element below reads a real
/// provider:
///  - quick start reads [templateSummariesProvider], sorted by
///    `TemplateSummary.lastPerformedAt` (nulls last);
///  - last workout reads [historyProvider].
///
/// Streaks/analytics are computed from completed sessions, and no session
/// can be completed until the finish-session flow exists — see the gap
/// left below rather than a placeholder section.
///
/// A live session is **not** surfaced here any more: the shell's
/// `WorkoutInProgressBar` (CMP-001, T-001) shows it above the nav on every
/// tab, so a Home-only resume card would be a second, less consistent way to
/// do the same thing.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(templateSummariesProvider);
    final completed = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            // A running session stays reachable here even with zero templates
            // left (e.g. the last one was deleted mid-workout): the shell's
            // WorkoutInProgressBar (CMP-001) sits above the nav on every tab,
            // so the empty state no longer strands the session the way it
            // would have when Home's resume card was the only way back.
            return _buildEmptyState(context);
          }

          final quickStart = _quickStart(rows);

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              _SectionHeader('Quick start'),
              const SizedBox(height: 8),
              for (final s in quickStart)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _QuickStartCard(summary: s),
                ),
              const SizedBox(height: 8),
              _SectionHeader('Last workout'),
              const SizedBox(height: 8),
              completed.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (sessions) => _LastWorkout(
                  session: sessions.isEmpty ? null : sessions.first,
                ),
              ),

              // --- Streaks / analytics ------------------------------------
              // Intentionally absent. Both are computed from completed
              // sessions, and no session can be completed yet — the
              // finish-session flow (which writes `SessionStatus.completed`)
              // is a later task. This section lands once that flow exists;
              // until then an empty shell here would just be another fake
              // metric.
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return EmptyState(
      icon: Icons.fitness_center,
      title: 'No workouts yet',
      message:
          'Build a template in the Workout tab so you can start a workout in seconds.',
      actionLabel: 'Go to Workout',
      onAction: () => context.go('/workout'),
    );
  }

  /// The 2-3 most recently performed templates, most recent first. A
  /// template that has never been performed (`lastPerformedAt == null`)
  /// sorts after every performed one.
  List<TemplateSummary> _quickStart(List<TemplateSummary> rows) {
    final sorted = [...rows]..sort((a, b) {
        final aT = a.lastPerformedAt;
        final bT = b.lastPerformedAt;
        if (aT == null && bT == null) return 0;
        if (aT == null) return 1;
        if (bT == null) return -1;
        return bT.compareTo(aT);
      });
    return sorted.take(3).toList();
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).extension<SemanticColors>()!.muted;
    return Text(
      label.toUpperCase(),
      style: AppTheme.columnHeader.copyWith(color: muted),
    );
  }
}

class _QuickStartCard extends ConsumerWidget {
  const _QuickStartCard({required this.summary});

  final TemplateSummary summary;

  String _pluralise(int count, String noun) =>
      count == 1 ? '1 $noun' : '$count ${noun}s';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.extension<SemanticColors>()!.muted;
    final canStart = summary.exerciseCount > 0;
    final metadata =
        '${_pluralise(summary.exerciseCount, 'exercise')} · ${_pluralise(summary.totalSets, 'set')}';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.template.name, style: AppTheme.exerciseName.copyWith(
                    color: theme.colorScheme.onSurface,
                  )),
                  const SizedBox(height: 4),
                  Text(metadata, style: AppTheme.body.copyWith(color: muted)),
                  if (!canStart) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Add an exercise before you can start',
                      style: AppTheme.body.copyWith(color: muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: canStart
                  ? () => startWorkout(context, ref, summary.template.id)
                  : null,
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single line: the most recent completed session, or a prompt to start
/// the first one if [session] is null. Not the full [EmptyState] widget
/// (which is built to fill a whole screen) — this is one line among
/// several sections — but it follows the same voice and the same
/// "hairline rule, no box chrome, muted colour" language.
class _LastWorkout extends StatelessWidget {
  const _LastWorkout({required this.session});

  final ActiveSession? session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    if (session == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: semantic.line)),
        ),
        child: Text(
          'Finish a workout and it will show up here.',
          style: AppTheme.body.copyWith(color: semantic.muted),
        ),
      );
    }

    final endedAt = session!.session.endedAt;
    final dateText =
        endedAt == null ? '' : DateFormat.yMMMd().format(endedAt);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: semantic.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              session!.session.name,
              style: AppTheme.exerciseName.copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
          Text(dateText, style: AppTheme.body.copyWith(color: semantic.muted)),
        ],
      ),
    );
  }
}
