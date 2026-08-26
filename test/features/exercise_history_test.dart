import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/domain/exercise_history.dart';
import 'package:gymflow/features/sessions/data/session_models.dart';

/// S-025's History pane: every session that contained this exercise, newest
/// first, with the sets actually logged in it.
void main() {
  var seq = 0;
  final t = DateTime.utc(2026, 1, 1);

  SessionSet set({double? weight, int? reps, bool complete = true}) => SessionSet(
        id: 'set-${seq++}',
        sessionExerciseId: 'se-x',
        setIndex: 0,
        weight: weight,
        reps: reps,
        completedAt: complete ? t : null,
        createdAt: t,
        updatedAt: t,
      );

  ActiveSession session({
    required DateTime endedAt,
    required String exerciseName,
    String? exerciseId = 'ex-1',
    required List<SessionSet> sets,
    String name = 'Push',
  }) {
    final id = 'ses-${seq++}';
    return ActiveSession(
      session: WorkoutSession(
        id: id,
        name: name,
        weightUnit: 'kg',
        status: SessionStatus.completed,
        autoFocusNextSet: true,
        autoFocusNextExercise: true,
        startedAt: endedAt,
        endedAt: endedAt,
        pausedSeconds: 0,
        restStatus: RestTimerStatus.idle,
        createdAt: t,
        updatedAt: t,
      ),
      exercises: [
        SessionExerciseWithSets(
          exercise: SessionExercise(
            id: 'se-${seq++}',
            sessionId: id,
            exerciseId: exerciseId,
            name: exerciseName,
            loggingType: LoggingType.strengthWeightRepsRir,
            sortOrder: 0,
            restSeconds: 90,
            targetSets: sets.length,
            createdAt: t,
            updatedAt: t,
          ),
          sets: sets,
        ),
      ],
    );
  }

  test('returns only sessions containing the exercise', () {
    final out = exerciseHistory(
      [
        session(
            endedAt: DateTime(2026, 8, 20),
            exerciseName: 'Bench',
            sets: [set(weight: 60, reps: 8)]),
        session(
            endedAt: DateTime(2026, 8, 18),
            exerciseName: 'Squat',
            exerciseId: 'ex-2',
            sets: [set(weight: 100, reps: 5)]),
      ],
      exerciseKey: 'ex-1',
    );

    expect(out, hasLength(1));
    expect(out.single.sets, hasLength(1));
  });

  test('carries the session name and date', () {
    final out = exerciseHistory(
      [
        session(
            endedAt: DateTime(2026, 8, 20),
            exerciseName: 'Bench',
            name: 'Push A',
            sets: [set(weight: 60, reps: 8)]),
      ],
      exerciseKey: 'ex-1',
    );

    expect(out.single.sessionName, 'Push A');
    expect(out.single.when, DateTime(2026, 8, 20));
  });

  test('only completed sets are listed', () {
    final out = exerciseHistory(
      [
        session(endedAt: DateTime(2026, 8, 20), exerciseName: 'Bench', sets: [
          set(weight: 60, reps: 8),
          set(weight: 70, reps: 5, complete: false),
        ]),
      ],
      exerciseKey: 'ex-1',
    );

    // An unlogged set is not something you did.
    expect(out.single.sets, hasLength(1));
    expect(out.single.sets.single.weight, 60);
  });

  test('a session where the exercise was skipped entirely is omitted', () {
    final out = exerciseHistory(
      [
        session(
            endedAt: DateTime(2026, 8, 20),
            exerciseName: 'Bench',
            sets: [set(weight: 60, reps: 8, complete: false)]),
      ],
      exerciseKey: 'ex-1',
    );

    expect(out, isEmpty);
  });

  test('an exercise with no id matches by name', () {
    final out = exerciseHistory(
      [
        session(
            endedAt: DateTime(2026, 8, 20),
            exerciseName: 'Ad-hoc Curl',
            exerciseId: null,
            sets: [set(weight: 20, reps: 12)]),
      ],
      exerciseKey: 'Ad-hoc Curl',
    );

    expect(out, hasLength(1));
  });

  test('no history yields nothing', () {
    expect(exerciseHistory(const [], exerciseKey: 'ex-1'), isEmpty);
  });
}
