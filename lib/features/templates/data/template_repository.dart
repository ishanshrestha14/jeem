import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ids.dart';
import '../../../db/app_database.dart';
import 'template_models.dart';

class TemplateRepository {
  TemplateRepository(this._db);

  final AppDatabase _db;

  /// Joins `templateExercises` to `exercises` WITHOUT filtering on
  /// `isArchived` — a template must keep showing an exercise the user has
  /// archived (flagged via `TemplateExerciseWithExercise.isArchived`) so the
  /// user can see it and replace it (PRD §18.2). Only
  /// `ExerciseRepository.watchAll` hides archived exercises.
  Stream<TemplateWithExercises?> watchTemplate(String id) {
    final query = _db.select(_db.workoutTemplates).join([
      leftOuterJoin(
        _db.templateExercises,
        _db.templateExercises.templateId.equalsExp(_db.workoutTemplates.id) &
            _db.templateExercises.deletedAt.isNull(),
      ),
      leftOuterJoin(
        _db.exercises,
        _db.exercises.id.equalsExp(_db.templateExercises.exerciseId) &
            _db.exercises.deletedAt.isNull(),
      ),
    ])
      ..where(_db.workoutTemplates.id.equals(id) &
          _db.workoutTemplates.deletedAt.isNull())
      ..orderBy([OrderingTerm(expression: _db.templateExercises.sortOrder)]);

    return query.watch().map((rows) {
      if (rows.isEmpty) return null;

      final template = rows.first.readTable(_db.workoutTemplates);
      final exercises = <TemplateExerciseWithExercise>[];
      for (final row in rows) {
        final config = row.readTableOrNull(_db.templateExercises);
        final exercise = row.readTableOrNull(_db.exercises);
        if (config != null && exercise != null) {
          exercises.add(
            TemplateExerciseWithExercise(config: config, exercise: exercise),
          );
        }
      }
      return TemplateWithExercises(template: template, exercises: exercises);
    });
  }

  Stream<List<TemplateSummary>> watchSummaries() async* {
    yield await _fetchSummaries();
    await for (final _ in _db.tableUpdates(TableUpdateQuery.onAllTables({
      _db.workoutTemplates,
      _db.templateExercises,
      _db.workoutSessions,
    }))) {
      yield await _fetchSummaries();
    }
  }

