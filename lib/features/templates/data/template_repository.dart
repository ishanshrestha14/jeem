import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ids.dart';
import '../../../db/app_database.dart';
import 'template_models.dart';

/// Emits whenever either source does, once both have produced a value.
///
/// Hand-rolled rather than pulling in rxdart for one operator: the routine
/// stream needs the exercises *and* their planned sets, and a single drift
/// join cannot watch both without duplicating every exercise row per set.
Stream<R> _combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;

  void emit() {
    if (hasA && hasB) controller.add(combine(latestA as A, latestB as B));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen((value) {
        latestA = value;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((value) {
        latestB = value;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    // Not awaited. Cancelling a drift query-stream subscription can never
    // complete on this drift/Dart version — the same hang `watchSummaries`
    // below is hand-rolled to avoid. Awaiting here would leave the
    // controller's own cancel pending forever, which surfaces as a widget
    // test that hangs in teardown rather than as an error.
    onCancel: () {
      unawaited(subA?.cancel() ?? Future<void>.value());
      unawaited(subB?.cancel() ?? Future<void>.value());
    },
  );
  return controller.stream;
}

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

    // The planned sets are watched alongside, so adding or editing a set
    // refreshes the routine without a second subscription in the UI.
    final sets = (_db.select(_db.templateSets)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .watch();

    return _combineLatest2(query.watch(), sets, (rows, allSets) {
      if (rows.isEmpty) return null;

      final byExercise = <String, List<TemplateSet>>{};
      for (final set in allSets) {
        byExercise.putIfAbsent(set.templateExerciseId, () => []).add(set);
      }

      final template = rows.first.readTable(_db.workoutTemplates);
      final exercises = <TemplateExerciseWithExercise>[];
      for (final row in rows) {
        final config = row.readTableOrNull(_db.templateExercises);
        final exercise = row.readTableOrNull(_db.exercises);
        if (config != null && exercise != null) {
          exercises.add(TemplateExerciseWithExercise(
            config: config,
            exercise: exercise,
            sets: byExercise[config.id] ?? const [],
          ));
        }
      }
      return TemplateWithExercises(template: template, exercises: exercises);
    });
  }

  /// Hand-rolled (rather than `async*`) because cancelling a subscription
  /// to an `async*` generator that is parked inside `await for` over the
  /// broadcast stream returned by `db.tableUpdates` never completes on this
  /// drift/Dart version — `StreamSubscription.cancel()` hangs forever. A
  /// `StreamController` with an explicit `onCancel` sidesteps that and
  /// cancels cleanly. Emits are chained through [_pendingFetch] so that
  /// rapid, overlapping table updates can't resolve out of order.
  Stream<List<TemplateSummary>> watchSummaries() {
    late StreamController<List<TemplateSummary>> controller;
    StreamSubscription<Set<TableUpdate>>? tableSub;
    var pendingFetch = Future<void>.value();

    void scheduleEmit() {
      // Caught explicitly and chained via `.catchError` (rather than left to
      // propagate) so a throwing `_fetchSummaries()` can't leave
      // `pendingFetch` permanently errored — a bare `.then()` on an errored
      // future skips the success callback forever, silently killing every
      // later emission on this stream.
      pendingFetch = pendingFetch.then((_) async {
        if (controller.isClosed) return;
        final summaries = await _fetchSummaries();
        if (!controller.isClosed) controller.add(summaries);
      }).catchError((Object error, StackTrace stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      });
    }

    controller = StreamController<List<TemplateSummary>>(
      onListen: () {
        scheduleEmit();
        tableSub = _db.tableUpdates(TableUpdateQuery.onAllTables({
          _db.workoutTemplates,
          _db.templateExercises,
          _db.workoutSessions,
        })).listen((_) => scheduleEmit());
      },
      onCancel: () async {
        await tableSub?.cancel();
      },
    );

    return controller.stream;
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
        totalSets: await _plannedSetCount(exerciseRows),
        lastPerformedAt: lastSession?.endedAt,
      ));
    }
    return summaries;
  }

  /// Total planned sets across a template's exercises. Counted from rows
  /// since v6 — there is no per-exercise total to add up any more.
  Future<int> _plannedSetCount(List<TemplateExercise> exercises) async {
    if (exercises.isEmpty) return 0;
    final rows = await (_db.select(_db.templateSets)
          ..where((t) =>
              t.templateExerciseId.isIn([for (final e in exercises) e.id]) &
              t.deletedAt.isNull()))
        .get();
    return rows.length;
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
        final copiedId = newId();
        await _db.into(_db.templateExercises).insert(
              TemplateExercise(
                id: copiedId,
                templateId: copy.id,
                exerciseId: te.exerciseId,
                sortOrder: te.sortOrder,
                restSeconds: te.restSeconds,
                notes: te.notes,
                createdAt: now,
                updatedAt: now,
                deletedAt: null,
              ),
            );
        // The prescription is the point of duplicating a routine, so the
        // planned sets come with it.
        for (final set in await setsFor(te.id)) {
          await _db.into(_db.templateSets).insert(
                TemplateSet(
                  id: newId(),
                  templateExerciseId: copiedId,
                  setIndex: set.setIndex,
                  weight: set.weight,
                  reps: set.reps,
                  repsMax: set.repsMax,
                  rir: set.rir,
                  durationSeconds: set.durationSeconds,
                  createdAt: now,
                  updatedAt: now,
                  deletedAt: null,
                ),
              );
        }
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
      restSeconds: restSeconds ?? 90,
      notes: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _db.into(_db.templateExercises).insert(row);

    // An exercise with no sets is not a plan, so it arrives with rows —
    // unprescribed, which the editor shows as "Press to add details".
    final count = targetSets ?? 3;
    await _db.batch((b) {
      for (var i = 0; i < count; i++) {
        b.insert(
          _db.templateSets,
          TemplateSetsCompanion.insert(
            id: newId(),
            templateExerciseId: row.id,
            setIndex: i,
            createdAt: now,
            updatedAt: now,
            rir: Value(defaultRir),
            durationSeconds: Value(defaultDurationSeconds),
          ),
        );
      }
    });
    return row;
  }

  // -------------------------------------------------------------------
  // Planned sets (T-002)
  // -------------------------------------------------------------------

  Future<List<TemplateSet>> setsFor(String templateExerciseId) async {
    return (_db.select(_db.templateSets)
          ..where((t) =>
              t.templateExerciseId.equals(templateExerciseId) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
        .get();
  }

  /// Swaps which exercise a routine row points at, **keeping its prescribed
  /// sets** — S-029's "Replace exercise".
  ///
  /// The problem it solves is the machine being taken: you want the same plan
  /// against a different movement, not to rebuild it set by set. Position in
  /// the routine is untouched, because a replacement takes the place of what
  /// it replaced.
  ///
  /// **Numbers that cannot transfer are cleared.** Swapping a strength
  /// exercise for a duration one leaves weight and reps meaningless — they
  /// would render as nonsense in the set table and snapshot into the next
  /// session. The set *count* survives, because "three sets" is still what you
  /// planned; only the numbers that no longer apply are dropped.
  ///
  /// Throws if [newExerciseId] does not exist, before writing anything.
  Future<void> replaceExercise(
    String templateExerciseId,
    String newExerciseId,
  ) async {
    await _db.transaction(() async {
      final replacement = await (_db.select(_db.exercises)
            ..where((e) => e.id.equals(newExerciseId) & e.deletedAt.isNull()))
          .getSingle();

      final row = await (_db.select(_db.templateExercises)
            ..where((t) => t.id.equals(templateExerciseId)))
          .getSingle();
      final previous = await (_db.select(_db.exercises)
            ..where((e) => e.id.equals(row.exerciseId)))
          .getSingleOrNull();

      final now = DateTime.now();
      await (_db.update(_db.templateExercises)
            ..where((t) => t.id.equals(templateExerciseId)))
          .write(TemplateExercisesCompanion(
        exerciseId: Value(replacement.id),
        updatedAt: Value(now),
      ));

      if (previous?.loggingType == replacement.loggingType) return;

      // The logging type changed, so half the prescription no longer means
      // anything. Clear only that half.
      final toDuration = replacement.loggingType == LoggingType.durationOnly;
      await (_db.update(_db.templateSets)
            ..where((t) => t.templateExerciseId.equals(templateExerciseId)))
          .write(TemplateSetsCompanion(
        weight: toDuration ? const Value(null) : const Value.absent(),
        reps: toDuration ? const Value(null) : const Value.absent(),
        repsMax: toDuration ? const Value(null) : const Value.absent(),
        durationSeconds:
            toDuration ? const Value.absent() : const Value(null),
        updatedAt: Value(now),
      ));
    });
  }

  Future<TemplateSet> addSet(String templateExerciseId) async {
    final existing = await setsFor(templateExerciseId);
    final now = DateTime.now();
    // A new set copies the last one: the common case is another set of the
    // same thing, and typing it again would be busywork.
    final previous = existing.isEmpty ? null : existing.last;
    final row = TemplateSet(
      id: newId(),
      templateExerciseId: templateExerciseId,
      setIndex: existing.length,
      weight: previous?.weight,
      reps: previous?.reps,
      repsMax: previous?.repsMax,
      rir: previous?.rir,
      durationSeconds: previous?.durationSeconds,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _db.into(_db.templateSets).insert(row);
    return row;
  }

  Future<void> updateSet(
    String setId, {
    Value<double?> weight = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<int?> repsMax = const Value.absent(),
    Value<double?> rir = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
  }) async {
    await (_db.update(_db.templateSets)..where((t) => t.id.equals(setId)))
        .write(TemplateSetsCompanion(
      weight: weight,
      reps: reps,
      repsMax: repsMax,
      rir: rir,
      durationSeconds: durationSeconds,
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<void> removeSet(String setId) async {
    final row = await (_db.select(_db.templateSets)
          ..where((t) => t.id.equals(setId)))
        .getSingleOrNull();
    if (row == null) return;
    await (_db.delete(_db.templateSets)..where((t) => t.id.equals(setId))).go();
    // Resequence, so a gap can never collide with the next insert.
    final remaining = await setsFor(row.templateExerciseId);
    final now = DateTime.now();
    await _db.batch((b) {
      for (var i = 0; i < remaining.length; i++) {
        b.update(
          _db.templateSets,
          TemplateSetsCompanion(setIndex: Value(i), updatedAt: Value(now)),
          where: (t) => t.id.equals(remaining[i].id),
        );
      }
    });
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

  /// Reorders exercises using `ReorderableListView.onReorder`'s raw index
  /// convention: `newIndex` is the target index computed BEFORE `oldIndex`
  /// is removed from the list, so for a downward drag it is one too high
  /// relative to the post-removal list. This method normalises internally
  /// (`if (newIndex > oldIndex) newIndex -= 1`) — callers should pass the
  /// raw values straight from `onReorder` without adjusting them first.
  Future<void> reorderExercises(
      String templateId, int oldIndex, int newIndex) async {
    await _db.transaction(() async {
      final list = await (_db.select(_db.templateExercises)
            ..where(
                (t) => t.templateId.equals(templateId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

      var target = newIndex;
      if (target > oldIndex) target -= 1;

      final item = list.removeAt(oldIndex);
      list.insert(target, item);

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
