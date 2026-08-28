import '../../../core/utils/weight_units.dart';
import '../../../db/app_database.dart';

class SessionExerciseWithSets {
  const SessionExerciseWithSets({required this.exercise, required this.sets});

  final SessionExercise exercise;
  final List<SessionSet> sets;

  /// Vacuously true for a zero-set exercise, so this agrees with
  /// [firstPendingSet] (which is also null for an empty list) rather than
  /// leaving a zero-set exercise permanently "pending" with nothing to do.
  bool get isComplete => sets.every((s) => s.completedAt != null);

  int get completedSetCount => sets.where((s) => s.completedAt != null).length;

  SessionSet? get firstPendingSet {
    for (final s in sets) {
      if (s.completedAt == null) return s;
    }
    return null;
  }
}

class ActiveSession {
  const ActiveSession({required this.session, required this.exercises});

  final WorkoutSession session;
  final List<SessionExerciseWithSets> exercises;

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets.length);

  int get completedSets =>
      exercises.fold(0, (sum, e) => sum + e.completedSetCount);

  int get totalExercises => exercises.length;

  int get completedExercises => exercises.where((e) => e.isComplete).length;

  /// Sum of weight x reps over completed strength sets that have both values.
  double get completedVolume {
    var total = 0.0;
    for (final e in exercises) {
      if (e.exercise.loggingType != LoggingType.strengthWeightRepsRir) {
        continue;
      }
      for (final s in e.sets) {
        if (s.completedAt == null) continue;
        final w = s.weight;
        final r = s.reps;
        if (w != null && r != null) total += w * r;
      }
    }
    return total;
  }

  /// [completedVolume], restated in [displayUnit].
  ///
  /// The session knows the unit it was logged in, so the conversion belongs
  /// here rather than at each call site. `completedVolume` is kept for the
  /// single-session surfaces (the summary screen, a history row), which show
  /// a session in its own unit and have nothing to reconcile (T-026).
  double completedVolumeIn(String displayUnit) => convertWeight(
        completedVolume,
        from: session.weightUnit,
        to: displayUnit,
      );

  SessionExerciseWithSets? exerciseOf(String setId) {
    for (final e in exercises) {
      if (e.sets.any((s) => s.id == setId)) return e;
    }
    return null;
  }

  SessionExerciseWithSets? exerciseById(String id) {
    for (final e in exercises) {
      if (e.exercise.id == id) return e;
    }
    return null;
  }

  SessionSet? setById(String id) {
    for (final e in exercises) {
      for (final s in e.sets) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  Duration elapsed(DateTime now) =>
      (session.endedAt ?? now).difference(session.startedAt) -
      Duration(seconds: session.pausedSeconds);
}
