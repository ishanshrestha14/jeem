import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/records/data/personal_records.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';

/// A logged workout must be removable. Deleting one is not just a list
/// operation: records, volume and `Previous` are all derived from completed
/// sessions, so the deletion has to reach them too.
void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  String? sharedExerciseId;

  setUp(() {
    db = testDatabase();
    sessions = SessionRepository(db);
    sharedExerciseId = null;
  });
  tearDown(() => db.close());

  /// One finished session with a single `weight` x 5 set.
  ///
  /// The exercise is created once and reused, so two workouts are two
  /// sessions of the *same* lift — which is what makes the record test mean
  /// anything.
  Future<String> aLoggedWorkout({double weight = 100}) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    sharedExerciseId ??= (await exercises.create(
            name: 'Bench Press',
            loggingType: LoggingType.strengthWeightRepsRir))
        .id;
    await templates.addExercise(
        templateId: t.id, exerciseId: sharedExerciseId!, targetSets: 1);
    final s = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    final set = (await db.select(db.sessionSets).get()).last;
    await sessions.updateSet(set.copyWith(
      weight: Value(weight),
      reps: const Value(5),
      completedAt: Value(DateTime.now()),
    ));
    await sessions.finishSession(s.id);
    return s.id;
  }

  test('a deleted workout leaves the history', () async {
    final id = await aLoggedWorkout();
    expect(await sessions.watchCompletedSessions().first, hasLength(1));

    await sessions.deleteSession(id);

    expect(await sessions.watchCompletedSessions().first, isEmpty);
  });

  test('it is soft-deleted, not dropped', () async {
    final id = await aLoggedWorkout();

    await sessions.deleteSession(id);

    final row = await (db.select(db.workoutSessions)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    expect(row, isNotNull, reason: 'the row survives, as every delete here does');
    expect(row!.deletedAt, isNotNull);
  });

  test('its records go with it', () async {
    // The heavier session holds the PR; deleting it must hand the record back
    // to the lighter one rather than leaving a number nothing supports.
    await aLoggedWorkout(weight: 80);
    final heavy = await aLoggedWorkout(weight: 120);
    expect(
      computePersonalRecords(await sessions.watchCompletedSessions().first)
          .single
          .heaviestWeight!
          .weight,
      120,
    );

    await sessions.deleteSession(heavy);

    expect(
      computePersonalRecords(await sessions.watchCompletedSessions().first)
          .single
          .heaviestWeight!
          .weight,
      80,
    );
  });

  test('deleting the only workout leaves no records at all', () async {
    final id = await aLoggedWorkout();

    await sessions.deleteSession(id);

    expect(
      computePersonalRecords(await sessions.watchCompletedSessions().first),
      isEmpty,
    );
  });

  test('deleting an unknown id is a no-op, not a crash', () async {
    await aLoggedWorkout();

    await sessions.deleteSession('no-such-session');

    expect(await sessions.watchCompletedSessions().first, hasLength(1));
  });
}
