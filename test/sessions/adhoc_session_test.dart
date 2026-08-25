import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/test_database.dart';
import '../session_feedback_fakes.dart';

/// T-012. A workout you did not plan should still be loggable, and a session
/// already underway should still accept an exercise you decide to do. Both are
/// the same missing capability: putting an exercise into a live session.
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

  Future<String> anExercise({
    String name = 'Bench Press',
    LoggingType type = LoggingType.strengthWeightRepsRir,
  }) async {
    final e = await ExerciseRepository(db).create(name: name, loggingType: type);
    return e.id;
  }

  Future<ActiveSessionState> state() async {
    final ActiveSessionState? value =
        await container.read(activeSessionControllerProvider.future);
    return value!;
  }

  Future<void> startAdHoc() async {
    await container
        .read(sessionRepositoryProvider)
        .startAdHoc(weightUnit: 'kg');
    container.listen(activeSessionControllerProvider, (_, _) {});
  }

  test('an ad-hoc session starts with no template and no exercises', () async {
    final session = await container
        .read(sessionRepositoryProvider)
        .startAdHoc(weightUnit: 'kg');

    expect(session.templateId, isNull);
    expect(session.name, 'Workout');
    expect(session.status, SessionStatus.active);
    expect((await state()).session.exercises, isEmpty);
  });

  test('adding the first exercise gives it one empty set', () async {
    await startAdHoc();
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.addExercise(await anExercise());

    final entry = (await state()).session.exercises.single;
    expect(entry.exercise.name, 'Bench Press');
    expect(entry.sets, hasLength(1));
    expect(entry.sets.single.weight, isNull);
    expect(entry.sets.single.completedAt, isNull);
  });

  test('the first exercise added becomes the current target', () async {
    await startAdHoc();
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.addExercise(await anExercise());

    final s = await state();
    // Without this the session sits with nothing focused and the keypad has
    // no set to write into — logbable only after a manual tap.
    expect(s.currentTarget, isNotNull);
    expect(s.currentTarget!.setId, s.session.exercises.single.sets.single.id);
  });

  test('a second exercise is appended, never inserted', () async {
    await startAdHoc();
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.addExercise(await anExercise(name: 'Bench Press'));
    await controller.addExercise(await anExercise(name: 'Barbell Row'));

    final names =
        (await state()).session.exercises.map((e) => e.exercise.name).toList();
    expect(names, ['Bench Press', 'Barbell Row']);
  });

  test('an exercise can be added to a session started from a routine',
      () async {
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    await templates.addExercise(
        templateId: t.id, exerciseId: await anExercise(name: 'Press'));
    await container
        .read(sessionRepositoryProvider)
        .startFromTemplate(t.id, weightUnit: 'kg');
    container.listen(activeSessionControllerProvider, (_, _) {});
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller.addExercise(await anExercise(name: 'Fly'));

    final names =
        (await state()).session.exercises.map((e) => e.exercise.name).toList();
    expect(names, ['Press', 'Fly']);
  });

  test('a duration exercise arrives with a duration set, not weight and reps',
      () async {
    await startAdHoc();
    final controller = container.read(activeSessionControllerProvider.notifier);

    await controller
        .addExercise(await anExercise(name: 'Plank', type: LoggingType.durationOnly));

    final entry = (await state()).session.exercises.single;
    expect(entry.exercise.loggingType, LoggingType.durationOnly);
    expect(entry.sets, hasLength(1));
  });

  test('a completed session accepts another exercise and is in progress again',
      () async {
    await startAdHoc();
    final controller = container.read(activeSessionControllerProvider.notifier);
    await controller.addExercise(await anExercise());
    await controller.completeSet(
        (await state()).session.exercises.single.sets.single.id);
    expect((await state()).session.exercises.single.isComplete, isTrue);

    await controller.addExercise(await anExercise(name: 'Barbell Row'));

    final s = await state();
    expect(s.session.completedSets, 1);
    expect(s.session.totalSets, 2);
    expect(s.currentTarget, isNotNull,
        reason: 'the newly added exercise is what to do next');
  });
}
