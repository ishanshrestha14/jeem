import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ids.dart';
import '../../../db/app_database.dart';
import '../domain/rest_timer.dart';
import '../domain/session_engine.dart';
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
  /// Starts a session with no routine behind it and nothing in it yet —
  /// S-006's ad-hoc empty session. Exercises arrive through
  /// [addExerciseToSession] as the workout is discovered.
  ///
  /// Named `Workout` rather than date-stamped: every surface that lists a
  /// session already shows its timestamp beside the name, so a date here
  /// would say the same thing twice. The name is editable in session
  /// settings.
  Future<WorkoutSession> startAdHoc({required String weightUnit}) async {
    final now = DateTime.now();
    final session = WorkoutSession(
      id: newId(),
      templateId: null,
      name: 'Workout',
      weightUnit: weightUnit,
      status: SessionStatus.active,
      // No routine to inherit these from, so take the same defaults a fresh
      // routine carries.
      autoFocusNextSet: true,
      autoFocusNextExercise: true,
      startedAt: now,
      endedAt: null,
      pausedSeconds: 0,
      pausedAt: null,
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
    return session;
  }

  /// Appends [exerciseId] to a live session with a single empty set (CMP-004).
  ///
  /// **Appended, never inserted**: adding an exercise mid-session must not
  /// reorder what you are in the middle of.
  ///
  /// One set, not the three a routine defaults to — you add an exercise
  /// because you are about to do it, and how many sets it takes is discovered
  /// as you go. It carries no prescription because nothing planned it: the
  /// `planned*` columns stay null and the row's plan hint (T-008) shows
  /// nothing, which is the truth.
  Future<void> addExerciseToSession({
    required String sessionId,
    required String exerciseId,
  }) async {
    await _db.transaction(() async {
      final exercise = await (_db.select(_db.exercises)
            ..where((e) => e.id.equals(exerciseId) & e.deletedAt.isNull()))
          .getSingle();

      final existing = await (_db.select(_db.sessionExercises)
            ..where((t) =>
                t.sessionId.equals(sessionId) & t.deletedAt.isNull()))
          .get();
      final sortOrder = existing.isEmpty
          ? 0
          : existing.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

      final now = DateTime.now();
      final sessionExercise = SessionExercise(
        id: newId(),
        sessionId: sessionId,
        exerciseId: exercise.id,
        name: exercise.name,
        description: exercise.description,
        notes: exercise.notes,
        imagePath: exercise.imagePath,
        loggingType: exercise.loggingType,
        sortOrder: sortOrder,
        // 90s — the same default `TemplateRepository.addExercise` gives an
        // exercise with no rest of its own. Adjustable per exercise from the
        // rest chip once it is in the session.
        restSeconds: 90,
        targetSets: 1,
        sessionNotes: null,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      );
      await _db.into(_db.sessionExercises).insert(sessionExercise);
      await _db.into(_db.sessionSets).insert(SessionSet(
            id: newId(),
            sessionExerciseId: sessionExercise.id,
            setIndex: 0,
            plannedWeight: null,
            plannedReps: null,
            plannedRepsMax: null,
            weight: null,
            reps: null,
            rir: null,
            durationSeconds: null,
            completedAt: null,
            createdAt: now,
            updatedAt: now,
            deletedAt: null,
          ));
    });
  }

  /// Thrown by [startFromTemplate] when the routine is gone.
  ///
  /// `TemplateRepository.deleteTemplate` is a **hard** delete, so a routine can
  /// vanish between being listed and being started — from a stale list, or a
  /// detail screen left open while it is deleted elsewhere. Callers need
  /// something they can catch and explain; drift's bare
  /// `StateError: No element` is not an explanation.
  Future<WorkoutSession> startFromTemplate(
    String templateId, {
    required String weightUnit,
  }) {
    return _db.transaction(() async {
      final template = await (_db.select(_db.workoutTemplates)
            ..where((t) => t.id.equals(templateId) & t.deletedAt.isNull()))
          .getSingleOrNull();
      if (template == null) throw RoutineNotFound(templateId);

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
        pausedAt: null,
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

        final plannedSets = await (_db.select(_db.templateSets)
              ..where((t) =>
                  t.templateExerciseId.equals(config.id) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm(expression: t.setIndex)]))
            .get();

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
          targetSets: plannedSets.length,
          sessionNotes: null,
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
        );
        await _db.into(_db.sessionExercises).insert(sessionExercise);

        for (final planned in plannedSets) {
          await _db.into(_db.sessionSets).insert(SessionSet(
                id: newId(),
                sessionExerciseId: sessionExercise.id,
                setIndex: planned.setIndex,
                // The plan, copied so the session is a true snapshot: editing
                // the routine afterwards must not rewrite what a past session
                // was asked to do.
                plannedWeight: planned.weight,
                plannedReps: planned.reps,
                plannedRepsMax: planned.repsMax,
                // Logged values start empty — the plan is a suggestion, not a
                // record of having done it.
                weight: null,
                reps: null,
                rir: planned.rir,
                durationSeconds: planned.durationSeconds,
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

  Future<void> saveRestState(String sessionId, RestTimerState rest) async {
    await (_db.update(_db.workoutSessions)..where((t) => t.id.equals(sessionId)))
        .write(WorkoutSessionsCompanion(
      restStatus: Value(rest.status),
      restEndsAt: Value(rest.endsAt),
      restRemainingSeconds: Value(rest.remainingSeconds),
      restTotalSeconds: Value(rest.totalSeconds),
      restAfterSetId: Value(rest.afterSetId),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Rehydrates persisted rest columns into a [RestTimerState]. `nextTarget`
  /// is not a DB column — it is recomputed from `restAfterSetId` via
  /// [nextTargetAfter] since the session's set order may have changed.
  RestTimerState restStateFrom(ActiveSession s) {
    final row = s.session;
    if (row.restStatus == RestTimerStatus.idle) return const RestTimerState.idle();
    return RestTimerState(
      status: row.restStatus,
      totalSeconds: row.restTotalSeconds ?? 0,
      endsAt: row.restEndsAt,
      remainingSeconds: row.restRemainingSeconds,
      afterSetId: row.restAfterSetId,
      nextTarget: row.restAfterSetId == null
          ? null
          : nextTargetAfter(s, row.restAfterSetId!),
    );
  }

  /// Removes a logged workout from the app.
  ///
  /// A **soft** delete: the row keeps its sets and is merely stamped
  /// `deletedAt`. (Not universal here — `deleteTemplate` and `removeSet` are
  /// hard deletes. Soft is right for a session because it is the only record
  /// that a workout happened.)
  /// and is merely stamped `deletedAt`. Because `_fetchCompletedSessions`
  /// filters on that column, one write takes the workout out of history, the
  /// week strips, `Previous` (T-009) and the personal-record pass at once —
  /// all of which are derived from completed sessions rather than stored.
  ///
  /// That means deleting a workout can *change your records*: if this session
  /// held your best lift, the record hands back to the next best. Correct, but
  /// invisible, which is why the confirmation says so.
  ///
  /// An unknown id is a no-op rather than an error — the caller is a menu on a
  /// row that may already have been deleted elsewhere.
  Future<void> deleteSession(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.workoutSessions)..where((t) => t.id.equals(id)))
        .write(WorkoutSessionsCompanion(
      deletedAt: Value(now),
      updatedAt: Value(now),
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

/// The routine a session was asked to start from no longer exists. See
/// [SessionRepository.startFromTemplate].
class RoutineNotFound implements Exception {
  const RoutineNotFound(this.templateId);

  final String templateId;

  @override
  String toString() => 'RoutineNotFound($templateId)';
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);

final activeSessionProvider = StreamProvider<ActiveSession?>(
  (ref) => ref.watch(sessionRepositoryProvider).watchActiveSession(),
);

/// Watches a single session by id — used by [SessionSummaryScreen] both live
/// (the just-finished-or-not-yet-finished session, still `active`) and
/// read-only (a completed row from history, Task 20).
final sessionByIdProvider = StreamProvider.autoDispose.family<ActiveSession?, String>(
  (ref, id) => ref.watch(sessionRepositoryProvider).watchSession(id),
);
