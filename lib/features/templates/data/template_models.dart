import '../../../db/app_database.dart';

class TemplateExerciseWithExercise {
  const TemplateExerciseWithExercise({
    required this.config,
    required this.exercise,
  });

  final TemplateExercise config;
  final Exercise exercise;

  String get name => exercise.name;
  bool get isArchived => exercise.isArchived;
  LoggingType get loggingType => exercise.loggingType;
}

class TemplateWithExercises {
  const TemplateWithExercises({
    required this.template,
    required this.exercises,
  });

  final WorkoutTemplate template;
  final List<TemplateExerciseWithExercise> exercises;

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.config.targetSets);

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
