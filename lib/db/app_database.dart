import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/utils/ids.dart';
import 'seed_exercises.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    ExerciseMuscles,
    ExerciseBodyParts,
    WorkoutPrograms,
    ProgramRoutines,
    WorkoutTemplates,
    TemplateExercises,
    WorkoutSessions,
    SessionExercises,
    SessionSets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  factory AppDatabase.open() => AppDatabase(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(workoutSessions, workoutSessions.pausedAt);
          }
          if (from < 3) {
            // v3 added typed muscle/equipment columns. v4 (below) replaces
            // the muscle column with a table, so a v2 install upgrading
            // straight to v4 only needs the columns v4 still keeps.
            await m.addColumn(exercises, exercises.equipment);
            await m.addColumn(exercises, exercises.isFavourite);
            // `category` is dropped only after the backfill has read it.
            await _migrateCategoriesToMuscles(from);
            await _insertMissingSeedExercises();
            await m.alterTable(TableMigration(exercises));
          }
          if (from < 4) {
            await m.createTable(exerciseMuscles);
            await m.createTable(exerciseBodyParts);
            // Only a genuine v3 install has rows to carry across; a v2
            // install was tagged directly into the v4 shape above.
            if (from == 3) {
              await _migrateV3MusclesToRoles();
              await m.alterTable(TableMigration(exercises));
            }
            await _deriveMissingBodyParts();
          }
          if (from < 5) {
            await m.createTable(workoutPrograms);
            await m.createTable(programRoutines);
          }
        },
        beforeOpen: (details) async {
          // Required for the onDelete: cascade references above to fire.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

/// Schema v3 backfill: moves the free-text `category` column onto the typed
/// [Muscle]/[Equipment] columns and the secondary-muscle join table, using the
/// per-exercise mapping reviewed in
/// `docs/tickets/T-004-appendix-seed-tags.md`.
///
/// Matching is by **exercise name**, because ids are generated per install and
/// cannot be relied on. Anything not in the table — every user-created
/// exercise — is left untagged rather than guessed at, which ADR-006 treats as
/// the normal state, not a failure.
extension _V3Backfill on AppDatabase {
  /// [from] is the schema the database is upgrading *from*: a v2 install has
  /// no `exercise_muscles` table yet at this point in the upgrade, so tags are
  /// staged and written once v4 creates it.
  Future<void> _migrateCategoriesToMuscles(int from) async {
    final rows = await select(exercises).get();
    if (rows.isEmpty) return;

    await batch((b) {
      for (final row in rows) {
        final tags = seedTagsByName[row.name.trim().toLowerCase()];
        if (tags == null) continue;
        b.update(
          exercises,
          ExercisesCompanion(equipment: Value(tags.equipment)),
          where: (t) => t.id.equals(row.id),
        );
        _pendingMuscleTags[row.id] = tags;
      }
    });
  }
}

/// Tags staged during the v2->v3 leg and written once the v4 tables exist.
/// Module-level because a Dart extension cannot hold state; it is cleared as
/// soon as it is drained, and a fresh install never populates it.
final Map<String, ExerciseTags> _pendingMuscleTags = {};

/// Adds seed exercises that the install does not already have, matched by
/// name. Runs **once**, as part of the v3 upgrade — not on every launch —
/// because a user who deletes a seeded exercise should not have it resurrected
/// every time they open the app.
///
/// Existing rows are never touched: this only inserts names that are absent.
/// `seedIfEmpty` still covers fresh installs.
extension _SeedBackfill on AppDatabase {
  Future<void> _insertMissingSeedExercises() async {
    final existing = await select(exercises).get();
    // Soft-deleted and archived rows count as present — their names are still
    // taken, and re-inserting would create a confusing duplicate.
    final taken = {for (final e in existing) e.name.trim().toLowerCase()};
    final missing = [
      for (final s in seedExercises)
        if (!taken.contains(s.name.toLowerCase())) s,
    ];
    if (missing.isEmpty) return;

    final now = DateTime.now();
    final ids = {for (final s in missing) s.name: newId()};
    await batch((b) {
      b.insertAll(exercises, [
        for (final s in missing)
          ExercisesCompanion.insert(
            id: ids[s.name]!,
            name: s.name,
            loggingType: s.loggingType,
            createdAt: now,
            updatedAt: now,
            equipment: Value(s.equipment),
            description: Value(s.description),
          ),
      ]);
    });
    for (final s in missing) {
      _pendingMuscleTags[ids[s.name]!] = (
        primary: s.primaryMuscles,
        secondary: s.secondaryMuscles,
        equipment: s.equipment,
      );
    }
  }
}

extension _V4Backfill on AppDatabase {
  /// Moves v3's single `primary_muscle` column and `exercise_secondary_muscles`
  /// table into the role-carrying [ExerciseMuscles] relation. Read with raw SQL
  /// because both are gone from the generated schema by now.
  Future<void> _migrateV3MusclesToRoles() async {
    final primaries = await customSelect(
      'SELECT id, primary_muscle FROM exercises '
      'WHERE primary_muscle IS NOT NULL;',
    ).get();
    final secondaries = await customSelect(
      'SELECT exercise_id, muscle FROM exercise_secondary_muscles;',
    ).get();

    await batch((b) {
      for (final row in primaries) {
        b.insert(
          exerciseMuscles,
          ExerciseMusclesCompanion.insert(
            exerciseId: row.read<String>('id'),
            muscle: Muscle.values.byName(row.read<String>('primary_muscle')),
            role: MuscleRole.primary,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      for (final row in secondaries) {
        b.insert(
          exerciseMuscles,
          ExerciseMusclesCompanion.insert(
            exerciseId: row.read<String>('exercise_id'),
            muscle: Muscle.values.byName(row.read<String>('muscle')),
            // insertOrIgnore, not replace: if a muscle somehow landed in both
            // roles, primary was written first and wins.
            role: MuscleRole.secondary,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
    await customStatement('DROP TABLE IF EXISTS exercise_secondary_muscles;');
  }

  /// Writes any tags staged during the v2->v3 leg, then gives every exercise
  /// that has muscles but no body parts a derived set. Existing body parts are
  /// never overwritten — a user's own tagging outranks derivation.
  Future<void> _deriveMissingBodyParts() async {
    if (_pendingMuscleTags.isNotEmpty) {
      final staged = Map.of(_pendingMuscleTags);
      _pendingMuscleTags.clear();
      await batch((b) {
        for (final entry in staged.entries) {
          for (final m in entry.value.primary) {
            b.insert(
              exerciseMuscles,
              ExerciseMusclesCompanion.insert(
                exerciseId: entry.key,
                muscle: m,
                role: MuscleRole.primary,
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
          for (final m in entry.value.secondary) {
            b.insert(
              exerciseMuscles,
              ExerciseMusclesCompanion.insert(
                exerciseId: entry.key,
                muscle: m,
                role: MuscleRole.secondary,
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
        }
      });
    }

    final withPrimary = await (select(exerciseMuscles)
          ..where((t) => t.role.equalsValue(MuscleRole.primary)))
        .get();
    final existing = await select(exerciseBodyParts).get();
    final alreadyTagged = {for (final r in existing) r.exerciseId};

    final derived = <String, Set<BodyPart>>{};
    for (final row in withPrimary) {
      if (alreadyTagged.contains(row.exerciseId)) continue;
      derived
          .putIfAbsent(row.exerciseId, () => <BodyPart>{})
          .add(bodyPartForMuscle(row.muscle));
    }
    if (derived.isEmpty) return;

    await batch((b) {
      for (final entry in derived.entries) {
        for (final part in entry.value) {
          b.insert(
            exerciseBodyParts,
            ExerciseBodyPartsCompanion.insert(
              exerciseId: entry.key,
              bodyPart: part,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      }
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'gymflow.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Overridden in main() and in tests. Reading it without an override is a bug.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);
