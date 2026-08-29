import '../../../core/utils/weight_units.dart';
import '../../records/data/personal_records.dart';
import 'exercise_history.dart';

/// One session's showing on the progress chart (T-027, S-025's fourth pane).
class ProgressPoint {
  const ProgressPoint({required this.when, required this.value});

  final DateTime when;

  /// Best estimated 1RM logged that session, in the display unit.
  final double value;
}

/// One point per session: the best estimated 1RM across the sets logged that
/// day, oldest first.
///
/// The session's *best* set represents it, not an average — the same
/// convention `Previous` (T-009) and Records (ADR-004) already use, so
/// "better lift" means one thing across the app.
///
/// Sets with no weight, no reps, or a zero weight contribute nothing: a
/// zero-weight set is bodyweight work, and an e1RM of zero is not a lift —
/// plotted, one would drag the whole y-domain to zero and flatten every real
/// point above it. A session where nothing qualifies yields no point rather
/// than a point at zero.
///
/// Reps are capped at 12 by [estimatedOneRepMax] (ADR-004). The documented
/// consequence: progress made purely by adding reps beyond 12 does not move
/// the line.
List<ProgressPoint> exerciseProgress(
  List<ExerciseHistoryEntry> history, {
  required String displayUnit,
}) {
  final points = <ProgressPoint>[];

  for (final entry in history) {
    var best = 0.0;
    for (final set in entry.sets) {
      final logged = set.weight;
      final reps = set.reps;
      if (logged == null || reps == null || reps <= 0) continue;
      final weight = convertWeight(
        logged,
        from: entry.weightUnit,
        to: displayUnit,
      );
      if (weight <= 0) continue;
      final score = estimatedOneRepMax(weight, reps);
      if (score > best) best = score;
    }
    if (best > 0) points.add(ProgressPoint(when: entry.when, value: best));
  }

  // Two entries can share a date: `exerciseHistory` emits one per
  // occurrence, and nothing stops an exercise the routine already contains
  // being added again mid-session. One point per session, so the later
  // entry's best value wins over the earlier one's — the same "session's
  // best set represents it" rule applied across entries, not just sets.
  final byDate = <DateTime, ProgressPoint>{};
  for (final point in points) {
    final existing = byDate[point.when];
    if (existing == null || point.value > existing.value) {
      byDate[point.when] = point;
    }
  }

  // `exerciseHistory` is newest first; the chart reads left to right.
  final merged = byDate.values.toList()
    ..sort((a, b) => a.when.compareTo(b.when));
  return merged;
}
