import '../../../db/tables.dart';
import '../../records/data/personal_records.dart';
import '../data/session_models.dart';

/// The best set of the last session that contained a given exercise — S-006's
/// `Previous`. Distinct from the muted pre-fill in a pending row: that is the
/// routine's *plan*, this is what was actually done last time, and reading the
/// two side by side is what tells you whether the plan is still right.
class PreviousBest {
  const PreviousBest({
    required this.weight,
    required this.reps,
    required this.when,
  });

  final double weight;
  final int reps;

  /// When that session ended — kept so a caller can say how long ago it was
  /// without going back to the session list.
  final DateTime when;
}

/// Maps `exerciseId ?? name` to the best set of the most recent session that
/// contained it.
///
/// [completed] must be **newest first**, which is what
/// `SessionRepository.watchCompletedSessions` (and so `historyProvider`)
/// already delivers.
///
/// "Most recent session that contained it" is not the same as "the previous
/// session": on a split you might not have benched for a week, and blanking
/// `Previous` because yesterday was leg day would hide exactly the number the
/// column exists to show. So the first session carrying a usable set for an
/// exercise wins, and older ones are never consulted for it again.
///
/// "Best" is the highest estimated 1RM ([estimatedOneRepMax], Epley capped at
/// 12 reps per ADR-004) — the app's own established notion of a better lift,
/// and the one that ranks 70x5 above 60x8 without letting 100x1 outrank 95x8.
/// Ties fall to the heavier set, since the same estimate off fewer reps is the
/// stronger showing.
///
/// Keyed the same way as [computePersonalRecords]: by `exerciseId` where the
/// session snapshot kept one, else by name, so an ad-hoc or since-deleted
/// exercise still matches itself.
Map<String, PreviousBest> previousBestByExercise(
  List<ActiveSession> completed,
) {
  final out = <String, PreviousBest>{};

  for (final session in completed) {
    final when = session.session.endedAt ?? session.session.startedAt;
    for (final entry in session.exercises) {
      if (entry.exercise.loggingType == LoggingType.durationOnly) continue;

      final key = entry.exercise.exerciseId ?? entry.exercise.name;
      // Already answered by a more recent session.
      if (out.containsKey(key)) continue;

      PreviousBest? best;
      var bestScore = 0.0;
      for (final set in entry.sets) {
        if (set.completedAt == null) continue;
        final weight = set.weight;
        final reps = set.reps;
        if (weight == null || reps == null || reps <= 0) continue;

        final score = estimatedOneRepMax(weight, reps);
        if (best == null || score > bestScore ||
            (score == bestScore && weight > best.weight)) {
          best = PreviousBest(weight: weight, reps: reps, when: when);
          bestScore = score;
        }
      }

      // A session where the exercise was skipped or left unlogged answers
      // nothing, so the next-older one still gets its turn.
      if (best != null) out[key] = best;
    }
  }

  return out;
}
