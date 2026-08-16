import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import '../db/test_database.dart';

/// See the doc comment above `pumpUntilSessionData` in
/// `active_session_test.dart` for the full reproduction evidence of why
/// this screen needs `tester.runAsync` rather than plain pumps or awaiting
/// the controller's own future. Reused verbatim.
Future<void> pumpUntilSessionData(
  WidgetTester tester, {
  int maxIterations = 50,
}) async {
  for (var i = 0; i < maxIterations; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() => db = testDatabase());
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget harness() {
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const ActiveSessionScreen(),
      ),
    );
  }

  Future<void> startSession(WidgetTester tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
      name: 'Bench Press',
      loggingType: LoggingType.strengthWeightRepsRir,
    );
    await templates.addExercise(
      templateId: t.id,
      exerciseId: bench.id,
      targetSets: 2,
      restSeconds: 90,
    );
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session settings'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the persisted auto-focus switches and weight unit',
      (tester) async {
    await startSession(tester);
    await openSheet(tester);

    expect(find.byKey(const Key('autoFocusNextSetSwitch')), findsOneWidget);
    expect(
        find.byKey(const Key('autoFocusNextExerciseSwitch')), findsOneWidget);
    // Defaults come from the template (Task 9), which defaults to true.
    final setSwitch = tester
        .widget<Switch>(find.byKey(const Key('autoFocusNextSetSwitch')));
    expect(setSwitch.value, isTrue);
    expect(find.text('kg'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('toggling auto-focus next set persists immediately',
      (tester) async {
    await startSession(tester);
    await openSheet(tester);

    await tester.tap(find.byKey(const Key('autoFocusNextSetSwitch')));
    // The controller mutator reloads via the same `.first`-based DB round
    // trip documented on `pumpUntilSessionData` — give it a real event-loop
    // turn rather than relying on a synchronous pump.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    final state =
        await container.read(activeSessionControllerProvider.future);
    expect(state!.session.session.autoFocusNextSet, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'the notes debounce flushes on dispose even mid-window',
      (tester) async {
    await startSession(tester);
    await openSheet(tester);

    await tester.enterText(
        find.byKey(const Key('sessionNotesField')), 'Felt strong today');
    // Close the sheet immediately — well inside the 300ms debounce window —
    // by popping the route, exercising the dispose-time flush rather than
    // letting the debounce timer fire naturally. The modal bottom sheet's
    // own exit transition is a fixed 200ms
    // (`_bottomSheetExitDuration` in the framework), so pumping exactly
    // that long disposes the sheet's State comfortably before the 300ms
    // debounce would otherwise fire on its own — this has to stay strictly
    // under 300ms or the test would pass "by accident" even if the
    // dispose-time flush were deleted, since the natural timer would still
    // land in time.
    Navigator.of(tester.element(find.byKey(const Key('sessionNotesField'))))
        .pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    // Give the fired-on-dispose write a real event-loop turn to land, the
    // same way every other controller mutator needs one under the fake
    // clock in this suite.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    final state =
        await container.read(activeSessionControllerProvider.future);
    expect(state!.session.session.notes, 'Felt strong today');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
