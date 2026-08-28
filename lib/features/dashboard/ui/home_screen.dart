import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../history/providers/history_providers.dart';
import '../../records/data/personal_records.dart';
import '../../records/providers/records_providers.dart';
import '../../sessions/data/session_models.dart';
import '../../settings/providers/settings_providers.dart';
import '../../templates/ui/start_workout_action.dart';
import '../domain/weekly_summary.dart';

/// How many workouts Home lists before deferring to the History screen.
/// Home is a recap; History is the archive. Listing everything here would make
/// them the same screen.
const _recentLimit = 5;

/// S-001 — recap. The week so far, then the last few workouts.
///
/// The reference Home is a social feed; everything social is deliberately out
/// of scope (see the spec). What survives is the useful half: the weekly
/// summary header and the session list.
///
/// Deliberately **not** a routine list. Routines live in the Library (S-004)
/// and the Workout tab suggests them (S-003); a third copy here was the same
/// duplication T-011 and T-013 removed.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final history = ref.watch(historyProvider).valueOrNull ?? const [];
    final unit = ref.watch(settingsProvider).weightUnit;
    final summary = weeklySummary(history, now: DateTime.now(), displayUnit: unit);
    final recent = history.take(_recentLimit).toList();
    final records = ref.watch(personalRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text('Your weekly summary', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Workouts',
                  value: '${summary.workouts}',
                  delta: summary.workoutsDelta.toDouble(),
                  deltaLabel: '${summary.workoutsDelta.abs()}',
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Duration',
                  value: mmss(summary.duration),
                  delta: summary.durationDelta.inSeconds.toDouble(),
                  deltaLabel: mmss(summary.durationDelta.abs()),
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Volume',
                  value: '${summary.volume.round()}',
                  delta: summary.volumeDelta,
                  deltaLabel: '${summary.volumeDelta.abs().round()} $unit',
                ),
              ),
            ],
          ),
          Divider(color: semantic.line, height: 32),
          if (recent.isEmpty)
            const _FirstWorkoutCard()
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text('Recent workouts',
                      style: theme.textTheme.titleMedium),
                ),
                TextButton(
                  onPressed: () => context.push('/history'),
                  child: const Text('See all'),
                ),
              ],
            ),
            for (final s in recent)
              _WorkoutRow(session: s, records: recordsSetIn(s, records)),
          ],
        ],
      ),
    );
  }
}

/// CMP-008 + CMP-013: one metric, with its change against last week beneath.
class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaLabel,
  });

  final String label;
  final String value;

  /// Signed, and used only for direction and colour — [deltaLabel] carries
  /// the text, so each metric can format its own units.
  final double delta;
  final String deltaLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: AppTheme.columnHeader.copyWith(color: semantic.muted)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        // No chip at all when nothing changed: an unchanging "0" under every
        // metric is noise, and the first week has nothing to compare against.
        if (delta != 0)
          Text(
            '${delta > 0 ? '▲' : '▼'} $deltaLabel',
            style: theme.textTheme.bodySmall?.copyWith(
              // Only an increase is coloured. A quieter week is not a failure
              // and should not be painted like one — `danger` is for
              // destructive actions (design system).
              color: delta > 0 ? semantic.success : semantic.muted,
            ),
          ),
      ],
    );
  }
}

/// CMP-014, the first-run card. S-001 nags on Home and stays silent during a
/// session — motivational copy belongs where you are deciding, never where you
/// are working.
class _FirstWorkoutCard extends ConsumerWidget {
  const _FirstWorkoutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: semantic.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center, size: 40, color: semantic.muted),
          const SizedBox(height: 16),
          Text('Ready to start lifting?',
              style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Complete your first workout to start seeing your progress.',
            style:
                theme.textTheme.bodyMedium?.copyWith(color: semantic.muted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => startAdHocWorkout(context, ref),
            child: const Text('Start workout'),
          ),
        ],
      ),
    );
  }
}

/// CMP-012's structure with the social layer removed: name, when, and the two
/// numbers. Tapping opens the session's read-only summary.
class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.session, this.records = 0});

  final ActiveSession session;

  /// How many exercises this workout holds a **currently standing** record for
  /// (S-001's `Records 🏅 N`). Zero hides the badge — most workouts set no
  /// record, and a `0 records` line on every row would be noise.
  final int records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final workout = session.session;
    final endedAt = workout.endedAt;
    final duration = endedAt == null
        ? Duration.zero
        : endedAt.difference(workout.startedAt) -
            Duration(seconds: workout.pausedSeconds);

    return InkWell(
      onTap: () =>
          context.push('/session/summary/${workout.id}?readOnly=true'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                    '${relativeDay(endedAt ?? workout.startedAt)} · '
                    '${DateFormat.jm().format(endedAt ?? workout.startedAt)}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: semantic.muted),
                  ),
                  if (records > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '🏅 $records ${records == 1 ? 'record' : 'records'}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: semantic.success),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '${mmss(duration)} · '
              '${session.completedVolume.round()} ${workout.weightUnit}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: semantic.muted),
            ),
          ],
        ),
      ),
    );
  }
}
