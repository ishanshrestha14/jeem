import '../../../db/app_database.dart';
import '../data/template_models.dart';

/// T-025 — the two stats the routine detail's tile (S-030) has been missing
/// since T-011: how long a routine takes, and what it hits.
///
/// Pure on purpose. The rule is the interesting part of this ticket and it
/// should be readable, and testable, without a widget anywhere near it.

/// How long one set is assumed to take, excluding rest.
///
/// **This is the one invented number in T-025.** Nothing the app records
/// supports it — it is not measured, derived, or configurable. It survives
/// only because it is confined to routines that have never been performed:
/// the first time you run one, [resolveRoutineDuration] switches to real
/// measurement and this constant never appears again for that routine.
const workSecondsPerSet = 45;

/// The plan's own guess at how long [routine] takes.
///
/// Each planned set costs its work plus that exercise's rest, except the very
/// last set of the routine, which costs no rest — you leave rather than rest
/// after it.
Duration estimateFromPlan(TemplateWithExercises routine) {
  final rests = <int>[];
  var seconds = 0;

  for (final te in routine.exercises) {
    for (final set in te.sets) {
      // A duration-logged set states its own work; everything else is assumed
      // to take the constant above.
      seconds += te.loggingType == LoggingType.durationOnly
          ? (set.durationSeconds ?? workSecondsPerSet)
          : workSecondsPerSet;
      rests.add(te.config.restSeconds);
    }
  }

  // Collected and summed rather than subtracted afterwards, so "the last set
  // of the routine" needs no special case for an empty routine or for a
  // trailing exercise that has no sets.
  if (rests.isNotEmpty) rests.removeLast();

  return Duration(seconds: seconds + rests.fold(0, (a, b) => a + b));
}

/// A duration to show, and whether it came from real sessions.
///
/// The provenance is part of the answer rather than an internal detail: the
/// tile captions it `your average` or `estimated`, because a measured number
/// and a guessed one deserve different amounts of trust.
class RoutineDuration {
  const RoutineDuration({required this.value, required this.wasMeasured});

  final Duration value;
  final bool wasMeasured;
}

/// Measured beats estimated whenever there is anything measured at all —
/// even one session. One real run of a routine says more about what it costs
/// than any formula does.
///
/// Returns `null` when neither branch has anything honest to offer (a routine
/// never performed and with no sets planned): no column at all beats `~0 min`.
RoutineDuration? resolveRoutineDuration({
  required TemplateWithExercises plan,
  required List<Duration> measured,
}) {
  if (measured.isNotEmpty) {
    final total = measured.fold(Duration.zero, (a, b) => a + b);
    return RoutineDuration(
      value: Duration(microseconds: total.inMicroseconds ~/ measured.length),
      wasMeasured: true,
    );
  }

  final estimate = estimateFromPlan(plan);
  if (estimate == Duration.zero) return null;
  return RoutineDuration(value: estimate, wasMeasured: false);
}

/// `~52 min`. Both branches of [resolveRoutineDuration] render this way: the
/// tilde is what carries the imprecision, so neither has to round to a
/// false-looking multiple of five to signal that it is approximate.
///
/// Floors at one minute — a routine takes *some* time, and `~0 min` reads as
/// broken rather than as short.
String approximateMinutes(Duration d) {
  final minutes = (d.inSeconds / 60).round();
  return '~${minutes < 1 ? 1 : minutes} min';
}

/// The body parts a routine works, from [byExercise] — the bulk map the
/// library already streams for its rows and its filter (T-021).
///
/// Deduped and returned in **enum declaration order**, not alphabetical, so
/// one routine always reads the same way and two routines are comparable at a
/// glance. Untagged exercises contribute nothing rather than an empty label;
/// under ADR-006 that is the normal early state.
List<BodyPart> summariseBodyParts(
  TemplateWithExercises routine,
  Map<String, List<BodyPart>> byExercise,
) {
  final present = <BodyPart>{
    for (final te in routine.exercises)
      ...?byExercise[te.exercise.id],
  };
  return [
    for (final part in BodyPart.values)
      if (present.contains(part)) part,
  ];
}
