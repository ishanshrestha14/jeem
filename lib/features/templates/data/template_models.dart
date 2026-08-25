import '../../../core/utils/formatting.dart';
import '../../../db/app_database.dart';

class TemplateExerciseWithExercise {
  const TemplateExerciseWithExercise({
    required this.config,
    required this.exercise,
    this.sets = const [],
  });

  final TemplateExercise config;
  final Exercise exercise;

  /// The planned sets, in order. Since schema v6 this *is* the prescription —
  /// how many, and what each one asks for.
  final List<TemplateSet> sets;

  String get name => exercise.name;
  bool get isArchived => exercise.isArchived;
  LoggingType get loggingType => exercise.loggingType;

  /// Replaces the old `TemplateExercises.targetSets` column: the number of
  /// planned sets is simply how many rows there are, so the two can never
  /// disagree.
  int get targetSets => sets.length;

  /// True when at least one set carries numbers — drives the routine editor's
  /// "Press to add details" affordance (S-028).
  bool get hasPrescription => sets.any(
        (s) => s.weight != null || s.reps != null || s.durationSeconds != null,
      );
}

/// Formats one planned set the way the collapsed routine row reads it:
/// `70kg x 8 reps`, `8-10 reps`, `45s`, or null when nothing is planned yet.
String? describeTemplateSet(TemplateSet set, {String unit = 'kg'}) {
  if (set.durationSeconds != null) return '${set.durationSeconds}s';
  final reps = set.reps;
  final repsMax = set.repsMax;
  final weight = set.weight;
  final repsText = reps == null
      ? null
      : (repsMax == null ? '$reps reps' : '$reps-$repsMax reps');
  if (weight == null) return repsText;
  final weightText = weight == weight.roundToDouble()
      ? weight.toStringAsFixed(0)
      : weight.toString();
  return repsText == null
      ? '$weightText$unit'
      : '$weightText$unit x $repsText';
}

class TemplateWithExercises {
  const TemplateWithExercises({
    required this.template,
    required this.exercises,
  });

  final WorkoutTemplate template;
  final List<TemplateExerciseWithExercise> exercises;

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.targetSets);

  bool get canStart => exercises.isNotEmpty;
}

class TemplateSummary {
  const TemplateSummary({
    required this.template,
    required this.exerciseCount,
    required this.totalSets,
    this.lastPerformedAt,
  });

  final WorkoutTemplate template;
  final int exerciseCount;
  final int totalSets;
  final DateTime? lastPerformedAt;
}

/// One exercise's whole prescription on a single line, the way the routine
/// detail screen (S-030) lists it: `3 sets · 6 reps · 60kg`.
///
/// Where the planned sets differ, each part shows its **span** —
/// `6-10 reps`, `60-80kg` — rather than the word "varied". The numbers are
/// the reason you are reading the row: a routine that ramps 60 to 80kg should
/// say so before you start it.
///
/// Parts with nothing planned are dropped, so a routine with no prescription
/// yet is honestly just its set count. Duration-logged exercises show seconds
/// in place of reps and weight.
///
/// Distinct from [describeTemplateSet], which describes *one* set for the
/// editor's collapsed row.
String describeTemplateExercise(
  TemplateExerciseWithExercise te, {
  String unit = 'kg',
}) {
  final sets = te.sets;
  if (sets.isEmpty) return 'No sets';

  final parts = <String>['${sets.length} ${sets.length == 1 ? 'set' : 'sets'}'];

  if (te.loggingType == LoggingType.durationOnly) {
    final durations = [
      for (final s in sets)
        if (s.durationSeconds != null) s.durationSeconds!,
    ];
    if (durations.isNotEmpty) {
      parts.add(_span(
        durations.reduce((a, b) => a < b ? a : b),
        durations.reduce((a, b) => a > b ? a : b),
        formatDurationSeconds,
      ));
    }
    return parts.join(' · ');
  }

  // Both bounds of a set's own range widen the span, so a single set planned
  // as 6-8 reads `6-8 reps` exactly as two sets of 6 and 8 would.
  final reps = <int>[
    for (final s in sets) ...[
      if (s.reps != null) s.reps!,
      if (s.repsMax != null) s.repsMax!,
    ],
  ];
  if (reps.isNotEmpty) {
    final lo = reps.reduce((a, b) => a < b ? a : b);
    final hi = reps.reduce((a, b) => a > b ? a : b);
    parts.add('${_span(lo, hi, (v) => '$v')} reps');
  }

  final weights = [
    for (final s in sets)
      if (s.weight != null) s.weight!,
  ];
  if (weights.isNotEmpty) {
    final lo = weights.reduce((a, b) => a < b ? a : b);
    final hi = weights.reduce((a, b) => a > b ? a : b);
    parts.add('${_span(lo, hi, formatWeight)}$unit');
  }

  return parts.join(' · ');
}

/// `60` when the bounds agree, `60-80` when they do not.
String _span<T>(T lo, T hi, String Function(T) format) =>
    lo == hi ? format(lo) : '${format(lo)}-${format(hi)}';
