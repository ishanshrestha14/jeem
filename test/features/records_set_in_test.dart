import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/records/data/personal_records.dart';
import 'package:gymflow/features/sessions/data/session_models.dart';

/// S-001's `Records 🏅 N` on a workout card. Owner-confirmed 2026-08-27: a
/// record counts against **all** history — the badge means "this session holds
/// a record that still stands", not "this was a best at the time".
void main() {
  var seq = 0;
  final t = DateTime.utc(2026, 1, 1);

  SessionSet set({required double weight, required int reps}) => SessionSet(
        id: 'set-${seq++}',
        sessionExerciseId: 'se-x',
        setIndex: 0,
        weight: weight,
        reps: reps,
        completedAt: t,
        createdAt: t,
        updatedAt: t,
      );

  ActiveSession session({
    required DateTime endedAt,
    required String exerciseId,
    required List<SessionSet> sets,
  }) {
    final id = 'ses-${seq++}';
    return ActiveSession(
      session: WorkoutSession(
        id: id,
        name: 'Push',
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
            name: exerciseId,
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

  test('a session holding the standing record counts it', () {
    final older = session(
        endedAt: DateTime(2026, 8, 10),
        exerciseId: 'bench',
        sets: [set(weight: 80, reps: 5)]);
    final best = session(
        endedAt: DateTime(2026, 8, 20),
        exerciseId: 'bench',
        sets: [set(weight: 120, reps: 5)]);
    final records = computePersonalRecords([best, older], displayUnit: 'kg');

    expect(recordsSetIn(best, records), 1);
    expect(recordsSetIn(older, records), 0,
        reason: 'its record was beaten, so it no longer stands');
  });

  test('one exercise counts once however many metrics it took', () {
    // A single heavy set usually sets heaviest weight AND estimated 1RM at the
    // same time. Counting metrics would read "Records 2" for one lift, which
    // overstates what happened.
    final only = session(
        endedAt: DateTime(2026, 8, 20),
        exerciseId: 'bench',
        sets: [set(weight: 120, reps: 5)]);
    final records = computePersonalRecords([only], displayUnit: 'kg');

    expect(recordsSetIn(only, records), 1);
  });

  test('records on two exercises count twice', () {
    final s = ActiveSession(
      session: session(
              endedAt: DateTime(2026, 8, 20), exerciseId: 'a', sets: [])
          .session,
      exercises: [
        session(
                endedAt: DateTime(2026, 8, 20),
                exerciseId: 'bench',
                sets: [set(weight: 120, reps: 5)])
            .exercises
            .single,
        session(
                endedAt: DateTime(2026, 8, 20),
                exerciseId: 'squat',
                sets: [set(weight: 150, reps: 5)])
            .exercises
            .single,
      ],
    );
    final records = computePersonalRecords([s], displayUnit: 'kg');

    expect(recordsSetIn(s, records), 2);
  });

  test('a session that set nothing counts nothing', () {
    final best = session(
        endedAt: DateTime(2026, 8, 20),
        exerciseId: 'bench',
        sets: [set(weight: 120, reps: 8)]);
    final weaker = session(
        endedAt: DateTime(2026, 8, 21),
        exerciseId: 'bench',
        sets: [set(weight: 60, reps: 3)]);
    final records = computePersonalRecords([weaker, best], displayUnit: 'kg');

    expect(recordsSetIn(weaker, records), 0);
  });

  test('a lighter session that ties on reps does still count', () {
    // Surprising but correct, and worth pinning. `mostReps` ignores weight
    // (ADR-004), so a light session matching your best rep count holds that
    // record on the tie and earns a badge. The alternative — silently
    // demoting ties — would make the badge disagree with the You tab, which
    // shows the same record.
    final heavy = session(
        endedAt: DateTime(2026, 8, 20),
        exerciseId: 'bench',
        sets: [set(weight: 120, reps: 5)]);
    final light = session(
        endedAt: DateTime(2026, 8, 21),
        exerciseId: 'bench',
        sets: [set(weight: 60, reps: 5)]);
    final records = computePersonalRecords([light, heavy], displayUnit: 'kg');

    expect(recordsSetIn(light, records), 1);
  });

  test('no records at all counts nothing', () {
    final s = session(
        endedAt: DateTime(2026, 8, 20), exerciseId: 'bench', sets: []);

    expect(recordsSetIn(s, const []), 0);
  });
}
