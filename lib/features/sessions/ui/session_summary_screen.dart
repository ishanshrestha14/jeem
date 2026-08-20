import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../db/app_database.dart';
import '../providers/active_session_controller.dart';

/// Where a session actually gets committed: the numbers, a notes field, and
/// (when live) Save/Discard. Reused verbatim as the read-only history detail
/// screen (Task 20) via [readOnly] — a completed session has nothing left to
/// commit, so the bottom bar simply disappears and the notes field locks.
///
/// Until Save is tapped the underlying session stays `active` — backing out
/// of this screen (the app bar back button, or the OS back gesture) returns
/// to a live workout rather than losing it. `readOnly` sessions never call
/// [activeSessionControllerProvider] at all, since a completed/cancelled row
/// viewed from history is never the one active session that controller talks
/// to.
class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({
    super.key,
    required this.sessionId,
    this.readOnly = false,
  });

  final String sessionId;
  final bool readOnly;

  @override
  ConsumerState<SessionSummaryScreen> createState() =>
      _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  final _notesController = TextEditingController();
  bool _notesHydrated = false;
  bool _busy = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionByIdProvider(widget.sessionId));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (session) {
        if (session == null) {
          return const Scaffold(body: Center(child: Text('Session not found')));
        }
        if (!_notesHydrated) {
          _notesHydrated = true;
          _notesController.text = session.session.notes ?? '';
        }
        return _buildScaffold(context, session);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, ActiveSession session) {
    final theme = Theme.of(context);
    final muted = theme.extension<SemanticColors>()!.muted;
    final workout = session.session;
    final weightUnit = workout.weightUnit;
    final volume = session.completedVolume;

    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(workout.name, style: AppTheme.exerciseName.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMEd().add_jm().format(workout.startedAt),
              style: AppTheme.body.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            _StatGrid(session: session, weightUnit: weightUnit, volume: volume),
            const SizedBox(height: 24),
            for (final exercise in session.exercises)
              _ExerciseSummary(exercise: exercise, weightUnit: weightUnit),
            const SizedBox(height: 16),
            Text('Notes', style: AppTheme.columnHeader.copyWith(color: muted)),
            const SizedBox(height: 4),
            TextField(
              controller: _notesController,
              enabled: !widget.readOnly && !_busy,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'How did it go?',
                filled: true,
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(),
                disabledBorder: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: widget.readOnly ? null : _buildActions(context),
    );
  }

  Widget _buildActions(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : () => _handleDiscard(context),
              child: const Text('Discard'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : () => _handleSave(context),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave(BuildContext context) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final notes = _notesController.text.trim();
    await ref.read(activeSessionControllerProvider.notifier).finish(
          notes: notes.isEmpty ? null : notes,
        );
    if (!context.mounted) return;
    router.go('/home');
    messenger.showSnackBar(const SnackBar(content: Text('Workout saved')));
  }

  Future<void> _handleDiscard(BuildContext context) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Discard session?',
      message: 'This discards the session. This cannot be undone.',
      confirmLabel: 'Discard',
    );
    if (!confirmed || !context.mounted) return;

    setState(() => _busy = true);
    final router = GoRouter.of(context);
    await ref.read(activeSessionControllerProvider.notifier).cancelSession();
    if (!context.mounted) return;
    router.go('/home');
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.session,
    required this.weightUnit,
    required this.volume,
  });

  final ActiveSession session;
  final String weightUnit;
  final double volume;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final stats = <String>[
      mmss(session.elapsed(now)),
      '${session.completedSets} / ${session.totalSets} sets',
      '${session.completedExercises} / ${session.totalExercises} exercises',
      if (volume > 0) '${volume.round()} $weightUnit',
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [for (final s in stats) _StatTile(value: s)],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: semantic.line),
      ),
      child: Text(
        value,
        style: AppTheme.elapsedTime.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ExerciseSummary extends StatelessWidget {
  const _ExerciseSummary({required this.exercise, required this.weightUnit});

  final SessionExerciseWithSets exercise;
  final String weightUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.extension<SemanticColors>()!.muted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.exercise.name, style: AppTheme.exerciseName),
          const SizedBox(height: 4),
          for (final set in exercise.sets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                _setLine(exercise.exercise, set),
                style: set.completedAt == null
                    ? AppTheme.body.copyWith(color: muted)
                    : AppTheme.body,
              ),
            ),
        ],
      ),
    );
  }

  String _setLine(SessionExercise exercise, SessionSet set) {
    if (set.completedAt == null) return 'Set ${set.setIndex + 1} · —';
    if (exercise.loggingType == LoggingType.durationOnly) {
      return 'Set ${set.setIndex + 1} · ${formatDurationSeconds(set.durationSeconds)}';
    }
    final weight = formatWeight(set.weight);
    final reps = set.reps?.toString() ?? '—';
    return 'Set ${set.setIndex + 1} · $weight $weightUnit × $reps · '
        'RIR ${formatRir(set.rir)}';
  }
}
