import 'dart:math' as math;

import '../../../db/app_database.dart';
import '../../sessions/data/session_models.dart';

/// One personal record: the value, the set that produced it, and when.
///
/// Storing the achieving set alongside the number is what makes a record
/// readable — "70 kg" alone says less than "70 kg, 70kg x 8 reps" — and it
/// costs nothing, since the set had to be found to compute the value.
class PersonalRecord {
  const PersonalRecord({
    required this.value,
    required this.weight,
    required this.reps,
    required this.achievedAt,
  });

  final double value;
  final double weight;
  final int reps;
  final DateTime achievedAt;
}

/// The four metrics ADR-004 fixes, for one exercise, over all history.
class ExerciseRecords {
  const ExerciseRecords({
    required this.exerciseKey,
    required this.exerciseName,
    this.heaviestWeight,
    this.bestEstimatedOneRepMax,
    this.bestSessionVolume,
    this.mostReps,
  });

  /// `exerciseId` where the session snapshot kept one, else the name — a
  /// session records the exercise it was built from, but an ad-hoc or deleted
  /// exercise may only leave a name behind.
  final String exerciseKey;
  final String exerciseName;

  final PersonalRecord? heaviestWeight;
  final PersonalRecord? bestEstimatedOneRepMax;
  final PersonalRecord? bestSessionVolume;
  final PersonalRecord? mostReps;

  /// The headline shown in the You tab: one row per exercise, led by the
  /// heaviest lift (S-005).
  PersonalRecord? get headline => heaviestWeight;

  bool get isEmpty =>
      heaviestWeight == null &&
      bestEstimatedOneRepMax == null &&
      bestSessionVolume == null &&
      mostReps == null;
}

/// Epley, capped at 12 reps: `w * (1 + reps/30)`.
///
/// The cap is the important part — every 1RM formula degrades past about a
/// dozen reps, and an uncapped estimate would let a light, high-rep set
/// out-rank a genuinely heavy single. Only ever compared against our own
/// history, so it needs to be self-consistent, not to match anyone else's
/// number ([ADR-004](../../../../docs/decisions/ADR-004-pr-metrics.md)).
double estimatedOneRepMax(double weight, int reps) {
  if (reps <= 0) return 0;
  final capped = math.min(reps, 12);
  return weight * (1 + capped / 30);
}

/// Computes lifetime records per exercise from completed sessions.
///
/// Duration-logged exercises are skipped entirely: they have no weight, reps
/// or volume in this sense, so a record would be meaningless (ADR-004).
List<ExerciseRecords> computePersonalRecords(List<ActiveSession> sessions) {
  final byExercise = <String, _Accumulator>{};

  for (final session in sessions) {
    final when = session.session.endedAt ?? session.session.startedAt;
    for (final exercise in session.exercises) {
      if (exercise.exercise.loggingType == LoggingType.durationOnly) continue;

      final key = exercise.exercise.exerciseId ?? exercise.exercise.name;
      final acc = byExercise.putIfAbsent(
        key,
        () => _Accumulator(key: key, name: exercise.exercise.name),
      );

      var sessionVolume = 0.0;
      PersonalRecord? volumeSet;

      for (final set in exercise.sets) {
        if (set.completedAt == null) continue;
        final weight = set.weight;
        final reps = set.reps;
        if (weight == null || reps == null || reps <= 0) continue;

        final record = PersonalRecord(
          value: weight,
          weight: weight,
          reps: reps,
          achievedAt: when,
        );

        acc.considerWeight(record);
        acc.considerOneRepMax(record.copyWithValue(
          estimatedOneRepMax(weight, reps),
        ));
        acc.considerReps(record.copyWithValue(reps.toDouble()));

        sessionVolume += weight * reps;
        // The session's volume is attributed to its heaviest set, so the
        // "achieving set" shown next to a volume record is a real set from
        // that session rather than an invented average.
        if (volumeSet == null || weight > volumeSet.weight) volumeSet = record;
      }

      if (sessionVolume > 0 && volumeSet != null) {
        acc.considerVolume(volumeSet.copyWithValue(sessionVolume));
      }
    }
  }

  final out = [for (final acc in byExercise.values) acc.build()]
    ..removeWhere((r) => r.isEmpty);
  // Heaviest first, so the list opens on the lifts worth being proud of.
  out.sort((a, b) => (b.headline?.value ?? 0).compareTo(a.headline?.value ?? 0));
  return out;
}

extension on PersonalRecord {
  PersonalRecord copyWithValue(double newValue) => PersonalRecord(
        value: newValue,
        weight: weight,
        reps: reps,
        achievedAt: achievedAt,
      );
}

class _Accumulator {
  _Accumulator({required this.key, required this.name});

  final String key;
  final String name;

  PersonalRecord? weight;
  PersonalRecord? oneRepMax;
  PersonalRecord? volume;
  PersonalRecord? reps;

  /// Strictly greater, so the *earliest* session to reach a value keeps the
  /// record — matching it again later is not a new personal best.
  void considerWeight(PersonalRecord r) {
    if (weight == null || r.value > weight!.value) weight = r;
  }

  void considerOneRepMax(PersonalRecord r) {
    if (oneRepMax == null || r.value > oneRepMax!.value) oneRepMax = r;
  }

  void considerVolume(PersonalRecord r) {
    if (volume == null || r.value > volume!.value) volume = r;
  }

  void considerReps(PersonalRecord r) {
    if (reps == null || r.value > reps!.value) reps = r;
  }

  ExerciseRecords build() => ExerciseRecords(
        exerciseKey: key,
        exerciseName: name,
        heaviestWeight: weight,
        bestEstimatedOneRepMax: oneRepMax,
        bestSessionVolume: volume,
        mostReps: reps,
      );
}
