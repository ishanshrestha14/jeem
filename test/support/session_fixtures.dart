import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/data/session_models.dart';

var _seq = 0;

/// A completed session holding one exercise, whose sets are `(weight, reps)`
/// pairs, logged in [unit].
///
/// The existing per-file helpers hard-code `weightUnit: 'kg'`, which is exactly
/// the axis T-026 needs to vary, so this lives in `test/support/` and is shared
/// rather than copied a third time.
ActiveSession completedSession({
  required String unit,
  required List<(double, int)> sets,
  DateTime? endedAt,
  String exerciseId = 'ex-1',
  String exerciseName = 'Bench Press',
  LoggingType loggingType = LoggingType.strengthWeightRepsRir,
}) {
  final now = endedAt ?? DateTime.utc(2026, 8, 20);
  final sessionId = 'session-${_seq++}';

  final sessionSets = [
    for (final (weight, reps) in sets)
      SessionSet(
        id: 'set-${_seq++}',
        sessionExerciseId: 'se-$sessionId',
        setIndex: 0,
        weight: weight,
        reps: reps,
        rir: null,
        durationSeconds: null,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
      ),
  ];

  return ActiveSession(
    session: WorkoutSession(
      id: sessionId,
      templateId: null,
      name: 'Session',
      weightUnit: unit,
      status: SessionStatus.completed,
      autoFocusNextSet: true,
      autoFocusNextExercise: true,
      startedAt: now,
      endedAt: now,
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
    ),
    exercises: [
      SessionExerciseWithSets(
        exercise: SessionExercise(
          id: 'se-$sessionId',
          sessionId: sessionId,
          exerciseId: exerciseId,
          name: exerciseName,
          description: null,
          notes: null,
          imagePath: null,
          loggingType: loggingType,
          sortOrder: 0,
          restSeconds: 90,
          targetSets: sets.length,
          sessionNotes: null,
          createdAt: now,
          updatedAt: now,
          deletedAt: null,
        ),
        sets: sessionSets,
      ),
    ],
  );
}
