import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/dashboard/domain/weekly_summary.dart';
import 'package:gymflow/features/sessions/data/session_models.dart';

/// S-001's weekly summary: workouts, duration and volume for this week, each
/// with its change against last week (CMP-008 + CMP-013).
void main() {
  var seq = 0;
  // A Tuesday. The week runs Sunday–Saturday (CMP-020's model), so this
  // week starts Sunday the 23rd and last week starts Sunday the 16th.
  final now = DateTime(2026, 8, 25, 13, 0);

  ActiveSession session({
    required DateTime endedAt,
    int minutes = 60,
    double weight = 100,
    int reps = 5,
    bool completed = true,
  }) {
    final t = DateTime.utc(2026, 1, 1);
    final id = 'ses-${seq++}';
    return ActiveSession(
      session: WorkoutSession(
        id: id,
        name: 'Push',
        weightUnit: 'kg',
        status: SessionStatus.completed,
        autoFocusNextSet: true,
        autoFocusNextExercise: true,
        startedAt: endedAt.subtract(Duration(minutes: minutes)),
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
            exerciseId: 'ex-1',
            name: 'Bench',
            loggingType: LoggingType.strengthWeightRepsRir,
            sortOrder: 0,
            restSeconds: 90,
            targetSets: 1,
            createdAt: t,
            updatedAt: t,
          ),
          sets: [
            SessionSet(
              id: 'set-${seq++}',
              sessionExerciseId: 'se-x',
              setIndex: 0,
              weight: weight,
              reps: reps,
              completedAt: completed ? endedAt : null,
              createdAt: t,
              updatedAt: t,
            ),
          ],
        ),
      ],
    );
  }

  test('counts this week only', () {
    final s = weeklySummary([
      session(endedAt: DateTime(2026, 8, 24)), // Monday, this week
      session(endedAt: DateTime(2026, 8, 25)), // Tuesday, this week
      session(endedAt: DateTime(2026, 8, 21)), // Friday, last week
    ], now: now, displayUnit: 'kg');

    expect(s.workouts, 2);
  });

  test('the week starts on Sunday, so Sunday counts as this week', () {
    final s = weeklySummary([
      session(endedAt: DateTime(2026, 8, 23, 9)), // Sunday
    ], now: now, displayUnit: 'kg');

    expect(s.workouts, 1);
  });

  test('Saturday belongs to last week, not this one', () {
    final s = weeklySummary([
      session(endedAt: DateTime(2026, 8, 22, 23)), // Saturday
    ], now: now, displayUnit: 'kg');

    expect(s.workouts, 0);
    expect(s.workoutsDelta, -1, reason: 'it counted toward last week');
  });

  test('sums duration and volume across the week', () {
    final s = weeklySummary([
      session(endedAt: DateTime(2026, 8, 24), minutes: 30, weight: 100, reps: 5),
      session(endedAt: DateTime(2026, 8, 25), minutes: 45, weight: 60, reps: 10),
    ], now: now, displayUnit: 'kg');

    expect(s.duration, const Duration(minutes: 75));
    expect(s.volume, 500 + 600);
  });

  test('deltas compare against the previous week', () {
    final s = weeklySummary([
      // This week: one workout, 500kg.
      session(endedAt: DateTime(2026, 8, 24), minutes: 60, weight: 100, reps: 5),
      // Last week: two workouts, 200kg total.
      session(endedAt: DateTime(2026, 8, 18), minutes: 30, weight: 50, reps: 2),
      session(endedAt: DateTime(2026, 8, 19), minutes: 30, weight: 50, reps: 2),
    ], now: now, displayUnit: 'kg');

    expect(s.workoutsDelta, -1);
    expect(s.volumeDelta, 500 - 200);
    expect(s.durationDelta, const Duration(minutes: 0));
  });

  test('an incomplete set adds no volume', () {
    final s = weeklySummary([
      session(endedAt: DateTime(2026, 8, 24), completed: false),
    ], now: now, displayUnit: 'kg');

    expect(s.workouts, 1);
    expect(s.volume, 0);
  });

  test('no history is all zeroes, not nulls', () {
    final s = weeklySummary(const [], now: now, displayUnit: 'kg');

    expect(s.workouts, 0);
    expect(s.volume, 0);
    expect(s.duration, Duration.zero);
    expect(s.workoutsDelta, 0);
  });
}
