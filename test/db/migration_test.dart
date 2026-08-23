import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';

/// Schema migration tests.
///
/// Two upgrade paths have to work, and they are genuinely different code
/// paths — a v2 install jumps both legs in one open, while a v3 install has
/// real rows in the old shape to carry across:
///
///   v2 -> v4  (T-004 + T-005 in one go)
///   v3 -> v4  (T-005 alone)
///
/// The old DDL below is written out rather than generated. It only needs to be
/// shape-compatible with what drift produced then; the migrations are what is
/// under test, not the old schemas' exact text.
void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('gymflow-migration-test');
    file = File('${dir.path}/v2.sqlite');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<void> createV2Database() async {
    final raw = NativeDatabase(file);
    // A minimal drift-shaped v2 `exercises` table: note `category`, and the
    // absence of primary_muscle / equipment / is_favourite.
    await raw.ensureOpen(_NoopUser());
    await raw.runCustom('''
      CREATE TABLE exercises (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NULL,
        logging_type TEXT NOT NULL,
        description TEXT NULL,
        notes TEXT NULL,
        image_path TEXT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT NULL,
        PRIMARY KEY (id)
      );
    ''', const []);
    await raw.runCustom('PRAGMA user_version = 2;', const []);
    await raw.close();
  }

  Future<void> insertV2Exercise({
    required String id,
    required String name,
    String? category,
  }) async {
    final raw = NativeDatabase(file);
    await raw.ensureOpen(_NoopUser());
    await raw.runCustom(
      'INSERT INTO exercises (id, name, category, logging_type, created_at, '
      'updated_at, is_archived) VALUES (?, ?, ?, ?, ?, ?, 0);',
      [
        id,
        name,
        category,
        'strengthWeightRepsRir',
        '2026-08-01T10:00:00.000Z',
        '2026-08-01T10:00:00.000Z',
      ],
    );
    await raw.close();
  }

  Future<void> createV3Database() async {
    final raw = NativeDatabase(file);
    await raw.ensureOpen(_NoopUser());
    await raw.runCustom('''
      CREATE TABLE exercises (
        id TEXT NOT NULL,
        name TEXT NOT NULL,
        primary_muscle TEXT NULL,
        equipment TEXT NULL,
        is_favourite INTEGER NOT NULL DEFAULT 0 CHECK (is_favourite IN (0, 1)),
        logging_type TEXT NOT NULL,
        description TEXT NULL,
        notes TEXT NULL,
        image_path TEXT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT NULL,
        PRIMARY KEY (id)
      );
    ''', const []);
    await raw.runCustom('''
      CREATE TABLE exercise_secondary_muscles (
        exercise_id TEXT NOT NULL REFERENCES exercises (id) ON DELETE CASCADE,
        muscle TEXT NOT NULL,
        PRIMARY KEY (exercise_id, muscle)
      );
    ''', const []);
    await raw.runCustom(
      'INSERT INTO exercises (id, name, primary_muscle, equipment, '
      'logging_type, created_at, updated_at, is_archived) '
      "VALUES ('row-1', 'Barbell Row', 'lats', 'barbell', "
      "'strengthWeightRepsRir', '2026-08-01T10:00:00.000Z', "
      "'2026-08-01T10:00:00.000Z', 0);",
      const [],
    );
    await raw.runCustom(
      'INSERT INTO exercise_secondary_muscles (exercise_id, muscle) '
      "VALUES ('row-1', 'biceps'), ('row-1', 'upperBack');",
      const [],
    );
    await raw.runCustom('PRAGMA user_version = 3;', const []);
    await raw.close();
  }

  test('upgrades v2 -> v4, backfilling seed tags and preserving rows',
      () async {
    await createV2Database();
    await insertV2Exercise(
      id: 'seeded-1',
      name: 'Barbell Bench Press',
      category: 'Chest',
    );
    // A user-created exercise the backfill knows nothing about. It must
    // survive untagged rather than being guessed at or dropped (ADR-006).
    await insertV2Exercise(
      id: 'mine-1',
      name: 'Ishan Special Curl',
      category: 'Arms',
    );

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final rows = await (db.select(db.exercises)
          ..orderBy([(t) => OrderingTerm(expression: t.id)]))
        .get();

    // The two v2 rows survive; the rest are the one-time seed backfill.
    expect(rows.where((r) => r.id == 'seeded-1' || r.id == 'mine-1'),
        hasLength(2));

    final mine = rows.firstWhere((r) => r.id == 'mine-1');
    expect(mine.name, 'Ishan Special Curl', reason: 'row must survive');
    final mineMuscles = await (db.select(db.exerciseMuscles)
          ..where((t) => t.exerciseId.equals('mine-1')))
        .get();
    expect(mineMuscles, isEmpty, reason: 'unknown names stay untagged');
    expect(mine.equipment, isNull);
    expect(mine.isFavourite, isFalse, reason: 'new column defaults to false');

    final seeded = rows.firstWhere((r) => r.id == 'seeded-1');
    expect(seeded.equipment, Equipment.barbell);

    final muscles = await (db.select(db.exerciseMuscles)
          ..where((t) => t.exerciseId.equals('seeded-1')))
        .get();
    expect(
      muscles
          .where((r) => r.role == MuscleRole.primary)
          .map((r) => r.muscle)
          .toSet(),
      {Muscle.chest},
    );
    expect(
      muscles
          .where((r) => r.role == MuscleRole.secondary)
          .map((r) => r.muscle)
          .toSet(),
      {Muscle.triceps, Muscle.deltsFront},
    );

    // Body parts are derived from the primaries, so a tagged exercise is
    // browsable by body part without anyone filling in both.
    final parts = await (db.select(db.exerciseBodyParts)
          ..where((t) => t.exerciseId.equals('seeded-1')))
        .get();
    expect(parts.map((r) => r.bodyPart).toSet(), {BodyPart.chest});

    // An untagged exercise gets no rows at all — not a default body part.
    final minePartsCount = await (db.select(db.exerciseBodyParts)
          ..where((t) => t.exerciseId.equals('mine-1')))
        .get();
    expect(minePartsCount, isEmpty);

    // Seed exercises absent from the v2 install are backfilled once, tagged.
    final all = await db.select(db.exercises).get();
    final byName = {for (final r in all) r.name: r};
    expect(byName.containsKey('Bulgarian Split Squat'), isTrue,
        reason: 'new seed entries reach an existing install');
    final splitSquatMuscles = await (db.select(db.exerciseMuscles)
          ..where((t) =>
              t.exerciseId.equals(byName['Bulgarian Split Squat']!.id) &
              t.role.equalsValue(MuscleRole.primary)))
        .get();
    expect(splitSquatMuscles.map((r) => r.muscle), [Muscle.quadriceps]);
    // ...without duplicating what was already there.
    expect(
      all.where((r) => r.name == 'Barbell Bench Press'),
      hasLength(1),
    );
    expect(byName['Barbell Bench Press']!.id, 'seeded-1',
        reason: 'the original row is kept, not replaced');
    expect(byName.containsKey('Ishan Special Curl'), isTrue);

    // The free-text column is gone, replaced by the typed pair.
    final columns = await db
        .customSelect('PRAGMA table_info(exercises);')
        .get();
    final names = columns.map((r) => r.read<String>('name')).toSet();
    expect(names, isNot(contains('category')));
    expect(names, isNot(contains('primary_muscle')),
        reason: 'v4 moves muscles into their own table');
    expect(names, containsAll(['equipment', 'is_favourite']));
  });

  test('upgrades v3 -> v4, converting the single primary and secondaries',
      () async {
    await createV3Database();

    final db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);

    final muscles = await (db.select(db.exerciseMuscles)
          ..where((t) => t.exerciseId.equals('row-1')))
        .get();
    expect(
      muscles
          .where((r) => r.role == MuscleRole.primary)
          .map((r) => r.muscle),
      [Muscle.lats],
      reason: 'the v3 column becomes a primary row',
    );
    expect(
      muscles
          .where((r) => r.role == MuscleRole.secondary)
          .map((r) => r.muscle)
          .toSet(),
      {Muscle.biceps, Muscle.upperBack},
      reason: 'the v3 join table becomes secondary rows',
    );

    final parts = await (db.select(db.exerciseBodyParts)
          ..where((t) => t.exerciseId.equals('row-1')))
        .get();
    expect(parts.map((r) => r.bodyPart).toSet(), {BodyPart.back});

    final row = await (db.select(db.exercises)
          ..where((t) => t.id.equals('row-1')))
        .getSingle();
    expect(row.name, 'Barbell Row');
    expect(row.equipment, Equipment.barbell);

    // The superseded table is gone.
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table';")
        .get();
    expect(
      tables.map((r) => r.read<String>('name')),
      isNot(contains('exercise_secondary_muscles')),
    );
  });

  test('a fresh database creates the v4 taxonomy tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.select(db.exerciseMuscles).get();
    await db.select(db.exerciseBodyParts).get();
    expect(db.schemaVersion, 4);
  });
}

/// `ensureOpen` needs a `QueryExecutorUser`; these raw handles only run DDL,
/// so both callbacks are deliberately inert.
class _NoopUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 2;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
