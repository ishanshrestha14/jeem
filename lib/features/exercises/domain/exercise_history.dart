import '../../../db/app_database.dart';
import '../../sessions/data/session_models.dart';

class ExerciseHistoryEntry {
  const ExerciseHistoryEntry({
    required this.when,
    required this.sessionName,
    required this.weightUnit,
    required this.sets,
  });

  final DateTime when;
  final String sessionName;
  final String weightUnit;
  final List<SessionSet> sets;
}

/// Every completed session that contained [exerciseKey], newest first, with
/// the sets actually logged in it — S-025's History pane.
///
/// [completed] must be newest-first, which `historyProvider` already is.
///
/// Keyed by `exerciseId ?? name`, the same convention as
/// `computePersonalRecords` and `previousBestByExercise`, so an ad-hoc or
/// since-deleted exercise still matches itself.
///
/// **Only completed sets are listed, and a session where none were completed
/// is omitted entirely.** A set you did not log is not something you did, and
/// a session where you skipped the exercise is not part of its history — it
/// would read as a blank row you would have to interpret.
List<ExerciseHistoryEntry> exerciseHistory(
  List<ActiveSession> completed, {
  required String exerciseKey,
}) {
  final out = <ExerciseHistoryEntry>[];

  for (final session in completed) {
    for (final entry in session.exercises) {
      final key = entry.exercise.exerciseId ?? entry.exercise.name;
      if (key != exerciseKey) continue;

      final logged = [
        for (final s in entry.sets)
          if (s.completedAt != null) s,
      ];
      if (logged.isEmpty) continue;

      out.add(ExerciseHistoryEntry(
        when: session.session.endedAt ?? session.session.startedAt,
        sessionName: session.session.name,
        weightUnit: session.session.weightUnit,
        sets: logged,
      ));
    }
  }

  return out;
}

/// Library exercise ids ordered by how recently they were actually performed,
/// most recent first, each appearing once.
///
/// S-026: when the picker opens **mid-session** its leading section is
/// `Recent Performed` rather than the alphabetical library — mid-set what you
/// want is almost always something you have done before, so recency beats
/// alphabetical.
///
/// [completed] must be newest-first, which `historyProvider` already is.
///
/// "Performed" means a set was actually logged, matching [exerciseHistory]: an
/// exercise you loaded into a session and skipped is not something you did.
/// A snapshot carrying no `exerciseId` is skipped, since the picker offers
/// library rows and there is no row for it to point at.
List<String> recentlyPerformedExerciseIds(List<ActiveSession> completed) {
  final seen = <String>{};
  final out = <String>[];

  for (final session in completed) {
    for (final entry in session.exercises) {
      final id = entry.exercise.exerciseId;
      if (id == null || seen.contains(id)) continue;
      if (!entry.sets.any((s) => s.completedAt != null)) continue;
      seen.add(id);
      out.add(id);
    }
  }

  return out;
}
