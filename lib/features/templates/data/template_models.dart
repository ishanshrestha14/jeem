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
