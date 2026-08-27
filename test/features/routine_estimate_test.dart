import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/templates/data/template_models.dart';
import 'package:gymflow/features/templates/domain/routine_estimate.dart';

/// T-025 — the two stats S-030 has been missing since T-011: how long a
/// routine takes, and what it hits.
///
/// The whole rule lives in pure functions so it can be read and tested
/// without pumping a widget. Which branch produced the duration is part of
/// the answer, not an implementation detail, because the screen says so out
/// loud (`your average` vs `estimated`).
void main() {
  var seq = 0;
  final now = DateTime.utc(2026, 8, 27);

  TemplateSet planned({int? durationSeconds}) => TemplateSet(
        id: 'ts-${seq++}',
        templateExerciseId: 'te-1',
        setIndex: seq,
        durationSeconds: durationSeconds,
        createdAt: now,
        updatedAt: now,
      );

  TemplateExerciseWithExercise exercise({
    required List<TemplateSet> sets,
    int restSeconds = 90,
    String id = 'e-1',
    LoggingType loggingType = LoggingType.strengthWeightRepsRir,
  }) {
    return TemplateExerciseWithExercise(
      config: TemplateExercise(
        id: 'te-$id',
        templateId: 't-1',
        exerciseId: id,
        sortOrder: 0,
        restSeconds: restSeconds,
        createdAt: now,
        updatedAt: now,
      ),
      exercise: Exercise(
        id: id,
        name: 'Exercise $id',
        loggingType: loggingType,
        isArchived: false,
        isFavourite: false,
        createdAt: now,
        updatedAt: now,
      ),
      sets: sets,
    );
  }

  TemplateWithExercises routine(List<TemplateExerciseWithExercise> exercises) =>
      TemplateWithExercises(
        template: WorkoutTemplate(
          id: 't-1',
          name: 'Push A',
          defaultRestSeconds: 90,
          autoFocusNextSet: true,
          autoFocusNextExercise: true,
          createdAt: now,
          updatedAt: now,
        ),
        exercises: exercises,
      );

  group('estimateFromPlan', () {
    test('charges each set its work plus its exercise rest', () {
      // 3 sets x 45s work = 135s, plus rest after the first two only.
      final estimate = estimateFromPlan(
        routine([
          exercise(sets: [planned(), planned(), planned()], restSeconds: 90),
        ]),
      );

      expect(estimate, const Duration(seconds: 135 + 180));
    });

    test('drops the rest after the last set of the whole routine', () {
      // Two exercises of one set each: the first still rests, the second
      // does not — you leave rather than rest after the final set.
      final estimate = estimateFromPlan(
        routine([
          exercise(sets: [planned()], restSeconds: 60, id: 'a'),
          exercise(sets: [planned()], restSeconds: 120, id: 'b'),
        ]),
      );

      expect(estimate, const Duration(seconds: 45 + 60 + 45));
    });

    test('uses a duration-logged set own seconds as its work', () {
      final estimate = estimateFromPlan(
        routine([
          exercise(
            sets: [planned(durationSeconds: 300)],
            restSeconds: 90,
            loggingType: LoggingType.durationOnly,
          ),
        ]),
      );

      expect(estimate, const Duration(seconds: 300));
    });

    test('falls back to the work constant when a set plans no seconds', () {
      final estimate = estimateFromPlan(
        routine([
          exercise(
            sets: [planned()],
            loggingType: LoggingType.durationOnly,
          ),
        ]),
      );

      expect(estimate, const Duration(seconds: 45));
    });

    test('is zero for a routine with no sets', () {
      expect(estimateFromPlan(routine([exercise(sets: [])])), Duration.zero);
      expect(estimateFromPlan(routine([])), Duration.zero);
    });
  });

  group('resolveRoutineDuration', () {
    final plan = routine([
      exercise(sets: [planned(), planned()], restSeconds: 90),
    ]);

    test('averages the measured sessions when there are any', () {
      final resolved = resolveRoutineDuration(
        plan: plan,
        measured: const [
          Duration(minutes: 50),
          Duration(minutes: 60),
          Duration(minutes: 55),
        ],
      );

      expect(resolved?.value, const Duration(minutes: 55));
      expect(resolved?.wasMeasured, isTrue);
    });

    test('prefers a single real session over the formula', () {
      final resolved = resolveRoutineDuration(
        plan: plan,
        measured: const [Duration(minutes: 47)],
      );

      expect(resolved?.value, const Duration(minutes: 47));
      expect(resolved?.wasMeasured, isTrue);
    });

    test('falls back to the plan when the routine was never performed', () {
      final resolved = resolveRoutineDuration(plan: plan, measured: const []);

      expect(resolved?.value, const Duration(seconds: 45 + 90 + 45));
      expect(resolved?.wasMeasured, isFalse);
    });

    test('is null when there is nothing honest to show', () {
      // No history and no sets: `~0 min` is worse than no column at all.
      final resolved = resolveRoutineDuration(
        plan: routine([exercise(sets: [])]),
        measured: const [],
      );

      expect(resolved, isNull);
    });
  });

  group('approximateMinutes', () {
    test('rounds to the nearest minute behind a tilde', () {
      // The `~` carries the imprecision, so neither branch has to round to a
      // false-looking multiple of five.
      expect(approximateMinutes(const Duration(minutes: 52)), '~52 min');
      expect(approximateMinutes(const Duration(seconds: 315)), '~5 min');
      expect(approximateMinutes(const Duration(seconds: 330)), '~6 min');
    });

    test('never reads as zero', () {
      // A short routine takes *some* time; `~0 min` reads as broken.
      expect(approximateMinutes(const Duration(seconds: 20)), '~1 min');
    });
  });

  group('summariseBodyParts', () {
    test('unions the exercises body parts, deduped, in enum order', () {
      final parts = summariseBodyParts(
        routine([
          exercise(sets: [planned()], id: 'a'),
          exercise(sets: [planned()], id: 'b'),
          exercise(sets: [planned()], id: 'c'),
        ]),
        const {
          'a': [BodyPart.arms, BodyPart.chest],
          'b': [BodyPart.chest],
          'c': [BodyPart.shoulders],
        },
      );

      expect(parts, [BodyPart.chest, BodyPart.shoulders, BodyPart.arms]);
    });

    test('is empty when no exercise is tagged', () {
      final parts = summariseBodyParts(
        routine([exercise(sets: [planned()], id: 'a')]),
        const {'a': []},
      );

      expect(parts, isEmpty);
    });

    test('ignores an exercise missing from the map entirely', () {
      final parts = summariseBodyParts(
        routine([
          exercise(sets: [planned()], id: 'a'),
          exercise(sets: [planned()], id: 'b'),
        ]),
        const {
          'b': [BodyPart.legs]
        },
      );

      expect(parts, [BodyPart.legs]);
    });
  });
}
