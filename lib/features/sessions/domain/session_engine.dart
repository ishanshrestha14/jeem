import '../../../db/app_database.dart';
import '../data/session_models.dart';

enum TargetKind { sameExercise, nextExercise }

class SessionTarget {
  const SessionTarget({
    required this.sessionExerciseId,
    required this.setId,
    required this.setIndex,
    required this.exerciseName,
    required this.kind,
  });

  final String sessionExerciseId;
  final String setId;
  final int setIndex;
  final String exerciseName;
  final TargetKind kind;

  String get label => '$exerciseName — Set ${setIndex + 1}';

  @override
  bool operator ==(Object other) =>
      other is SessionTarget &&
      other.setId == setId &&
      other.sessionExerciseId == sessionExerciseId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(setId, sessionExerciseId, kind);
}

SessionTarget _target(
  SessionExerciseWithSets exercise,
  SessionSet set,
  TargetKind kind,
) {
  return SessionTarget(
    sessionExerciseId: exercise.exercise.id,
    setId: set.id,
    setIndex: set.setIndex,
    exerciseName: exercise.exercise.name,
    kind: kind,
  );
}

/// The first incomplete set in current session order. This is the session's
/// "current set" unless the user has manually focused something else.
SessionTarget? firstPendingTarget(ActiveSession s) {
  for (final e in s.exercises) {
    final pending = e.firstPendingSet;
    if (pending != null) return _target(e, pending, TargetKind.sameExercise);
  }
  return null;
}

/// What comes after completing [completedSetId]: the next pending set in the
/// same exercise, else the first pending set of a later exercise in the
/// session's *current* order (PRD §10.1, §18.8).
SessionTarget? nextTargetAfter(ActiveSession s, String completedSetId) {
  final owner = s.exerciseOf(completedSetId);
  if (owner == null) return null;

  final ownerIndex =
      s.exercises.indexWhere((e) => e.exercise.id == owner.exercise.id);
  final completed = owner.sets.firstWhere((x) => x.id == completedSetId);

  // Order-independent: pick the smallest matching setIndex rather than the
  // first list entry, so this is correct even if [owner.sets] isn't sorted.
  SessionSet? nextInExercise;
  for (final set in owner.sets) {
    if (set.setIndex > completed.setIndex && set.completedAt == null) {
      if (nextInExercise == null || set.setIndex < nextInExercise.setIndex) {
        nextInExercise = set;
      }
    }
  }
  if (nextInExercise != null) {
    return _target(owner, nextInExercise, TargetKind.sameExercise);
  }

  for (var i = ownerIndex + 1; i < s.exercises.length; i++) {
    final pending = s.exercises[i].firstPendingSet;
    if (pending != null) {
      return _target(s.exercises[i], pending, TargetKind.nextExercise);
    }
  }
  return null;
}

bool isLastSetOfSession(ActiveSession s, String setId) =>
    nextTargetAfter(s, setId) == null;

/// Rest owed after completing [completedSetId] — always the rest configured on
/// the exercise that set belongs to, and zero when nothing follows (PRD §10.2).
int restSecondsAfter(ActiveSession s, String completedSetId) {
  if (isLastSetOfSession(s, completedSetId)) return 0;
  return s.exerciseOf(completedSetId)?.exercise.restSeconds ?? 0;
}

/// Exercises that still have at least one incomplete set, in session order.
List<SessionExerciseWithSets> pendingExercises(ActiveSession s) =>
    s.exercises.where((e) => !e.isComplete).toList();

List<String> _completedIds(ActiveSession s) =>
    s.exercises.where((e) => e.isComplete).map((e) => e.exercise.id).toList();

/// "Do later": send [sessionExerciseId] behind every other pending exercise.
/// Completed exercises stay locked at the front (PRD §11.3).
List<String> moveToEnd(ActiveSession s, String sessionExerciseId) {
  final pending =
      pendingExercises(s).map((e) => e.exercise.id).toList();
  if (!pending.remove(sessionExerciseId)) {
    return s.exercises.map((e) => e.exercise.id).toList();
  }
  return [..._completedIds(s), ...pending, sessionExerciseId];
}

/// Drag-reorder within the pending sublist. Indices are pending-relative, which
/// is what the UI's ReorderableListView reports since it only renders pending
/// exercises.
List<String> reorderPending(ActiveSession s, int oldIndex, int newIndex) {
  final pending = pendingExercises(s).map((e) => e.exercise.id).toList();
  if (oldIndex < 0 || oldIndex >= pending.length) {
    return s.exercises.map((e) => e.exercise.id).toList();
  }
  var target = newIndex;
  if (target > oldIndex) target -= 1;
  final moved = pending.removeAt(oldIndex);
  pending.insert(target.clamp(0, pending.length), moved);
  return [..._completedIds(s), ...pending];
}
