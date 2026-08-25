import '../../../core/utils/formatting.dart';
import '../../sessions/data/session_models.dart';

class WeeklySummary {
  const WeeklySummary({
    required this.workouts,
    required this.duration,
    required this.volume,
    required this.workoutsDelta,
    required this.durationDelta,
    required this.volumeDelta,
  });

  final int workouts;
  final Duration duration;
  final double volume;
  final int workoutsDelta;
  final Duration durationDelta;
  final double volumeDelta;
}

/// S-001's weekly summary: this week's workouts, time and volume, each with
/// its change against the week before (CMP-008 + CMP-013).
///
/// The week runs Sunday–Saturday via the shared [weekStart], the same
/// definition CMP-020's strip uses — two views of "this week" that disagreed
/// would be a bug nobody would spot.
///
/// A session belongs to the week it **ended** in, matching how the Workout tab
/// and history attribute one that ran past midnight.
///
/// Everything is zero rather than null with no history: the summary is a
/// scoreboard, and a scoreboard reading `0` is meaningful where a blank is not.
WeeklySummary weeklySummary(
  List<ActiveSession> completed, {
  required DateTime now,
}) {
  final thisWeek = weekStart(now);
  final lastWeek = thisWeek.subtract(const Duration(days: 7));

  var workouts = 0, priorWorkouts = 0;
  var duration = Duration.zero, priorDuration = Duration.zero;
  var volume = 0.0, priorVolume = 0.0;

  for (final s in completed) {
    final endedAt = s.session.endedAt ?? s.session.startedAt;
    final week = weekStart(endedAt);

    final isThisWeek = week == thisWeek;
    final isLastWeek = week == lastWeek;
    if (!isThisWeek && !isLastWeek) continue;

    final took = s.session.endedAt == null
        ? Duration.zero
        : s.session.endedAt!.difference(s.session.startedAt) -
            Duration(seconds: s.session.pausedSeconds);

    if (isThisWeek) {
      workouts++;
      duration += took;
      volume += s.completedVolume;
    } else {
      priorWorkouts++;
      priorDuration += took;
      priorVolume += s.completedVolume;
    }
  }

  return WeeklySummary(
    workouts: workouts,
    duration: duration,
    volume: volume,
    workoutsDelta: workouts - priorWorkouts,
    durationDelta: duration - priorDuration,
    volumeDelta: volume - priorVolume,
  );
}
