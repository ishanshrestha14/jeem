import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/db/seed_exercises.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
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

  group('ExerciseRepository', () {
    late ExerciseRepository repo;

    setUp(() => repo = ExerciseRepository(db));

    test('seedIfEmpty populates the starter library exactly once', () async {
      await repo.seedIfEmpty();
      final first = await repo.watchAll().first;
      expect(first, hasLength(seedExercises.length));

      await repo.seedIfEmpty();
      final second = await repo.watchAll().first;
      expect(second, hasLength(seedExercises.length));
    });

    test('watchAll hides archived exercises unless asked', () async {
      final ex = await repo.create(
        name: 'Bench Press',
        loggingType: LoggingType.strengthWeightRepsRir,
      );
      await repo.archive(ex.id);

      expect(await repo.watchAll().first, isEmpty);
      expect(await repo.watchAll(includeArchived: true).first, hasLength(1));
    });

    test('watchSearch matches name case-insensitively', () async {
      await repo.create(name: 'Lat Pulldown', loggingType: LoggingType.strengthWeightRepsRir);
      await repo.create(name: 'Leg Press', loggingType: LoggingType.strengthWeightRepsRir);

      final hits = await repo.watchSearch('pull').first;
      expect(hits.map((e) => e.name), ['Lat Pulldown']);
    });

    test('update bumps updatedAt', () async {
      final ex = await repo.create(name: 'Plank', loggingType: LoggingType.durationOnly);
      // Timestamps are stored as ISO-8601 text with sub-second precision, so
      // a short delay is enough for updatedAt to differ.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.update(ex.copyWith(name: 'Side Plank'));

      final saved = await repo.watchAll().first;
      expect(saved.single.name, 'Side Plank');
      expect(saved.single.updatedAt.isAfter(ex.updatedAt), isTrue);
    });
  });
}
