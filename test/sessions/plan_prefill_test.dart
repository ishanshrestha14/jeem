import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/test_database.dart';
import '../session_feedback_fakes.dart';

/// CMP-015. The plan snapshotted onto a session set is shown muted while the
/// row is pending; completing an untouched row materialises it into the
/// logged columns, so a set that goes to plan is one tap and no typing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider
            .overrideWithValue(RecordingNotificationService()),
        hapticsServiceProvider.overrideWithValue(RecordingHapticsService()),
        soundServiceProvider.overrideWithValue(RecordingSoundService()),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    db.close();
  });

  /// One exercise, one planned set carrying [weight] / [reps] / [repsMax],
  /// started as a live session. Rest is zero so completion never has to wait
  /// on a timer.
  Future<void> seedAndStart({
    double? weight,
    int? reps,
    int? repsMax,
  }) async {
    final exercises = ExerciseRepository(db);
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    final e = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    final te = await templates.addExercise(
        templateId: t.id, exerciseId: e.id, targetSets: 1, restSeconds: 0);
    final planned = (await templates.setsFor(te.id)).single;
    await templates.updateSet(planned.id,
        weight: Value(weight), reps: Value(reps), repsMax: Value(repsMax));
    await container
        .read(sessionRepositoryProvider)
        .startFromTemplate(t.id, weightUnit: 'kg');
    container.listen(activeSessionControllerProvider, (_, _) {});
  }

  Future<ActiveSessionState> state() async {
    final ActiveSessionState? value =
        await container.read(activeSessionControllerProvider.future);
    return value!;
  }

  Future<SessionSet> firstSet() async =>
      (await state()).session.exercises.first.sets.first;

  test('completing an untouched set logs the planned weight and reps',
      () async {
    await seedAndStart(weight: 60, reps: 8);
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.completeSet((await firstSet()).id);

    final logged = await firstSet();
    expect(logged.weight, 60);
    expect(logged.reps, 8);
  });

  test('a planned rep range logs its lower bound', () async {
    await seedAndStart(weight: 60, reps: 8, repsMax: 10);
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.completeSet((await firstSet()).id);

    expect((await firstSet()).reps, 8);
  });

  test('a value the user typed is never overwritten by the plan', () async {
    await seedAndStart(weight: 60, reps: 8);
    final controller = container.read(activeSessionControllerProvider.notifier);
    final id = (await firstSet()).id;

    await controller.updateSetValues(id, weight: 72.5, reps: 5);
    await controller.completeSet(id);

    final logged = await firstSet();
    expect(logged.weight, 72.5);
    expect(logged.reps, 5);
  });

  test('completing a set with no plan leaves the logged values empty',
      () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.completeSet((await firstSet()).id);

    final logged = await firstSet();
    expect(logged.weight, isNull);
    expect(logged.reps, isNull);
  });

  test('the plan itself is left untouched by completion', () async {
    await seedAndStart(weight: 60, reps: 8, repsMax: 10);
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.completeSet((await firstSet()).id);

    final logged = await firstSet();
    expect(logged.plannedWeight, 60);
    expect(logged.plannedReps, 8);
    expect(logged.plannedRepsMax, 10);
  });
}
