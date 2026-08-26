import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';

import '../db/test_database.dart';

/// S-023: the finish form is an *editable* record of what happened, not a
/// read-only summary. Two values are worth correcting because otherwise they
/// are wrong forever and feed the weekly summary: the name, and the duration.
void main() {
  late AppDatabase db;
  late SessionRepository sessions;

  setUp(() {
    db = testDatabase();
    sessions = SessionRepository(db);
  });
  tearDown(() => db.close());

  Future<WorkoutSession> anAdHocSession() =>
      sessions.startAdHoc(weightUnit: 'kg');

  Future<WorkoutSession> reload(String id) async =>
      (await (db.select(db.workoutSessions)..where((t) => t.id.equals(id)))
              .getSingle());

  test('finishing can rename the session', () async {
    // Every ad-hoc session starts as "Workout" (T-012); the finish form is
    // the natural moment to say what it actually was.
    final s = await anAdHocSession();
    expect(s.name, 'Workout');

    await sessions.finishSession(s.id, name: 'Evening push');

    expect((await reload(s.id)).name, 'Evening push');
  });

  test('an omitted name leaves the existing one alone', () async {
    final s = await anAdHocSession();

    await sessions.finishSession(s.id, notes: 'felt strong');

    expect((await reload(s.id)).name, 'Workout');
  });

  test('a blank name is ignored rather than saved', () async {
    final s = await anAdHocSession();

    await sessions.finishSession(s.id, name: '   ');

    // A nameless workout is worse than a generically-named one.
    expect((await reload(s.id)).name, 'Workout');
  });

  test('finishing can correct the duration', () async {
    // The "I left the timer running" case: the recorded duration is whatever
    // the clock said, and it feeds the weekly summary until corrected.
    final s = await anAdHocSession();

    await sessions.finishSession(s.id, duration: const Duration(minutes: 45));

    final saved = await reload(s.id);
    final actual = saved.endedAt!.difference(saved.startedAt) -
        Duration(seconds: saved.pausedSeconds);
    expect(actual, const Duration(minutes: 45));
  });

  test('an omitted duration keeps what the clock recorded', () async {
    final s = await anAdHocSession();

    await sessions.finishSession(s.id);

    final saved = await reload(s.id);
    expect(saved.endedAt, isNotNull);
    // Ended now, not shifted to some computed point.
    expect(saved.endedAt!.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5));
  });

  test('a negative duration is refused rather than inverting the session',
      () async {
    final s = await anAdHocSession();

    await sessions.finishSession(s.id, duration: const Duration(minutes: -5));

    final saved = await reload(s.id);
    expect(saved.endedAt!.isAfter(saved.startedAt), isTrue);
  });

  test('renaming still completes the session', () async {
    final s = await anAdHocSession();

    await sessions.finishSession(s.id, name: 'Legs');

    expect((await reload(s.id)).status, SessionStatus.completed);
  });
}
