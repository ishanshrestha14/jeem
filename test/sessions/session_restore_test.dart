import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/services/keep_screen_on_setting.dart';
import 'package:gymflow/core/services/wakelock_service.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/test_database.dart';
import '../widget/pump_helpers.dart';

/// Records every call rather than driving the real `wakelock_plus` platform
/// channel — `flutter test` has no host implementation for it, and this
/// project runs no Android/iOS build here to exercise one.
class _RecordingWakelockService implements WakelockService {
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enable() async {
    enableCalls++;
  }

  @override
  Future<void> disable() async {
    disableCalls++;
  }
}

/// See the doc comment above `pumpUntilSessionData` in
/// `test/widget/active_session_test.dart` for the full reproduction evidence
/// of why this screen needs `tester.runAsync` rather than plain pumps or
/// awaiting the controller's own future, and why `pumpAndSettle` must never
/// be used on it. Reused verbatim.
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

  Future<void> seedAndStart({int restSeconds = 90, int sets = 2}) async {
    final exercises = ExerciseRepository(db);
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    for (final n in ['Bench Press', 'Lat Pulldown']) {
      final e = await exercises.create(
          name: n, loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(
          templateId: t.id, exerciseId: e.id,
          targetSets: sets, restSeconds: restSeconds);
    }
    await container
        .read(sessionRepositoryProvider)
        .startFromTemplate(t.id, weightUnit: 'kg');

    // Keeps the autoDispose provider alive across the `await`s below — see
    // the identical note in active_session_controller_test.dart.
    container.listen(activeSessionControllerProvider, (_, _) {});
  }

  setUp(() {
    db = testDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<ActiveSessionState> state() async {
    final ActiveSessionState? value =
        await container.read(activeSessionControllerProvider.future);
    return value!;
  }

  /// Disposes the current container and builds a fresh one over the SAME
  /// underlying database — the closest honest analogue to a cold start
  /// (app backgrounded, process killed, relaunched) available without an
  /// actual platform. Reassigns the shared `container` so `tearDown` only
  /// ever disposes a live instance.
  void simulateColdStart() {
    container.dispose();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  }

  group('rest timer restore', () {
    test(
        'a rest whose deadline passed while the app was closed comes back '
        'finished', () async {
      await seedAndStart(restSeconds: 90);
      final repo = container.read(sessionRepositoryProvider);
      final controller = container.read(activeSessionControllerProvider.notifier);
      final setId = (await state()).session.exercises.first.sets.first.id;
      await controller.completeSet(setId);
      final sessionId = (await state()).session.session.id;

      // Simulate the deadline having passed while the app was closed: write
      // a running rest whose `endsAt` is already in the past, through the
      // same Drift-backed `SessionRepository.saveRestState` the controller
      // itself uses for every rest mutation — never raw SQL, so there's no
      // way for a unit mismatch to make this lie.
      await repo.saveRestState(
        sessionId,
        RestTimerState(
          status: RestTimerStatus.running,
          totalSeconds: 90,
          endsAt: DateTime.now().subtract(const Duration(minutes: 5)),
          afterSetId: setId,
        ),
      );

      simulateColdStart();
      final restored = (await state());

      expect(restored.rest.status, RestTimerStatus.finished);
      expect(restored.rest.remainingAt(DateTime.now()), Duration.zero);
    });

    test(
        'a rest still in flight comes back running with the right '
        'remainder', () async {
      await seedAndStart(restSeconds: 90);
      final repo = container.read(sessionRepositoryProvider);
      final controller = container.read(activeSessionControllerProvider.notifier);
      final setId = (await state()).session.exercises.first.sets.first.id;
      await controller.completeSet(setId);
      final sessionId = (await state()).session.session.id;

      await repo.saveRestState(
        sessionId,
        RestTimerState(
          status: RestTimerStatus.running,
          totalSeconds: 90,
          endsAt: DateTime.now().add(const Duration(seconds: 30)),
          afterSetId: setId,
        ),
      );

      simulateColdStart();
      final restored = (await state());

      expect(restored.rest.status, RestTimerStatus.running);
      expect(restored.rest.remainingAt(DateTime.now()).inSeconds,
          closeTo(30, 2));
    });

    test('a paused rest comes back paused with its frozen remainder',
        () async {
      await seedAndStart(restSeconds: 90);
      final controller = container.read(activeSessionControllerProvider.notifier);
      final setId = (await state()).session.exercises.first.sets.first.id;
      await controller.completeSet(setId);
      await controller.pauseRest();
      final pausedRemaining = (await state()).rest.remainingSeconds;

      simulateColdStart();
      final restored = (await state());

      expect(restored.rest.status, RestTimerStatus.paused);
      expect(restored.rest.remainingSeconds, pausedRemaining);
    });
  });

  test('logged set values survive a full reopen', () async {
    await seedAndStart();
    final controller = container.read(activeSessionControllerProvider.notifier);
    final setId = (await state()).session.exercises.first.sets.first.id;

    await controller.updateSetValues(setId, weight: 82.5, reps: 8, rir: 2);

    simulateColdStart();
    final restored = await state();
    final set = restored.session.setById(setId)!;

    expect(set.weight, 82.5);
    expect(set.reps, 8);
    expect(set.rir, 2);
  });

  group('the carried-forward autoDispose / in-flight-mutation race', () {
    test(
        'a mutation still in flight when the last listener drops (this '
        "notifier's own autoDispose firing) completes without throwing",
        () async {
      // This is the actual production race, not a stand-in: the app's root
      // `ProviderContainer` lives for the whole app session and is never
      // disposed mid-mutation — what happens on "the user backs out of the
      // session screen fast" is that *this one* `autoDispose` provider's
      // element gets torn down (last listener gone) while the container
      // itself stays alive. Simulated here by opening a dedicated
      // subscription and closing it (rather than disposing `container`
      // wholesale, which throws for an unrelated reason: `ref.read` inside
      // an already-in-flight mutator then hits the *container's* own
      // disposed check, not the per-element guard this flag exists for —
      // confirmed by direct reproduction, see the Task 17 report).
      await seedAndStart();
      final controller = container.read(activeSessionControllerProvider.notifier);
      final setId = (await state()).session.exercises.first.sets.first.id;

      final sub = container.listen(activeSessionControllerProvider, (_, _) {});

      // Kick off a mutation but deliberately do not await it before the
      // listener drops — `completeSet` awaits `_ready()` (itself an
      // `await`, so this always yields at least one microtask) before it
      // ever touches the DB, so closing the subscription below is
      // guaranteed to land while the mutation is still in flight.
      final pending = controller.completeSet(setId);
      sub.close();
      // autoDispose's own teardown is scheduled, not synchronous — give it
      // a real turn to actually run before the mutation resumes.
      await Future<void>.delayed(Duration.zero);

      await expectLater(pending, completes);

      // The underlying DB write is NOT skipped by the disposed-notifier
      // guard (see `_setState`'s doc comment) — only the `state =` write is.
      // Confirm the set really did get marked complete on disk despite
      // nothing being left mounted to display it.
      final restored = (await container.read(
        activeSessionControllerProvider.future,
      ))!;
      expect(restored.session.setById(setId)!.completedAt, isNotNull);
    });
  });

  group('active session screen lifecycle', () {
    late ProviderContainer screenContainer;
    late _RecordingWakelockService wakelock;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      wakelock = _RecordingWakelockService();
    });

    Widget harness({bool keepScreenOn = false}) {
      SharedPreferences.setMockInitialValues(
        keepScreenOn ? {keepScreenOnPrefsKey: true} : {},
      );
      screenContainer = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          wakelockServiceProvider.overrideWithValue(wakelock),
        ],
      );
      return UncontrolledProviderScope(
        container: screenContainer,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ActiveSessionScreen(),
        ),
      );
    }

    testWidgets('the 1-second ticker is cancelled on dispose',
        (tester) async {
      await seedAndStart();
      await tester.pumpWidget(harness());
      await pumpUntilSessionData(tester);

      await disposeAndDrainTimers(tester, container: screenContainer);
      screenContainer.dispose();
      // No assertion needed beyond this point: flutter_test's
      // `AutomatedTestWidgetsFlutterBinding` fails the test at teardown if
      // any Timer is still pending. If `ActiveSessionScreen.dispose()`
      // stopped calling `_ticker?.cancel()`, this test would fail there
      // with "A Timer is still pending" rather than here.
    });

    testWidgets(
        'the wakelock is not enabled when the keep-screen-on setting is off',
        (tester) async {
      await seedAndStart();
      await tester.pumpWidget(harness());
      await pumpUntilSessionData(tester);
      // The setting provider's own build() is async; give its
      // `ref.listenManual(..., fireImmediately: true)` callback a turn to
      // run before asserting.
      await tester.pump();

      expect(wakelock.enableCalls, 0);

      await disposeAndDrainTimers(tester, container: screenContainer);
      screenContainer.dispose();
    });

    testWidgets(
        'the wakelock is enabled when the keep-screen-on setting is on',
        (tester) async {
      await seedAndStart();
      await tester.pumpWidget(harness(keepScreenOn: true));
      await pumpUntilSessionData(tester);
      await tester.pump();

      expect(wakelock.enableCalls, greaterThan(0));

      await disposeAndDrainTimers(tester, container: screenContainer);
      screenContainer.dispose();
    });
  });
}
