import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  test('round-trips an exercise including its logging type enum', () async {
    final now = DateTime.utc(2026, 8, 15, 10);
    await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'ex-1',
          name: 'Bench Press',
          loggingType: LoggingType.strengthWeightRepsRir,
          createdAt: now,
          updatedAt: now,
          category: const Value('Chest'),
          description: const Value('Barbell press on a flat bench.'),
        ));

    final row = await db.select(db.exercises).getSingle();

    expect(row.name, 'Bench Press');
    expect(row.loggingType, LoggingType.strengthWeightRepsRir);
    expect(row.category, 'Chest');
    expect(row.isArchived, isFalse);
    expect(row.deletedAt, isNull);
  });

  test('deleting a session cascades to its exercises and sets', () async {
    final now = DateTime.utc(2026, 8, 15, 10);
    await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
          id: 's-1',
          name: 'Push',
          status: SessionStatus.active,
          startedAt: now,
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.sessionExercises).insert(SessionExercisesCompanion.insert(
          id: 'se-1',
          sessionId: 's-1',
          name: 'Bench Press',
          loggingType: LoggingType.strengthWeightRepsRir,
          sortOrder: 0,
          restSeconds: 90,
          targetSets: 3,
          createdAt: now,
          updatedAt: now,
        ));
    await db.into(db.sessionSets).insert(SessionSetsCompanion.insert(
          id: 'set-1',
          sessionExerciseId: 'se-1',
          setIndex: 0,
          createdAt: now,
          updatedAt: now,
        ));

    await (db.delete(db.workoutSessions)..where((t) => t.id.equals('s-1'))).go();

    expect(await db.select(db.sessionExercises).get(), isEmpty);
    expect(await db.select(db.sessionSets).get(), isEmpty);
  });
}
