import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/theme/semantic_colors.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/sessions/ui/widgets/rest_bar.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/test_database.dart';
import '../session_feedback_fakes.dart';

/// See the doc comment above `pumpUntilSessionData` in
/// `active_session_test.dart` for the full reproduction evidence of why
/// this screen needs `tester.runAsync` rather than plain `pumpUntilData` or
/// awaiting the controller's own future. Reused verbatim, as that comment
/// directs for Tasks 14/15/16/19.
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

/// Parses the widget's own `mmss` display ("1:30") back into whole seconds.
int _displayedSeconds(WidgetTester tester, Key key) {
  final text = tester.widget<Text>(find.byKey(key)).data!;
  final parts = text.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
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

  /// `restTickerProvider` is a `StreamProvider.autoDispose` backed by an
  /// unbounded `while (true) { await Future.delayed(500ms); yield ...; }`
  /// generator. Once it has been watched at least once, unmounting the
  /// watching widget is not by itself enough to make its *currently
  /// pending* `Future.delayed` Timer go away — that Timer already exists in
  /// the fake-time zone and nothing retroactively cancels it merely by the
  /// widget disappearing. Confirmed by direct reproduction: tearing a
  /// harness down with only `pumpWidget(shrink) + pump()` (as
  /// `disposeAndDrainTimers` does for Drift's zero-duration cleanup Timer)
  /// left a `!timersPending` failure every time, even after several more
  /// 600ms pumps and even after `container.dispose()`. Explicitly
  /// invalidating the provider *and* pumping fake time past its 500ms
  /// period drains it deterministically, so this is used instead of (or in
  /// addition to) `disposeAndDrainTimers` in every test here that touched
  /// an active/paused rest.
  Future<void> disposeRestScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.invalidate(restTickerProvider);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Seeds a session with one exercise ("Bench Press", 2 target sets, 90s
  /// rest) and completes its first set, landing the screen with a running
  /// rest whose next target is "Bench Press — Set 2".
  Future<void> startRestingSession(WidgetTester tester) async {
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

    await tester.tap(find.byTooltip('Complete set').first);
    await pumpUntilSessionData(tester);
  }

  testWidgets('completing a set reveals the rest bar with the next target',
      (tester) async {
    await startRestingSession(tester);

    expect(find.byType(RestBar), findsOneWidget);
    // "NEXT" micro-label and the target label are now separate Text widgets
    // (design system: "NEXT as an 11px muted micro-label, then the label in
    // Barlow 15/400") rather than one concatenated "Next: ..." string.
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.text('Bench Press — Set 2'), findsOneWidget);
    // The DB round-trip in completeSet() consumes a little real wall-clock
    // time before this assertion runs, so the exact second can legitimately
    // read 90 or (rarely) one tick below it — assert a tight band around
    // 90s rather than a single hard-coded literal.
    final seconds =
        _displayedSeconds(tester, const Key('restCountdownText'));
    expect(seconds, inInclusiveRange(85, 90));

    await disposeRestScreen(tester);
  });

  testWidgets('+15s extends the countdown', (tester) async {
    await startRestingSession(tester);
    final before =
        _displayedSeconds(tester, const Key('restCountdownText'));

    await tester.tap(find.text('+15s'));
    await pumpUntilSessionData(tester);

    final after = _displayedSeconds(tester, const Key('restCountdownText'));
    // Assert the DISPLAYED time actually moved by ~15s, not merely that
    // adjustRest() was invoked. A generous tolerance absorbs the real
    // wall-clock drift documented above; it's nowhere near wide enough to
    // also pass a no-op or a -15s regression (see deletion check).
    expect(after - before, inInclusiveRange(10, 17));

    await disposeRestScreen(tester);
  });

  testWidgets('-15s shortens the countdown', (tester) async {
    await startRestingSession(tester);
    final before =
        _displayedSeconds(tester, const Key('restCountdownText'));

    await tester.tap(find.text('-15s'));
    await pumpUntilSessionData(tester);

    final after = _displayedSeconds(tester, const Key('restCountdownText'));
    expect(before - after, inInclusiveRange(13, 20));

    await disposeRestScreen(tester);
  });

  testWidgets(
      'skip ends rest and replaces the bar with the rest-complete banner',
      (tester) async {
    await startRestingSession(tester);
    // Auto-focus defaults to on (Task 15) and would otherwise consume the
    // finished state instantly, moving focus and dismissing the bar before
    // this test can observe the banner it's asserting on. Fired inside
    // `runAsync` and settled via `pumpUntilSessionData` for the same reason
    // documented on that helper: this mutator's DB reload needs a real
    // event-loop turn that plain pumps under the fake clock never provide.
    unawaited(container
        .read(activeSessionControllerProvider.notifier)
        .setAutoFocusNextSet(false));
    await pumpUntilSessionData(tester);

    await tester.tap(find.byIcon(Icons.skip_next));
    await pumpUntilSessionData(tester);

    // The running countdown/progress UI is gone...
    expect(find.byKey(const Key('restCountdownText')), findsNothing);
    expect(find.byIcon(Icons.skip_next), findsNothing);
    // ...replaced by the finished banner (PRD FR-108/109): still inside
    // RestBar (restJustFinished keeps the bar mounted), not hidden outright.
    expect(find.byType(RestBar), findsOneWidget);
    // Design system: the finished state's micro-label is "REST COMPLETE"
    // (uppercase, 11px letterspaced), not the old sentence-case "Rest
    // complete".
    expect(find.text('REST COMPLETE'), findsOneWidget);
    expect(find.text('Next set'), findsOneWidget);

    await disposeRestScreen(tester);
  });

  testWidgets(
      'tapping "Next set" on the finished banner focuses the target and '
      'hides the bar', (tester) async {
    await startRestingSession(tester);
    // Same reasoning as the previous test: turn off auto-focus so the
    // finished banner actually renders for this test to tap through.
    unawaited(container
        .read(activeSessionControllerProvider.notifier)
        .setAutoFocusNextSet(false));
    await pumpUntilSessionData(tester);
    await tester.tap(find.byIcon(Icons.skip_next));
    await pumpUntilSessionData(tester);
    expect(find.byType(RestBar), findsOneWidget);

    // Rest stopped being active (and so stopped being watched) the moment
    // it finished above — drain the ticker's pending timer here, while
    // still close to that transition, rather than only at teardown.
    container.invalidate(restTickerProvider);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }

    await tester.tap(find.text('Next set'));
    await pumpUntilSessionData(tester);

    expect(find.byType(RestBar), findsNothing);

    await disposeRestScreen(tester);
  });

  testWidgets('pausing shows the paused colour and freezes the countdown',
      (tester) async {
    await startRestingSession(tester);

    await tester.tap(find.byIcon(Icons.pause));
    await pumpUntilSessionData(tester);

    final frozen =
        _displayedSeconds(tester, const Key('restCountdownText'));
    final colors = AppTheme.dark().extension<SemanticColors>()!;
    final textWidget =
        tester.widget<Text>(find.byKey(const Key('restCountdownText')));
    expect(textWidget.style?.color, colors.warning);

    // Advance fake time well past a couple of 500ms ticks — a genuinely
    // paused timer must not have moved even though the ticker (which still
    // runs while paused, per design) keeps forcing rebuilds.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));

    final after =
        _displayedSeconds(tester, const Key('restCountdownText'));
    expect(after, frozen);

    await disposeRestScreen(tester);
  });

  testWidgets('tapping the bar opens the expanded sheet', (tester) async {
    await startRestingSession(tester);

    await tester.tap(find.byType(RestBar));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // The sheet's own 240px ring (a `CustomPaint`, not a
    // `CircularProgressIndicator` — design system), plus the "Undo last
    // set" control that isn't present on the compact bar.
    expect(find.byKey(const Key('restRing')), findsOneWidget);
    expect(find.text('Undo last set'), findsOneWidget);
    expect(find.text('Cancel rest'), findsOneWidget);

    await disposeRestScreen(tester);
  });

  testWidgets('"Undo last set" in the sheet uncompletes the set and cancels '
      'rest', (tester) async {
    await startRestingSession(tester);

    await tester.tap(find.byType(RestBar));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Undo last set'));
    await pumpUntilSessionData(tester);

    // Rest was anchored on the undone set, so it's cancelled outright, and
    // the bar disappears.
    expect(find.byType(RestBar), findsNothing);
    // No set is marked complete any more — the done control's tooltip
    // flips back to "Complete set" (its completed-state tooltip is "Mark
    // incomplete"; see StrengthSetRow/DurationSetRow).
    expect(find.byTooltip('Mark incomplete'), findsNothing);

    await disposeRestScreen(tester);
  });

  testWidgets(
      'tapping "Next exercise" on the finished banner uses the recomputed '
      'target, not the one frozen when rest finished', (tester) async {
    // 3 exercises, 1 set each, so completing Bench Press's only set starts
    // a rest whose next target is Lat Pulldown (the next exercise in
    // session order at that moment).
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    for (final n in ['Bench Press', 'Lat Pulldown', 'Squat']) {
      final e = await exercises.create(
        name: n,
        loggingType: LoggingType.strengthWeightRepsRir,
      );
      await templates.addExercise(
        templateId: t.id,
        exerciseId: e.id,
        targetSets: 1,
        restSeconds: 90,
      );
    }
    await sessions.startFromTemplate(t.id, weightUnit: 'kg');

    await tester.pumpWidget(harness());
    await pumpUntilSessionData(tester);

    // Auto-focus off, so the finished rest parks in the manual "REST
    // COMPLETE" banner this test drives by hand, rather than resolving on
    // its own.
    unawaited(container
        .read(activeSessionControllerProvider.notifier)
        .setAutoFocusNextExercise(false));
    await pumpUntilSessionData(tester);

    final completeButton = find.byTooltip('Complete set').first;
    await tester.ensureVisible(completeButton);
    await tester.pump();
    await tester.tap(completeButton);
    await pumpUntilSessionData(tester);

    final skipButton = find.byIcon(Icons.skip_next);
    await tester.ensureVisible(skipButton);
    await tester.pump();
    await tester.tap(skipButton);
    await pumpUntilSessionData(tester);
    expect(find.text('Next exercise'), findsOneWidget);

    // Rest stopped being active (and so stopped being watched) the moment
    // it finished above — drain the ticker's pending timer here, while
    // still close to that transition, rather than only at teardown. Same
    // reasoning as the "Next set" test above: leaving this straggler
    // untouched through the several extra real-async round trips below
    // (reorder + another `pumpUntilSessionData`) is what left more than one
    // `Future.delayed` Timer in flight by teardown.
    container.invalidate(restTickerProvider);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }

    // Reorder the still-pending exercises while the banner is up — the same
    // PRD §18.8 "machine occupied" scenario as the controller-level
    // "reordering during active rest" tests, just occurring after rest has
    // already finished, in the window the app is explicitly waiting on the
    // user. Pending order [Lat Pulldown, Squat] -> [Squat, Lat Pulldown].
    unawaited(container
        .read(activeSessionControllerProvider.notifier)
        .reorder(0, 2));
    await pumpUntilSessionData(tester);

    final nextExerciseButton = find.text('Next exercise');
    await tester.ensureVisible(nextExerciseButton);
    await tester.pump();
    await tester.tap(nextExerciseButton);
    await pumpUntilSessionData(tester);

    final state =
        await container.read(activeSessionControllerProvider.future);
    // Squat, not the frozen Lat Pulldown — proves the tap recomputes
    // against the post-reorder session rather than trusting
    // `rest.nextTarget`, which was captured when rest finished, before the
    // reorder.
    expect(state!.currentTarget!.exerciseName, 'Squat');
    expect(find.byType(RestBar), findsNothing);

    await disposeRestScreen(tester);
    // This test's several extra real-async round trips (multiple
    // `pumpUntilSessionData` calls layered on top of the rest ticker) can
    // leave more than one `restTickerProvider` `Future.delayed` timer
    // in flight by teardown — `disposeRestScreen`'s usual 3 pumps aren't
    // always enough here, so drain a few more.
    container.invalidate(restTickerProvider);
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
  });
}
