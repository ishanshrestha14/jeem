import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/data/session_models.dart';
import 'package:gymflow/features/sessions/domain/previous_best.dart';

/// S-006's `Previous`: what you actually did last time, so you can see whether
/// the plan is still right. The *best* set of the most recent session that
/// contained the exercise — not the same-numbered set, and not necessarily the
/// immediately preceding session, since you do not train everything every time.
void main() {
  var seq = 0;
  final now = DateTime.utc(2026, 8, 20);

  SessionSet set({
    required double? weight,
    required int? reps,
    bool complete = true,
  }) {
    return SessionSet(
      id: 'set-${seq++}',
      sessionExerciseId: 'se-1',
      setIndex: 0,
      weight: weight,
      reps: reps,
      completedAt: complete ? now : null,
      createdAt: now,
      updatedAt: now,
    );
  }

  SessionExerciseWithSets entry({
    required String name,
    String? exerciseId = 'ex-1',
    LoggingType loggingType = LoggingType.strengthWeightRepsRir,
    required List<SessionSet> sets,
  }) {
    return SessionExerciseWithSets(
      exercise: SessionExercise(
        id: 'se-${seq++}',
        sessionId: 'session-1',
        exerciseId: exerciseId,
        name: name,
        loggingType: loggingType,
        sortOrder: 0,
        restSeconds: 90,
        targetSets: sets.length,
        createdAt: now,
        updatedAt: now,
      ),
      sets: sets,
    );
  }

  ActiveSession session({
    required DateTime endedAt,
    required List<SessionExerciseWithSets> exercises,
  }) {
    return ActiveSession(
      session: WorkoutSession(
        id: 'session-${seq++}',
        name: 'Session',
        weightUnit: 'kg',
        status: SessionStatus.completed,
        autoFocusNextSet: true,
        autoFocusNextExercise: true,
        startedAt: endedAt,
        endedAt: endedAt,
        pausedSeconds: 0,
        restStatus: RestTimerStatus.idle,
        createdAt: now,
        updatedAt: now,
      ),
      exercises: exercises,
    );
  }

  test('the best set is the one with the highest estimated 1RM', () {
    // 70x5 estimates 81.7; 60x8 estimates 76.0 — the heavier set wins here,
    // and `reps` proves it is the achieving set rather than a reconstruction.
    final best = previousBestByExercise([
      session(endedAt: DateTime.utc(2026, 8, 10), exercises: [
        entry(name: 'Bench', sets: [set(weight: 60, reps: 8), set(weight: 70, reps: 5)]),
      ]),
    ]);

    expect(best['ex-1']!.weight, 70);
    expect(best['ex-1']!.reps, 5);
  });

  test('a lighter set can win on estimated 1RM', () {
    // 60x10 estimates 80.0, above 70x2's 74.7 — so this is not "heaviest".
    final best = previousBestByExercise([
      session(endedAt: DateTime.utc(2026, 8, 10), exercises: [
        entry(name: 'Bench', sets: [set(weight: 70, reps: 2), set(weight: 60, reps: 10)]),
      ]),
    ]);

    expect(best['ex-1']!.weight, 60);
    expect(best['ex-1']!.reps, 10);
  });

  test('reads the most recent session that contained the exercise', () {
    final best = previousBestByExercise([
      // Newest first, as `historyProvider` delivers them. The newest session
      // never touched Bench, so it must not blank Bench's previous.
      session(endedAt: DateTime.utc(2026, 8, 18), exercises: [
        entry(name: 'Squat', exerciseId: 'ex-2', sets: [set(weight: 100, reps: 5)]),
      ]),
      session(endedAt: DateTime.utc(2026, 8, 10), exercises: [
        entry(name: 'Bench', sets: [set(weight: 80, reps: 5)]),
      ]),
      session(endedAt: DateTime.utc(2026, 8, 3), exercises: [
        entry(name: 'Bench', sets: [set(weight: 200, reps: 5)]),
      ]),
    ]);

    expect(best['ex-1']!.weight, 80,
        reason: 'the 10th, not the older 3rd — recency beats the bigger lift');
    expect(best['ex-2']!.weight, 100);
  });

  test('a session with no completed set for the exercise is looked past', () {
    final best = previousBestByExercise([
      session(endedAt: DateTime.utc(2026, 8, 18), exercises: [
        entry(name: 'Bench', sets: [set(weight: 90, reps: 5, complete: false)]),
      ]),
      session(endedAt: DateTime.utc(2026, 8, 10), exercises: [
        entry(name: 'Bench', sets: [set(weight: 80, reps: 5)]),
      ]),
    ]);

    expect(best['ex-1']!.weight, 80);
  });

  test('sets missing a weight or reps are ignored', () {
    final best = previousBestByExercise([
      session(endedAt: DateTime.utc(2026, 8, 10), exercises: [
        entry(name: 'Bench', sets: [
          set(weight: null, reps: 5),
          set(weight: 90, reps: null),
          set(weight: 50, reps: 5),
        ]),
      ]),
    ]);

    expect(best['ex-1']!.weight, 50);
  });

  test('duration-logged exercises have no previous best', () {
    final best = previousBestByExercise([
      session(endedAt: DateTime.utc(2026, 8, 10), exercises: [
        entry(
          name: 'Plank',
          loggingType: LoggingType.durationOnly,
          sets: [set(weight: null, reps: null)],
        ),
      ]),
    ]);

    expect(best, isEmpty);
  });

  test('an exercise with no id is keyed by name', () {
    final best = previousBestByExercise([
      session(endedAt: DateTime.utc(2026, 8, 10), exercises: [
        entry(name: 'Ad-hoc Curl', exerciseId: null, sets: [set(weight: 20, reps: 12)]),
      ]),
    ]);

    expect(best['Ad-hoc Curl']!.weight, 20);
  });

  test('no history yields no entries', () {
    expect(previousBestByExercise([]), isEmpty);
  });

  test('the achieving set carries the date it was done', () {
    final best = previousBestByExercise([
      session(endedAt: DateTime.utc(2026, 8, 10), exercises: [
        entry(name: 'Bench', sets: [set(weight: 80, reps: 5)]),
      ]),
    ]);

    expect(best['ex-1']!.when, DateTime.utc(2026, 8, 10));
  });
}
