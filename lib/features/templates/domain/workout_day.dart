import '../../sessions/data/session_models.dart';
import '../data/template_models.dart';

/// S-003's suggestions, ordered **least recently performed first**, with
/// never-performed routines leading.
///
/// The prompt worth showing is what you are neglecting. Ranking by recency
/// instead would keep re-suggesting whatever you just did, and a routine you
/// have never run is the most neglected of all — so `null` sorts before every
/// date rather than after it.
///
/// Returns a new list; the input is not mutated.
List<TemplateSummary> suggestedRoutines(List<TemplateSummary> all) {
  final out = [...all];
  out.sort((a, b) {
    final x = a.lastPerformedAt;
    final y = b.lastPerformedAt;
    if (x == null && y == null) return a.template.name.compareTo(b.template.name);
    if (x == null) return -1;
    if (y == null) return 1;
    return x.compareTo(y);
  });
  return out;
}

/// The completed sessions belonging to [day].
///
/// A session is attributed to the day it **ended**, not the day it started: a
/// workout begun at 11pm and finished at half past midnight is the new day's
/// workout, which is how history and the week strip already read it.
List<ActiveSession> sessionsOn(
  List<ActiveSession> completed, {
  required DateTime day,
}) {
  final target = DateTime(day.year, day.month, day.day);
  return [
    for (final s in completed)
      if (_dateOnly(s.session.endedAt ?? s.session.startedAt) == target) s,
  ];
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
