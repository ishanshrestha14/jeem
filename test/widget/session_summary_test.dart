import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/sessions/ui/session_summary_screen.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/test_database.dart';
import '../session_feedback_fakes.dart';
import 'pump_helpers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // The summary's content (stat grid + two exercises' worth of set lines)
  // is taller than the default 800x600 test surface, so a plain ListView
  // (not lazily built beyond the viewport) never builds the second
  // exercise's widgets at all — `find.text` then reports 0 matches for
  // content that exists in the model but was never built. Enlarge the
  // surface instead of scrolling, matching the pattern already used in
  // exercise_editor_image_test.dart for the same reason.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget harness(String sessionId, {bool readOnly = false}) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ...sessionFeedbackOverrides(),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: SessionSummaryScreen(sessionId: sessionId, readOnly: readOnly),
      ),
    );
  }

  /// Seeds a session with two strength exercises (3 target sets each — 6
  /// total) and completes one set on each: 80kg x 8 on the first, 80kg x 6
  /// on the second. 2/6 sets complete, volume 80*8 + 80*6 = 1120.
  ///
  /// Runs entirely inside [WidgetTester.runAsync]: `SessionRepository`'s
  /// `watchSession(id).first` needs a real event-loop turn for its
  /// hand-rolled stream's cancel to settle, which the ambient
  /// `AutomatedTestWidgetsFlutterBinding` fake clock never provides on its
  /// own — see the doc comment on `pumpUntilSessionData` in
  /// `active_session_test.dart` for the full mechanism (confirmed there by
  /// direct reproduction: this exact `.first` shape hangs indefinitely
  /// under plain `tester.pump()`, even across 300 pumps, unless run inside
  /// `runAsync`).
  Future<String> seedPartialSession(WidgetTester tester) async {
    return (await tester.runAsync(() async {
      final templates = TemplateRepository(db);
      final exercises = ExerciseRepository(db);
      final sessions = SessionRepository(db);

      final t = await templates.createTemplate(name: 'Push Day');
      final bench = await exercises.create(
          name: 'Bench Press',
          loggingType: LoggingType.strengthWeightRepsRir);
      final ohp = await exercises.create(
          name: 'Overhead Press',
          loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(
          templateId: t.id, exerciseId: bench.id, targetSets: 3);
      await templates.addExercise(
          templateId: t.id, exerciseId: ohp.id, targetSets: 3);

      final session = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
      final active = await sessions.watchSession(session.id).first;
      final benchExercise = active!.exercises
          .firstWhere((e) => e.exercise.name == 'Bench Press');
      final ohpExercise = active.exercises
          .firstWhere((e) => e.exercise.name == 'Overhead Press');

      await sessions.updateSet(benchExercise.sets.first.copyWith(
        weight: const Value(80),
        reps: const Value(8),
        completedAt: Value(DateTime.now()),
      ));
      await sessions.updateSet(ohpExercise.sets.first.copyWith(
        weight: const Value(80),
        reps: const Value(6),
        completedAt: Value(DateTime.now()),
      ));

      return session.id;
    }))!;
  }

  testWidgets('summary reports duration, sets, exercises and volume',
      (tester) async {
    final sessionId = await seedPartialSession(tester);

    await tester.pumpWidget(harness(sessionId));
    await pumpUntilData(tester, until: find.text('2 / 6 sets'));

    expect(find.text('2 / 6 sets'), findsOneWidget);
    expect(find.textContaining('1120 kg'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('per-exercise breakdown shows completed and incomplete sets',
      (tester) async {
    useTallSurface(tester);
    final sessionId = await seedPartialSession(tester);

    await tester.pumpWidget(harness(sessionId));
    await pumpUntilData(tester, until: find.text('2 / 6 sets'));

    expect(find.text('Set 1 · 80 kg × 8 · RIR —'), findsOneWidget);
    expect(find.text('Set 1 · 80 kg × 6 · RIR —'), findsOneWidget);

    // The remaining 4 target sets are still incomplete.
    expect(find.text('Set 2 · —'), findsNWidgets(2));
    expect(find.text('Set 3 · —'), findsNWidgets(2));

    await disposeAndDrainTimers(tester);
  });

  testWidgets('Save and Discard are shown when not read-only', (tester) async {
    useTallSurface(tester);
    final sessionId = await seedPartialSession(tester);

    await tester.pumpWidget(harness(sessionId));
    await pumpUntilData(tester, until: find.text('2 / 6 sets'));

    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Discard'), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isTrue);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('Save and Discard are hidden in read-only mode', (tester) async {
    useTallSurface(tester);
    final sessionId = await seedPartialSession(tester);

    await tester.pumpWidget(harness(sessionId, readOnly: true));
    await pumpUntilData(tester, until: find.text('2 / 6 sets'));

    expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Discard'), findsNothing);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);

    await disposeAndDrainTimers(tester);
  });
}
