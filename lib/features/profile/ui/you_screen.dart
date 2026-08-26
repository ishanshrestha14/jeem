import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../history/providers/history_providers.dart';
import '../../records/data/personal_records.dart';
import '../../records/providers/records_providers.dart';
import '../../../core/widgets/week_dot_strip.dart';

/// The You tab: what accumulates *because* you trained (S-005).
///
/// Two sections, both from real data — a Workout Log week strip over the
/// existing history, and lifetime personal records computed from logged sets.
/// Settings sits in the top bar rather than occupying a whole primary
/// destination, which is what it used to do.
///
/// S-005's other Overview sections are deliberately absent rather than faked:
/// trend charts need charting we have not built, and Muscle Recovery needs a
/// recovery model we do not have. The **sub-tab bar** (Overview · Exercises ·
/// Measures · Photos) is absent for the same reason — a bar where three of
/// four panes are empty is the mistake the five-tab shell already taught us.
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final history = ref.watch(historyProvider);
    final records = ref.watch(personalRecordsProvider);
    final sessions = history.valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('You'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _SectionHeading(
            title: 'Workout log',
            subtitle: 'See patterns in your workout history.',
          ),
          const SizedBox(height: 16),
          WeekDotStrip(
            today: DateTime.now(),
            trainedDays: {
              for (final s in sessions)
                s.session.endedAt ?? s.session.startedAt,
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/history'),
              child: const Text('See full workout history'),
            ),
          ),
          Divider(color: semantic.line, height: 32),
          _SectionHeading(
            title: 'Personal records',
            subtitle: 'See your best lifts and trends over time.',
          ),
          const SizedBox(height: 8),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                sessions.isEmpty
                    ? 'Finish a workout and your best lifts will show up here.'
                    : 'No weighted sets logged yet — records come from weight '
                        'and reps, so stretches and holds do not set them.',
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: semantic.muted),
              ),
            )
          else
            for (final record in records) _RecordRow(records: record),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(color: semantic.muted)),
      ],
    );
  }
}

/// CMP-021: one row per exercise, led by its heaviest lift, with the set that
/// produced it and the date beneath — a record reads better as a value plus
/// its set than as a bare number (S-005).
class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.records});

  final ExerciseRecords records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final best = records.headline;
    if (best == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  records.exerciseName,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM yyyy').format(best.achievedAt),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: semantic.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${formatWeight(best.weight)} kg',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatWeight(best.weight)}kg x ${best.reps} reps',
                style:
                    theme.textTheme.bodyMedium?.copyWith(color: semantic.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
