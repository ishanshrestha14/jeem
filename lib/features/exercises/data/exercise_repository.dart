import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ids.dart';
import '../../../db/app_database.dart';
import '../../../db/seed_exercises.dart';

/// The many-valued half of an exercise, loaded on demand.
class ExerciseTaxonomy {
  const ExerciseTaxonomy({
    this.primary = const [],
    this.secondary = const [],
    this.bodyParts = const [],
  });

  final List<Muscle> primary;
  final List<Muscle> secondary;
  final List<BodyPart> bodyParts;

  bool get isEmpty =>
      primary.isEmpty && secondary.isEmpty && bodyParts.isEmpty;
}

class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  Stream<List<Exercise>> watchAll({
    bool includeArchived = false,
    bool favouritesOnly = false,
  }) {
    final q = _db.select(_db.exercises)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    if (favouritesOnly) q.where((t) => t.isFavourite.equals(true));
    return q.watch();
  }

  Stream<List<Exercise>> watchSearch(
    String query, {
    bool includeArchived = false,
    bool favouritesOnly = false,
  }) {
    final trimmed = query.trim();
    final all = watchAll(
      includeArchived: includeArchived,
      favouritesOnly: favouritesOnly,
    );
    if (trimmed.isEmpty) return all;
    return all.map(
      (rows) => rows
          .where((e) => e.name.toLowerCase().contains(trimmed.toLowerCase()))
          .toList(),
    );
  }

  /// Muscles and body parts for one exercise. Kept off [Exercise] rather than
  /// joined into it: they are only needed on detail surfaces, and loading them
  /// for every row of a list would cost a query per exercise.
  Future<ExerciseTaxonomy> taxonomy(String exerciseId) async {
    final muscles = await (_db.select(_db.exerciseMuscles)
          ..where((t) => t.exerciseId.equals(exerciseId)))
        .get();
    final parts = await (_db.select(_db.exerciseBodyParts)
          ..where((t) => t.exerciseId.equals(exerciseId)))
        .get();
    return ExerciseTaxonomy(
      primary: [
        for (final r in muscles)
          if (r.role == MuscleRole.primary) r.muscle,
      ],
      secondary: [
        for (final r in muscles)
          if (r.role == MuscleRole.secondary) r.muscle,
      ],
      bodyParts: [for (final r in parts) r.bodyPart],
    );
  }

  /// Body parts for every exercise, in one query, so list rows can show their
  /// subtitle without a query each.
  Stream<Map<String, List<BodyPart>>> watchBodyPartsByExercise() {
    return _db.select(_db.exerciseBodyParts).watch().map((rows) {
      final out = <String, List<BodyPart>>{};
      for (final r in rows) {
        out.putIfAbsent(r.exerciseId, () => []).add(r.bodyPart);
      }
      return out;
    });
  }

  /// Replaces an exercise's whole taxonomy. Delete-then-insert rather than
  /// diffing: these are a handful of rows with no identity of their own.
  ///
  /// A muscle listed as both primary and secondary would violate the composite
  /// key, so secondaries are filtered against primaries here — the caller's
  /// mistake is corrected rather than thrown back at them.
  Future<void> setTaxonomy(
    String exerciseId, {
    required List<Muscle> primary,
    required List<Muscle> secondary,
    required List<BodyPart> bodyParts,
  }) async {
    final primarySet = primary.toSet();
    final secondarySet = secondary.toSet()..removeAll(primarySet);
    await _db.transaction(() async {
      await (_db.delete(_db.exerciseMuscles)
            ..where((t) => t.exerciseId.equals(exerciseId)))
          .go();
      await (_db.delete(_db.exerciseBodyParts)
            ..where((t) => t.exerciseId.equals(exerciseId)))
          .go();
      await _db.batch((b) {
        b.insertAll(_db.exerciseMuscles, [
          for (final m in primarySet)
            ExerciseMusclesCompanion.insert(
              exerciseId: exerciseId,
              muscle: m,
              role: MuscleRole.primary,
            ),
          for (final m in secondarySet)
            ExerciseMusclesCompanion.insert(
              exerciseId: exerciseId,
              muscle: m,
              role: MuscleRole.secondary,
            ),
        ]);
        b.insertAll(_db.exerciseBodyParts, [
          for (final p in bodyParts.toSet())
            ExerciseBodyPartsCompanion.insert(
              exerciseId: exerciseId,
              bodyPart: p,
            ),
        ]);
      });
    });
  }

  Future<void> setFavourite(String id, bool favourite) async {
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(
        isFavourite: Value(favourite),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Exercise?> findById(String id) =>
      (_db.select(_db.exercises)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<Exercise> create({
    required String name,
    required LoggingType loggingType,
    Equipment? equipment,
    List<Muscle> primaryMuscles = const [],
    List<Muscle> secondaryMuscles = const [],
    List<BodyPart> bodyParts = const [],
    String? description,
    String? notes,
    String? imagePath,
  }) async {
    final now = DateTime.now();
    final row = Exercise(
      id: newId(),
      name: name.trim(),
      equipment: equipment,
      isFavourite: false,
      loggingType: loggingType,
      description: description,
      notes: notes,
      imagePath: imagePath,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _db.into(_db.exercises).insert(row);
    if (primaryMuscles.isNotEmpty ||
        secondaryMuscles.isNotEmpty ||
        bodyParts.isNotEmpty) {
      await setTaxonomy(
        row.id,
        primary: primaryMuscles,
        secondary: secondaryMuscles,
        // Derived when the caller gives none, so a tagged exercise is always
        // browsable by body part without the user filling in both.
        bodyParts: bodyParts.isNotEmpty
            ? bodyParts
            : primaryMuscles.map(bodyPartForMuscle).toSet().toList(),
      );
    }
    return row;
  }

  Future<void> update(Exercise exercise) async {
    await _db.update(_db.exercises).replace(
          exercise.copyWith(updatedAt: DateTime.now()),
        );
  }

  Future<void> archive(String id) => _setArchived(id, true);

  Future<void> unarchive(String id) => _setArchived(id, false);

  Future<void> _setArchived(String id, bool archived) async {
    await (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Populates the starter library on first launch. No-op if any exercise
  /// already exists, so it is safe to call on every app start.
  Future<void> seedIfEmpty() async {
    final existing = await _db.select(_db.exercises).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    // Ids are generated up front so the secondary-muscle rows inserted in the
    // same batch can reference them.
    final ids = {for (final s in seedExercises) s.name: newId()};
    await _db.batch((b) {
      b.insertAll(
        _db.exercises,
        [
          for (final s in seedExercises)
            ExercisesCompanion.insert(
              id: ids[s.name]!,
              name: s.name,
              loggingType: s.loggingType,
              createdAt: now,
              updatedAt: now,
              equipment: Value(s.equipment),
              description: Value(s.description),
            ),
        ],
      );
      b.insertAll(_db.exerciseMuscles, [
        for (final s in seedExercises) ...[
          for (final m in s.primaryMuscles)
            ExerciseMusclesCompanion.insert(
              exerciseId: ids[s.name]!,
              muscle: m,
              role: MuscleRole.primary,
            ),
          for (final m in s.secondaryMuscles)
            ExerciseMusclesCompanion.insert(
              exerciseId: ids[s.name]!,
              muscle: m,
              role: MuscleRole.secondary,
            ),
        ],
      ]);
      b.insertAll(_db.exerciseBodyParts, [
        for (final s in seedExercises)
          for (final p in s.primaryMuscles.map(bodyPartForMuscle).toSet())
            ExerciseBodyPartsCompanion.insert(
              exerciseId: ids[s.name]!,
              bodyPart: p,
            ),
      ]);
    });
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);
