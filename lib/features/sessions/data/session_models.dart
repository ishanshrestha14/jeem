import '../../../db/app_database.dart';

class SessionExerciseWithSets {
  const SessionExerciseWithSets({required this.exercise, required this.sets});

  final SessionExercise exercise;
  final List<SessionSet> sets;

  bool get isComplete =>
      sets.isNotEmpty && sets.every((s) => s.completedAt != null);

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
