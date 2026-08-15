import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ids.dart';
import '../../../db/app_database.dart';
import 'session_models.dart';

class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  /// Turns a template into an immutable snapshot: a [WorkoutSession] plus
  /// one [SessionExercise] per template exercise (denormalising `name`,
  /// `description`, `notes`, `imagePath`, `loggingType` from the library
  /// [Exercise] and `sortOrder`/`restSeconds`/`targetSets` from the
  /// [TemplateExercise] config row) plus `targetSets` [SessionSet] rows
  /// seeded with the config's `defaultRir`/`defaultDurationSeconds`. Once
  /// written, none of this reads from the template again.
  Future<WorkoutSession> startFromTemplate(
    String templateId, {
    required String weightUnit,
  }) {
    return _db.transaction(() async {
      final template = await (_db.select(_db.workoutTemplates)
            ..where((t) => t.id.equals(templateId) & t.deletedAt.isNull()))
          .getSingle();

      final templateExerciseRows = await (_db.select(_db.templateExercises)
            ..where((t) =>
                t.templateId.equals(templateId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
          .get();

      final now = DateTime.now();
      final session = WorkoutSession(
        id: newId(),
        templateId: template.id,
        name: template.name,
        weightUnit: weightUnit,
        status: SessionStatus.active,
        autoFocusNextSet: template.autoFocusNextSet,
        autoFocusNextExercise: template.autoFocusNextExercise,
        startedAt: now,
        endedAt: null,
        pausedSeconds: 0,
        notes: null,
        restStatus: RestTimerStatus.idle,
        restEndsAt: null,
        restRemainingSeconds: null,
        restTotalSeconds: null,
        restAfterSetId: null,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );
      await _db.into(_db.workoutSessions).insert(session);

      for (final config in templateExerciseRows) {
        final exercise = await (_db.select(_db.exercises)
              ..where((e) =>
                  e.id.equals(config.exerciseId) & e.deletedAt.isNull()))
            .getSingle();

        final sessionExercise = SessionExercise(
          id: newId(),
          sessionId: session.id,
          exerciseId: exercise.id,
          name: exercise.name,
          description: exercise.description,
          notes: exercise.notes,
          imagePath: exercise.imagePath,
          loggingType: exercise.loggingType,
          sortOrder: config.sortOrder,
          restSeconds: config.restSeconds,
          targetSets: config.targetSets,
          sessionNotes: null,
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
        );
        await _db.into(_db.sessionExercises).insert(sessionExercise);

        for (var i = 0; i < config.targetSets; i++) {
          await _db.into(_db.sessionSets).insert(SessionSet(
                id: newId(),
                sessionExerciseId: sessionExercise.id,
                setIndex: i,
                weight: null,
                reps: null,
                rir: config.defaultRir,
                durationSeconds: config.defaultDurationSeconds,
                completedAt: null,
                createdAt: now,
                updatedAt: now,
                deletedAt: null,
              ));
        }
      }

      return session;
    });
  }

  Future<ActiveSession?> _fetchSession(String id) async {
    final session = await (_db.select(_db.workoutSessions)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .getSingleOrNull();
    if (session == null) return null;
    return _buildActiveSession(session);
  }

  Future<ActiveSession> _buildActiveSession(WorkoutSession session) async {
    final exerciseRows = await (_db.select(_db.sessionExercises)
          ..where(
              (t) => t.sessionId.equals(session.id) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();

    final exercises = <SessionExerciseWithSets>[];
    for (final exercise in exerciseRows) {
      final sets = await (_db.select(_db.sessionSets)
            ..where((t) =>
                t.sessionExerciseId.equals(exercise.id) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
          .get();
      exercises.add(SessionExerciseWithSets(exercise: exercise, sets: sets));
    }

    return ActiveSession(session: session, exercises: exercises);
  }

  Future<ActiveSession?> _fetchActiveSession() async {
    final session = await (_db.select(_db.workoutSessions)
          ..where((t) =>
              t.deletedAt.isNull() &
              (t.status.equalsValue(SessionStatus.active) |
                  t.status.equalsValue(SessionStatus.paused)))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (session == null) return null;
    return _buildActiveSession(session);
  }

  Future<List<ActiveSession>> _fetchCompletedSessions() async {
    final rows = await (_db.select(_db.workoutSessions)
          ..where((t) =>
              t.status.equalsValue(SessionStatus.completed) &
              t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.endedAt)]))
        .get();

    final result = <ActiveSession>[];
    for (final row in rows) {
      result.add(await _buildActiveSession(row));
    }
    return result;
  }

  /// Watches `{workoutSessions, sessionExercises, sessionSets}` and re-runs
  /// [fetch] on every change. Hand-rolled with an explicit
  /// `StreamController`/`onCancel` rather than `async*` + `await for` over
  /// `db.tableUpdates` — that combination left `StreamSubscription.cancel()`
  /// hanging forever in this project (see `TemplateRepository.watchSummaries`).
  /// Emits are chained through [_pendingFetch] so rapid, overlapping table
  /// updates can't resolve out of order.
  Stream<T> _watchAggregate<T>(Future<T> Function() fetch) {
    late StreamController<T> controller;
    StreamSubscription<Set<TableUpdate>>? tableSub;
    var pendingFetch = Future<void>.value();

    void scheduleEmit() {
      // Caught explicitly and chained via `.catchError` (rather than left to
      // propagate) so a throwing `fetch()` can't leave `pendingFetch`
      // permanently errored — a bare `.then()` on an errored future skips
      // the success callback forever, silently killing every later emission
      // on this stream.
      pendingFetch = pendingFetch.then((_) async {
        if (controller.isClosed) return;
        final value = await fetch();
        if (!controller.isClosed) controller.add(value);
      }).catchError((Object error, StackTrace stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
        }
      });
    }

    controller = StreamController<T>(
      onListen: () {
        scheduleEmit();
        tableSub = _db.tableUpdates(TableUpdateQuery.onAllTables({
          _db.workoutSessions,
          _db.sessionExercises,
          _db.sessionSets,
        })).listen((_) => scheduleEmit());
      },
      onCancel: () async {
        await tableSub?.cancel();
      },
    );

    return controller.stream;
  }

  Stream<ActiveSession?> watchSession(String id) =>
      _watchAggregate(() => _fetchSession(id));

  Stream<ActiveSession?> watchActiveSession() =>
      _watchAggregate(_fetchActiveSession);

  Stream<List<ActiveSession>> watchCompletedSessions() =>
      _watchAggregate(_fetchCompletedSessions);

  Future<void> updateSet(SessionSet set) async {
    await _db.update(_db.sessionSets).replace(
          set.copyWith(updatedAt: DateTime.now()),
        );
  }

  Future<SessionSet> addSet(String sessionExerciseId) async {
    final existing = await (_db.select(_db.sessionSets)
          ..where((t) =>
              t.sessionExerciseId.equals(sessionExerciseId) &
              t.deletedAt.isNull()))
        .get();
    final nextIndex = existing.isEmpty
        ? 0
        : existing.map((s) => s.setIndex).reduce((a, b) => a > b ? a : b) + 1;

    final now = DateTime.now();
    final set = SessionSet(
      id: newId(),
      sessionExerciseId: sessionExerciseId,
      setIndex: nextIndex,
      weight: null,
      reps: null,
      rir: null,
      durationSeconds: null,
      completedAt: null,
      createdAt: now,
      updatedAt: now,
      deletedAt: null,
    );
    await _db.into(_db.sessionSets).insert(set);
    return set;
  }

  /// Removes [setId], unless it is the last remaining set of its exercise —
  /// PRD FR-101 constrains target sets to 1-20, so an exercise with zero sets
  /// was never intended and would desync [SessionExerciseWithSets.isComplete]
  /// from the session engine's next-target logic. A no-op in that case.
  Future<void> removeSet(String setId) async {
    await _db.transaction(() async {
      final set = await (_db.select(_db.sessionSets)
            ..where((t) => t.id.equals(setId)))
          .getSingleOrNull();
      if (set == null) return;

      final siblingCount = await (_db.select(_db.sessionSets)
            ..where((t) =>
                t.sessionExerciseId.equals(set.sessionExerciseId) &
                t.deletedAt.isNull()))
          .get()
          .then((rows) => rows.length);
      if (siblingCount <= 1) return;

      await (_db.delete(_db.sessionSets)..where((t) => t.id.equals(setId)))
          .go();

      final remaining = await (_db.select(_db.sessionSets)
            ..where((t) =>
                t.sessionExerciseId.equals(set.sessionExerciseId) &
                t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
          .get();

      for (var i = 0; i < remaining.length; i++) {
        await (_db.update(_db.sessionSets)
              ..where((t) => t.id.equals(remaining[i].id)))
            .write(SessionSetsCompanion(
          setIndex: Value(i),
          updatedAt: Value(DateTime.now()),
        ));
      }
    });
  }

  Future<void> updateSessionExercise(SessionExercise se) async {
    await _db.update(_db.sessionExercises).replace(
          se.copyWith(updatedAt: DateTime.now()),
        );
  }

  Future<void> updateSession(WorkoutSession session) async {
    await _db.update(_db.workoutSessions).replace(
          session.copyWith(updatedAt: DateTime.now()),
        );
  }

  Future<void> reorderSessionExercises(
    String sessionId,
    List<String> orderedIds,
  ) async {
    await _db.transaction(() async {
      final now = DateTime.now();
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.sessionExercises)
              ..where((t) =>
                  t.id.equals(orderedIds[i]) & t.sessionId.equals(sessionId)))
            .write(SessionExercisesCompanion(
          sortOrder: Value(i),
          updatedAt: Value(now),
        ));
      }
    });
  }

  Future<void> finishSession(String id, {String? notes}) async {
    final now = DateTime.now();
    await (_db.update(_db.workoutSessions)..where((t) => t.id.equals(id)))
        .write(WorkoutSessionsCompanion(
      status: const Value(SessionStatus.completed),
      endedAt: Value(now),
      notes: Value(notes),
      updatedAt: Value(now),
      restStatus: const Value(RestTimerStatus.idle),
      restEndsAt: const Value(null),
      restRemainingSeconds: const Value(null),
      restTotalSeconds: const Value(null),
      restAfterSetId: const Value(null),
    ));
  }

  Future<void> cancelSession(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.workoutSessions)..where((t) => t.id.equals(id)))
        .write(WorkoutSessionsCompanion(
      status: const Value(SessionStatus.cancelled),
      endedAt: Value(now),
      updatedAt: Value(now),
      restStatus: const Value(RestTimerStatus.idle),
      restEndsAt: const Value(null),
      restRemainingSeconds: const Value(null),
      restTotalSeconds: const Value(null),
      restAfterSetId: const Value(null),
    ));
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);

final activeSessionProvider = StreamProvider<ActiveSession?>(
  (ref) => ref.watch(sessionRepositoryProvider).watchActiveSession(),
);
