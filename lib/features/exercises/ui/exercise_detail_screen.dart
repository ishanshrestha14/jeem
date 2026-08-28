import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../db/app_database.dart';
import '../../history/providers/history_providers.dart';
import '../../records/data/personal_records.dart';
import '../../records/providers/records_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../domain/exercise_history.dart';
import '../providers/exercise_providers.dart';

/// S-025 — everything known about one exercise: how to do it, what you have
/// done, and your best.
///
/// Three panes, not the reference's five. `Progress` needs charting this app
/// has none of (the gap analysis marks it Later), and `Leaderboard` is social,
/// which [00-overview §5] puts out of scope.
///
/// The in-session ℹ still opens the small info sheet (S-013) rather than this:
/// mid-set you want a glance, and pushing a tabbed screen navigates away from a
/// running workout.
class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(exerciseByIdProvider(exerciseId));

    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (exercise) {
        if (exercise == null) {
          // Deleted while open — pop rather than render a shell.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).maybePop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text(exercise.name),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (_) => context.push('/exercises/$exerciseId'),
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  ],
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'About'),
                  Tab(text: 'History'),
                  Tab(text: 'Records'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _AboutPane(exercise: exercise),
                _HistoryPane(exercise: exercise),
                _RecordsPane(exercise: exercise),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AboutPane extends ConsumerWidget {
  const _AboutPane({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final taxonomy =
        ref.watch(exerciseTaxonomyProvider(exercise.id)).valueOrNull;
    final image = exercise.imagePath;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (image != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(image),
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (exercise.description != null) ...[
          Text(exercise.description!, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
        ],
        if (exercise.notes != null) ...[
          _Heading('Notes'),
          Text(exercise.notes!,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: semantic.muted)),
          const SizedBox(height: 16),
        ],
        // Muscles by name, from our own taxonomy (T-005). The reference draws
        // anatomical figures; we do not reproduce its artwork, and a named
        // list is what its own legend falls back to anyway.
        if (taxonomy != null && !taxonomy.isEmpty) ...[
          if (taxonomy.primary.isNotEmpty)
            _MuscleRow(label: 'Primary', muscles: taxonomy.primary),
          if (taxonomy.secondary.isNotEmpty)
            _MuscleRow(label: 'Secondary', muscles: taxonomy.secondary),
        ],
        if (exercise.equipment != null) ...[
          const SizedBox(height: 8),
          _Heading('Equipment'),
          Text(equipmentLabel(exercise.equipment!),
              style: theme.textTheme.bodyMedium),
        ],
        if (exercise.description == null &&
            exercise.notes == null &&
            (taxonomy == null || taxonomy.isEmpty))
          Text(
            'Nothing recorded about this exercise yet.',
            style: theme.textTheme.bodyMedium?.copyWith(color: semantic.muted),
          ),
      ],
    );
  }
}

class _MuscleRow extends StatelessWidget {
  const _MuscleRow({required this.label, required this.muscles});

  final String label;
  final List<Muscle> muscles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTheme.columnHeader.copyWith(color: semantic.muted)),
          const SizedBox(height: 2),
          Text(muscles.map(muscleLabel).join(', '),
              style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _HistoryPane extends ConsumerWidget {
  const _HistoryPane({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final sessions = ref.watch(historyProvider).valueOrNull ?? const [];
    final entries = exerciseHistory(sessions, exerciseKey: exercise.id);

    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'You have never logged this exercise.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: semantic.muted),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final e = entries[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.sessionName, style: theme.textTheme.titleMedium),
              Text(
                relativeDay(e.when),
                style:
                    theme.textTheme.bodySmall?.copyWith(color: semantic.muted),
              ),
              const SizedBox(height: 6),
              for (final s in e.sets)
                Text(
                  _describeSet(s, e.weightUnit),
                  style: theme.textTheme.bodyMedium,
                ),
            ],
          ),
        );
      },
    );
  }

  static String _describeSet(SessionSet s, String unit) {
    if (s.durationSeconds != null) {
      return formatDurationSeconds(s.durationSeconds);
    }
    final w = s.weight;
    final r = s.reps;
    if (w == null && r == null) return '—';
    if (w == null) return '$r reps';
    if (r == null) return '${formatWeight(w)}$unit';
    return '${formatWeight(w)}$unit x $r';
  }
}

class _RecordsPane extends ConsumerWidget {
  const _RecordsPane({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final all = ref.watch(personalRecordsProvider);
    final records = all.where((r) => r.exerciseKey == exercise.id).firstOrNull;
    // Values from personalRecordsProvider are already in the settings unit,
    // so the label shown next to them must be that unit too (T-026).
    final unit = ref.watch(settingsProvider).weightUnit;

    if (records == null || records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No records yet — log a set to set your first.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: semantic.muted),
          ),
        ),
      );
    }

    // ADR-004's four metrics, in its order.
    final rows = <(String, PersonalRecord?, String Function(PersonalRecord))>[
      ('Heaviest weight', records.heaviestWeight,
          (r) => '${formatWeight(r.value)} $unit'),
      ('Best estimated 1RM', records.bestEstimatedOneRepMax,
          (r) => '${formatWeight(r.value)} $unit'),
      ('Best session volume', records.bestSessionVolume,
          (r) => '${r.value.round()} $unit'),
      ('Most reps', records.mostReps, (r) => '${r.value.round()}'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        for (final (label, record, format) in rows)
          if (record != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTheme.columnHeader
                          .copyWith(color: semantic.muted)),
                  const SizedBox(height: 2),
                  Text(format(record), style: theme.textTheme.headlineSmall),
                  Text(
                    // The achieving set, so the number is readable rather than
                    // just impressive (ADR-004).
                    '${formatWeight(record.weight)} $unit x ${record.reps} · '
                    '${relativeDay(record.achievedAt)}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: semantic.muted),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(text,
          style: AppTheme.columnHeader.copyWith(color: semantic.muted)),
    );
  }
}
