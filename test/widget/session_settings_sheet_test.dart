import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/test_database.dart';
import '../session_feedback_fakes.dart';

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

  setUp(() {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget harness() {
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
        home: const ActiveSessionScreen(),
      ),
    );
  }

  /// [autoFocusNextSet] is set on the TEMPLATE before the session is created,
  /// so the session snapshot inherits it and the controller's one-shot
  /// `build()` picks it up. Writing the flag to the session row afterwards
  /// does NOT work: `ActiveSessionController.build()` is deliberately a
  /// one-shot fetch (it fixed a race where a stale rehydration reverted a
  /// completed rest to idle), so writes made outside the controller never
  /// reach its state and the sheet would still render the old value.
  Future<void> startSession(
    WidgetTester tester, {
    bool autoFocusNextSet = true,
  }) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    if (!autoFocusNextSet) {
      await templates
          .updateTemplate(t.copyWith(autoFocusNextSet: autoFocusNextSet));
    }
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

  /// Reads the persisted session row straight from the database.
  ///
  /// Do NOT assert persistence by awaiting
  /// `container.read(activeSessionControllerProvider.future)` — inside a
  /// `runAsync` block that hangs indefinitely, which is documented on
  /// `pumpUntilSessionData` in `active_session_test.dart` and is what hung
  /// this file. A direct select has no stream, no controller and no fake-clock
  /// interaction, and it proves the stronger thing anyway: that the write
  /// actually reached disk rather than only controller state.
  Future<WorkoutSession> readSessionRow() async =>
      (await db.select(db.workoutSessions).get()).single;

  /// Pumps a bounded number of frames — never `pumpAndSettle`.
  ///
  /// The active session screen sits behind this sheet and is backed by a Drift
  /// stream plus a 500ms rest ticker, so `pumpAndSettle` has nothing to settle
  /// to: it spins until its 10-minute default timeout and then fails. That is
  /// exactly what hung this file. 600ms of frames is well past any finite
  /// menu/sheet transition and is guaranteed to terminate.
  Future<void> pumpFiniteTransition(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await pumpFiniteTransition(tester);
    await tester.tap(find.text('Session settings'));
    await pumpFiniteTransition(tester);
  }

  testWidgets(
      'shows the persisted auto-focus switches and weight unit, bound to '
      'the session row rather than a hardcoded default', (tester) async {
    // A hardcoded `value: true` in the sheet would also satisfy an
    // all-defaults session, so start from a template whose flag is already
    // false. This only passes if the switch genuinely reads
    // `autoFocusNextSet` off the session rather than rendering a literal,
    // and it proves the whole chain: template -> session snapshot -> switch.
    await startSession(tester, autoFocusNextSet: false);
    expect((await readSessionRow()).autoFocusNextSet, isFalse);

    await openSheet(tester);

    expect(find.byKey(const Key('autoFocusNextSetSwitch')), findsOneWidget);
    expect(
        find.byKey(const Key('autoFocusNextExerciseSwitch')), findsOneWidget);
    final setSwitch = tester
        .widget<Switch>(find.byKey(const Key('autoFocusNextSetSwitch')));
    expect(setSwitch.value, isFalse);
    final exerciseSwitch = tester.widget<Switch>(
        find.byKey(const Key('autoFocusNextExerciseSwitch')));
    // Untouched — still the template default (true) — so this also proves
    // the two switches are bound independently rather than to one flag.
    expect(exerciseSwitch.value, isTrue);
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

    expect((await readSessionRow()).autoFocusNextSet, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'sound and haptics switches default ON and persist to '
      'shared_preferences independently of each other', (tester) async {
    await startSession(tester);
    await openSheet(tester);

    expect(find.byKey(const Key('soundOnRestCompleteSwitch')), findsOneWidget);
    expect(find.byKey(const Key('hapticsSwitch')), findsOneWidget);
    final soundSwitch = tester
        .widget<Switch>(find.byKey(const Key('soundOnRestCompleteSwitch')));
    final hapticsSwitch =
        tester.widget<Switch>(find.byKey(const Key('hapticsSwitch')));
    // A silent/unfelt rest timer defeats the point of Task 18, so an MVP
    // user who never opens this sheet must still get both by default.
    expect(soundSwitch.value, isTrue);
    expect(hapticsSwitch.value, isTrue);

    await tester.tap(find.byKey(const Key('soundOnRestCompleteSwitch')));
    // Same real event-loop turn as the auto-focus switch above — these
    // write through an `AsyncNotifier`'s own `shared_preferences` round
    // trip, not a synchronous pump.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(soundEnabledPrefsKey), isFalse);
    // Untouched — still true — proves the two switches persist
    // independently rather than sharing one flag.
    expect(prefs.getBool(hapticsEnabledPrefsKey), isNot(false));

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

    expect((await readSessionRow()).notes, 'Felt strong today');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
