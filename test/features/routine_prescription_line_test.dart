import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/templates/data/template_models.dart';

/// S-030's exercise row: one line per exercise, aggregated across its planned
/// sets — `3 sets · 6 reps · 60kg`. Where the sets differ the line shows the
/// span rather than the word "varied": a routine that ramps 60→80kg should
/// say so on the row you read before starting it.
void main() {
  var seq = 0;
  final now = DateTime.utc(2026, 8, 25);

  TemplateSet planned({
    double? weight,
    int? reps,
    int? repsMax,
    int? durationSeconds,
  }) {
    return TemplateSet(
      id: 'ts-${seq++}',
      templateExerciseId: 'te-1',
      setIndex: seq,
      weight: weight,
      reps: reps,
      repsMax: repsMax,
      durationSeconds: durationSeconds,
      createdAt: now,
      updatedAt: now,
    );
  }

  TemplateExerciseWithExercise exercise({
    required List<TemplateSet> sets,
    LoggingType loggingType = LoggingType.strengthWeightRepsRir,
  }) {
    return TemplateExerciseWithExercise(
      config: TemplateExercise(
        id: 'te-1',
        templateId: 't-1',
        exerciseId: 'e-1',
        sortOrder: 0,
        restSeconds: 90,
        createdAt: now,
        updatedAt: now,
      ),
      exercise: Exercise(
        id: 'e-1',
        name: 'Bench Press',
        loggingType: loggingType,
        isArchived: false,
        isFavourite: false,
        createdAt: now,
        updatedAt: now,
      ),
      sets: sets,
    );
  }

  String line(List<TemplateSet> sets, {LoggingType? type}) =>
      describeTemplateExercise(exercise(
        sets: sets,
        loggingType: type ?? LoggingType.strengthWeightRepsRir,
      ));

  test('uniform sets read as the screenshot does', () {
    expect(
      line([
        planned(weight: 60, reps: 6),
        planned(weight: 60, reps: 6),
        planned(weight: 60, reps: 6),
      ]),
      '3 sets · 6 reps · 60kg',
    );
  });

  test('a single set is not pluralised', () {
    expect(line([planned(weight: 60, reps: 6)]), '1 set · 6 reps · 60kg');
  });

  test('differing weights show the span', () {
    expect(
      line([planned(weight: 60, reps: 6), planned(weight: 80, reps: 6)]),
      '2 sets · 6 reps · 60-80kg',
    );
  });

  test('differing reps show the span', () {
    expect(
      line([planned(weight: 60, reps: 6), planned(weight: 60, reps: 10)]),
      '2 sets · 6-10 reps · 60kg',
    );
  });

  test("a set's own rep range widens the span", () {
    expect(
      line([planned(weight: 60, reps: 6, repsMax: 8)]),
      '1 set · 6-8 reps · 60kg',
    );
  });

  test('an unprescribed routine shows only its set count', () {
    expect(line([planned(), planned()]), '2 sets');
  });

  test('weight without reps omits the reps part', () {
    expect(line([planned(weight: 60)]), '1 set · 60kg');
  });

  test('reps without weight omits the weight part', () {
    expect(line([planned(reps: 12)]), '1 set · 12 reps');
  });

  test('duration work shows seconds instead of reps and weight', () {
    expect(
      line([planned(durationSeconds: 45), planned(durationSeconds: 45)],
          type: LoggingType.durationOnly),
      '2 sets · 45s',
    );
  });

  test('differing durations show the span', () {
    expect(
      line([planned(durationSeconds: 30), planned(durationSeconds: 60)],
          type: LoggingType.durationOnly),
      '2 sets · 30s-1:00',
    );
  });

  test('an exercise with no planned sets at all reads as none', () {
    expect(line([]), 'No sets');
  });

  test('a fractional weight is not rounded away', () {
    expect(line([planned(weight: 17.5, reps: 10)]), '1 set · 10 reps · 17.5kg');
  });
}
