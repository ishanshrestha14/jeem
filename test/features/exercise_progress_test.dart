import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/domain/exercise_history.dart';
import 'package:gymflow/features/exercises/domain/exercise_progress.dart';

/// T-027 — one point per session: the best estimated 1RM logged that day.
void main() {
  var seq = 0;
  final base = DateTime.utc(2026, 6, 1);

  SessionSet set({double? weight, int? reps}) {
    final now = DateTime.utc(2026, 6, 1);
    return SessionSet(
      id: 'set-${seq++}',
      sessionExerciseId: 'se-1',
      setIndex: 0,
      weight: weight,
      reps: reps,
      rir: null,
      durationSeconds: null,
      completedAt: now,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  ExerciseHistoryEntry entry({
    required int dayOffset,
    required List<SessionSet> sets,
    String unit = 'kg',
  }) =>
      ExerciseHistoryEntry(
        when: base.add(Duration(days: dayOffset)),
        sessionName: 'Session',
        weightUnit: unit,
        sets: sets,
      );

  test('takes the best estimated 1RM of each session', () {
    // 70x5 estimates higher than 60x8 under Epley capped at 12.
    final points = exerciseProgress([
      entry(dayOffset: 0, sets: [set(weight: 60, reps: 8), set(weight: 70, reps: 5)]),
    ], displayUnit: 'kg');

    expect(points, hasLength(1));
    expect(points.single.value, closeTo(70 * (1 + 5 / 30), 1e-9));
  });

  test('returns points oldest first, whatever order history arrives in', () {
    // `exerciseHistory` is newest first; the chart draws left to right.
    final points = exerciseProgress([
      entry(dayOffset: 10, sets: [set(weight: 80, reps: 5)]),
      entry(dayOffset: 0, sets: [set(weight: 70, reps: 5)]),
    ], displayUnit: 'kg');

    expect(points.map((p) => p.when).toList(),
        [base, base.add(const Duration(days: 10))]);
  });

  test('converts each session from its own unit', () {
    // 135 lb = 61.23 kg; e1RM at 5 reps = x(1 + 5/30).
    final points = exerciseProgress([
      entry(dayOffset: 0, unit: 'lb', sets: [set(weight: 135, reps: 5)]),
    ], displayUnit: 'kg');

    expect(points.single.value, closeTo(61.2349 * (1 + 5 / 30), 1e-3));
  });

  test('skips sets with no weight, no reps, or zero weight', () {
    // A zero weight is bodyweight work, not a lift — an e1RM of 0 would drag
    // the whole y-domain to zero.
    final points = exerciseProgress([
      entry(dayOffset: 0, sets: [
        set(weight: null, reps: 8),
        set(weight: 60, reps: null),
        set(weight: 0, reps: 20),
        set(weight: 50, reps: 5),
      ]),
    ], displayUnit: 'kg');

    expect(points.single.value, closeTo(50 * (1 + 5 / 30), 1e-9));
  });

  test('a session with nothing usable yields no point at all', () {
    final points = exerciseProgress([
      entry(dayOffset: 0, sets: [set(weight: 0, reps: 20)]),
    ], displayUnit: 'kg');

    expect(points, isEmpty, reason: 'no point beats a point at zero');
  });

  test('collapses two entries on the same date into one, keeping the best',
      () {
    // Reachable in practice: adding an exercise mid-session that the
    // routine already contains produces two `exerciseHistory` entries for
    // the same date, and the chart draws one point per session, not per
    // entry.
    final points = exerciseProgress([
      entry(dayOffset: 0, sets: [set(weight: 60, reps: 5)]),
      entry(dayOffset: 0, sets: [set(weight: 80, reps: 5)]),
    ], displayUnit: 'kg');

    expect(points, hasLength(1));
    expect(points.single.when, base);
    expect(points.single.value, closeTo(80 * (1 + 5 / 30), 1e-9));
  });

  test('caps reps at 12, so a 20-rep set scores as a 12-rep one', () {
    // Inherited from ADR-004's cap. Documented consequence: progress made by
    // adding reps beyond 12 does not move the line.
    final twenty = exerciseProgress([
      entry(dayOffset: 0, sets: [set(weight: 40, reps: 20)]),
    ], displayUnit: 'kg').single.value;
    final twelve = exerciseProgress([
      entry(dayOffset: 0, sets: [set(weight: 40, reps: 12)]),
    ], displayUnit: 'kg').single.value;

    expect(twenty, closeTo(twelve, 1e-9));
  });
}
