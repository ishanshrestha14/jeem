import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ids.dart';
import '../../../db/app_database.dart';
import '../../../db/seed_exercises.dart';

class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  Stream<List<Exercise>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.exercises)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm(expression: t.name)]);
    if (!includeArchived) q.where((t) => t.isArchived.equals(false));
    return q.watch();
  }

  Stream<List<Exercise>> watchSearch(String query,
      {bool includeArchived = false}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return watchAll(includeArchived: includeArchived);
    return watchAll(includeArchived: includeArchived).map(
      (rows) => rows
          .where((e) => e.name.toLowerCase().contains(trimmed.toLowerCase()))
          .toList(),
    );
  }

  Future<Exercise?> findById(String id) =>
      (_db.select(_db.exercises)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<Exercise> create({
    required String name,
    required LoggingType loggingType,
    String? category,
    String? description,
    String? notes,
    String? imagePath,
  }) async {
    final now = DateTime.now();
    final row = Exercise(
      id: newId(),
      name: name.trim(),
      category: category,
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
    await _db.batch((b) {
      b.insertAll(
        _db.exercises,
        [
          for (final s in seedExercises)
            ExercisesCompanion.insert(
              id: newId(),
              name: s.name,
              loggingType: s.loggingType,
              createdAt: now,
              updatedAt: now,
              category: Value(s.category),
              description: Value(s.description),
            ),
        ],
      );
    });
  }
}

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);
