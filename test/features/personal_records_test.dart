import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/records/data/personal_records.dart';
import 'package:gymflow/features/sessions/data/session_models.dart';

/// ADR-004: lifetime records per exercise on weight, estimated 1RM, volume and
/// reps. Duration work sets none.
void main() {
  var seq = 0;

  SessionSet set({
    required double? weight,
    required int? reps,
    bool complete = true,
  }) {
    final now = DateTime.utc(2026, 8, 20);
    return SessionSet(
      id: 'set-${seq++}',
      sessionExerciseId: 'se-1',
      setIndex: 0,
      weight: weight,
      reps: reps,
      rir: null,
      durationSeconds: null,
      completedAt: complete ? now : null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  ActiveSession session({
    required DateTime endedAt,
    required String exerciseName,
    required List<SessionSet> sets,
    String? exerciseId = 'ex-1',
    LoggingType loggingType = LoggingType.strengthWeightRepsRir,
  }) {
    final now = DateTime.utc(2026, 8, 20);
    return ActiveSession(
      session: WorkoutSession(
        id: 'session-${seq++}',
        templateId: null,
        name: 'Session',
        weightUnit: 'kg',
        status: SessionStatus.completed,
        autoFocusNextSet: true,
        autoFocusNextExercise: true,
        startedAt: endedAt,
        endedAt: endedAt,
        pausedSeconds: 0,
        pausedAt: null,
        notes: null,
        restStatus: RestTimerStatus.idle,
        restEndsAt: null,
        restRemainingSeconds: null,
        restTotalSeconds: null,
        restAfterSetId: null,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      ),
      exercises: [
        SessionExerciseWithSets(
          exercise: SessionExercise(
            id: 'se-1',
            sessionId: 'session-1',
            exerciseId: exerciseId,
            name: exerciseName,
            description: null,
            notes: null,
            imagePath: null,
            loggingType: loggingType,
            sortOrder: 0,
            restSeconds: 90,
            targetSets: sets.length,
            sessionNotes: null,
            createdAt: now,
            updatedAt: now,
            deletedAt: null,
          ),
          sets: sets,
        ),
      ],
    );
  }

  test('heaviest weight leads the row, carrying its achieving set', () {
    final records = computePersonalRecords([
      session(
        endedAt: DateTime.utc(2026, 8, 10),
        exerciseName: 'Barbell Row',
        sets: [set(weight: 60, reps: 8), set(weight: 70, reps: 6)],
      ),
    ]);

    final best = records.single.headline!;
    expect(best.weight, 70);
    expect(best.reps, 6, reason: 'the set that produced it, not another');
  });

  test('an incomplete set sets no record', () {
    final records = computePersonalRecords([
      session(
        endedAt: DateTime.utc(2026, 8, 10),
        exerciseName: 'Barbell Row',
        sets: [
          set(weight: 60, reps: 8),
          set(weight: 100, reps: 1, complete: false),
        ],
      ),
    ]);
    expect(records.single.headline!.weight, 60);
  });

  test('duration-only exercises never appear', () {
    final records = computePersonalRecords([
      session(
        endedAt: DateTime.utc(2026, 8, 10),
        exerciseName: 'Plank',
        loggingType: LoggingType.durationOnly,
        sets: [set(weight: null, reps: null)],
      ),
    ]);
    expect(records, isEmpty);
  });

  test('estimated 1RM is capped at 12 reps', () {
    // Uncapped, a 20-rep set would out-rank a genuinely heavy single. Epley
    // at 12 reps: 50 * (1 + 12/30) = 70.
    expect(estimatedOneRepMax(50, 12), closeTo(70, 0.001));
    expect(estimatedOneRepMax(50, 20), closeTo(70, 0.001),
        reason: 'past 12 reps the estimate stops climbing');
    expect(estimatedOneRepMax(50, 0), 0);
  });

  test('volume is per session, and reps records the best single set', () {
    final records = computePersonalRecords([
      session(
        endedAt: DateTime.utc(2026, 8, 10),
        exerciseName: 'Barbell Row',
        sets: [set(weight: 50, reps: 10), set(weight: 50, reps: 10)],
      ),
      session(
        endedAt: DateTime.utc(2026, 8, 17),
        exerciseName: 'Barbell Row',
        sets: [set(weight: 60, reps: 12)],
      ),
    ]);

    final r = records.single;
    // 50x10 + 50x10 = 1000 beats 60x12 = 720.
    expect(r.bestSessionVolume!.value, 1000);
    expect(r.mostReps!.value, 12);
    expect(r.heaviestWeight!.weight, 60);
  });

  test('the earliest session to reach a value keeps the record', () {
    final records = computePersonalRecords([
      session(
        endedAt: DateTime.utc(2026, 8, 10),
        exerciseName: 'Barbell Row',
        sets: [set(weight: 70, reps: 6)],
      ),
      session(
        endedAt: DateTime.utc(2026, 8, 17),
        exerciseName: 'Barbell Row',
        sets: [set(weight: 70, reps: 6)],
      ),
    ]);
    expect(records.single.headline!.achievedAt, DateTime.utc(2026, 8, 10),
        reason: 'matching a best again is not a new personal best');
  });

  test('exercises are kept apart, heaviest first', () {
    final records = computePersonalRecords([
      session(
        endedAt: DateTime.utc(2026, 8, 10),
        exerciseName: 'Curl',
        exerciseId: 'ex-curl',
        sets: [set(weight: 20, reps: 10)],
      ),
      session(
        endedAt: DateTime.utc(2026, 8, 11),
        exerciseName: 'Squat',
        exerciseId: 'ex-squat',
        sets: [set(weight: 100, reps: 5)],
      ),
    ]);
    expect([for (final r in records) r.exerciseName], ['Squat', 'Curl']);
  });
}