  Future<List<TemplateSummary>> _fetchSummaries() async {
    final templates = await (_db.select(_db.workoutTemplates)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();

    final summaries = <TemplateSummary>[];
    for (final template in templates) {
      final exerciseRows = await (_db.select(_db.templateExercises)
            ..where((t) =>
                t.templateId.equals(template.id) & t.deletedAt.isNull()))
          .get();

      final lastSession = await (_db.select(_db.workoutSessions)
            ..where((t) =>
                t.templateId.equals(template.id) &
                t.status.equalsValue(SessionStatus.completed) &
                t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.endedAt)])
            ..limit(1))
          .getSingleOrNull();

      summaries.add(TemplateSummary(
        template: template,
        exerciseCount: exerciseRows.length,
        totalSets: exerciseRows.fold(0, (sum, e) => sum + e.targetSets),
        lastPerformedAt: lastSession?.endedAt,
      ));
    }
    return summaries;
  }

  Future<WorkoutTemplate> createTemplate({
    required String name,
    String? notes,
    int defaultRestSeconds = 90,
  }) async {
    final now = DateTime.now();
    final row = WorkoutTemplate(
      id: newId(),
      name: name.trim(),
      notes: notes,
      defaultRestSeconds: defaultRestSeconds,
      autoFocusNextSet: true,
      autoFocusNextExercise: true,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _db.into(_db.workoutTemplates).insert(row);
    return row;
  }

  Future<void> updateTemplate(WorkoutTemplate template) async {
    await _db.update(_db.workoutTemplates).replace(
          template.copyWith(updatedAt: DateTime.now()),
        );
  }

  Future<void> deleteTemplate(String id) async {
    await (_db.delete(_db.workoutTemplates)..where((t) => t.id.equals(id)))
        .go();
  }

  Future<WorkoutTemplate> duplicateTemplate(String id) async {
    return _db.transaction(() async {
      final original = await (_db.select(_db.workoutTemplates)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      final originalExercises = await (_db.select(_db.templateExercises)
            ..where((t) => t.templateId.equals(id) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

      final now = DateTime.now();
      final copy = WorkoutTemplate(
        id: newId(),
        name: '${original.name} (copy)',
        notes: original.notes,
        defaultRestSeconds: original.defaultRestSeconds,
        autoFocusNextSet: original.autoFocusNextSet,
        autoFocusNextExercise: original.autoFocusNextExercise,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );
      await _db.into(_db.workoutTemplates).insert(copy);

      for (final te in originalExercises) {
        await _db.into(_db.templateExercises).insert(
              TemplateExercise(
                id: newId(),
                templateId: copy.id,
                exerciseId: te.exerciseId,
                sortOrder: te.sortOrder,
                targetSets: te.targetSets,
                restSeconds: te.restSeconds,
                defaultRir: te.defaultRir,
                defaultDurationSeconds: te.defaultDurationSeconds,
                notes: te.notes,
                createdAt: now,
                updatedAt: now,
                deletedAt: null,
              ),
            );
      }
      return copy;
    });
  }

  Future<TemplateExercise> addExercise({
    required String templateId,
    required String exerciseId,
    int? targetSets,
    int? restSeconds,
    double? defaultRir,
    int? defaultDurationSeconds,
  }) async {
    final existing = await (_db.select(_db.templateExercises)
          ..where(
              (t) => t.templateId.equals(templateId) & t.deletedAt.isNull()))
        .get();
    final sortOrder = existing.isEmpty
        ? 0
        : existing.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) +
            1;

    final now = DateTime.now();
    final row = TemplateExercise(
      id: newId(),
      templateId: templateId,
      exerciseId: exerciseId,
      sortOrder: sortOrder,
      targetSets: targetSets ?? 3,
      restSeconds: restSeconds ?? 90,
      defaultRir: defaultRir,
      defaultDurationSeconds: defaultDurationSeconds,
      notes: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _db.into(_db.templateExercises).insert(row);
    return row;
  }

  Future<void> updateTemplateExercise(TemplateExercise te) async {
    await _db.update(_db.templateExercises).replace(
          te.copyWith(updatedAt: DateTime.now()),
        );
  }

  Future<void> removeTemplateExercise(String id) async {
    await _db.transaction(() async {
      final te = await (_db.select(_db.templateExercises)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (te == null) return;

      await (_db.delete(_db.templateExercises)..where((t) => t.id.equals(id)))
          .go();

      final remaining = await (_db.select(_db.templateExercises)
            ..where((t) =>
                t.templateId.equals(te.templateId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

      for (var i = 0; i < remaining.length; i++) {
        await (_db.update(_db.templateExercises)
              ..where((t) => t.id.equals(remaining[i].id)))
            .write(TemplateExercisesCompanion(
          sortOrder: Value(i),
          updatedAt: Value(DateTime.now()),
        ));
      }
    });
  }

  Future<void> reorderExercises(
      String templateId, int oldIndex, int newIndex) async {
    await _db.transaction(() async {
      final list = await (_db.select(_db.templateExercises)
            ..where(
                (t) => t.templateId.equals(templateId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);

      for (var i = 0; i < list.length; i++) {
        await (_db.update(_db.templateExercises)
              ..where((t) => t.id.equals(list[i].id)))
            .write(TemplateExercisesCompanion(
          sortOrder: Value(i),
          updatedAt: Value(DateTime.now()),
        ));
      }
    });
  }
}

final templateRepositoryProvider = Provider<TemplateRepository>(
  (ref) => TemplateRepository(ref.watch(databaseProvider)),
);
