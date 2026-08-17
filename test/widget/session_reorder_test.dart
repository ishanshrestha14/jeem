import 'dart:async';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/sessions/providers/active_session_controller.dart';
import 'package:gymflow/features/sessions/ui/active_session_screen.dart';
import 'package:gymflow/features/sessions/ui/session_reorder_screen.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/test_database.dart';
import '../session_feedback_fakes.dart';
import 'pump_helpers.dart';

/// Copied verbatim from `active_session_test.dart` (see that file's long
/// doc comment for the full mechanism and the two dead ends already ruled
/// out — `runAsync`-awaiting the controller's own future, and polling
/// container state from the real zone — both hang). `ActiveSessionScreen`
/// and `SessionReorderScreen` share the same reload-then-`.first` pattern,
/// so the same adaptive wait applies here.
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

/// Precise, deterministic drag helper. Drags [handle] to the *original*
/// position of [targetHandle] — deliberately another row's **drag handle**,
/// not its title text, and captured before the gesture starts. `Reorderable
/// ListView`'s swap math (`_dragUpdateItems` in the framework source)
/// compares the dragged item's proxy rect — anchored using the pointer's
/// grab offset *within that item* — against each row's rect. Targeting a
/// title `Text`, which sits in the upper portion of a `ListTile` with a
/// subtitle, doesn't correct for that grab offset and lands the drop one
/// row short; targeting the same widget type (handle-to-handle, so both
/// ends share the same vertical offset within their row) does not, and
/// reproduces Flutter's own `ReorderableListView` test results (see
/// `packages/flutter/test/material/reorderable_list_test.dart`, e.g.
/// dragging item 0 onto item 3's position in a 4-item list lands item 0 at
/// index 2, not 3 — the mid-list case task-16's brief warns is easy to get
/// wrong).
///
/// No `pumpAndSettle` — never used on these Drift-stream-backed screens;
/// see `pumpUntilSessionData` above. The `ReorderableListView.onReorder`
/// callback this triggers calls `controller.reorder(...)` without awaiting
/// it (mirroring how Flutter itself invokes the callback), so the caller
/// must follow up with `pumpUntilSessionData` to observe the persisted
/// result.
Future<void> dragHandleTo(
  WidgetTester tester,
  Finder handle,
  Finder targetHandle,
) async {
  final start = tester.getCenter(handle);
  final end = tester.getCenter(targetHandle);
  final gesture = await tester.startGesture(start);
  await gesture.moveTo(end);
  await gesture.up();
  // `ReorderableListView` only calls `onReorder` once its 250ms drop-proxy
  // animation completes (`_DragInfo`'s `_proxyAnimation` in the framework
  // source) — a zero-duration `pump()` here leaves the drag visually
  // "dropped" but `onReorder` never fires.
  await tester.pump(const Duration(milliseconds: 260));
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

  void buildContainer() {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        ...sessionFeedbackOverrides(),
      ],
    );
    // Keeps the autoDispose controller alive across the gap between seeding
    // and the eventual `pumpWidget` — mirrors
    // `active_session_controller_test.dart`'s `seedAndStart`.
    container.listen(activeSessionControllerProvider, (_, _) {});
  }

  Widget reorderHarness() => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const SessionReorderScreen(),
        ),
      );

  Widget sessionHarness() => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const ActiveSessionScreen(),
        ),
      );

  /// Seeds a template with one exercise per name in [names], each with a
  /// single target set, and starts a session from it. Deliberately does
  /// NOT touch `activeSessionControllerProvider` — only plain Drift
  /// `select`s and direct repository calls, both of which resolve on
  /// ordinary awaited Futures. `ActiveSessionController.build()` and its
  /// mutators instead round-trip through `SessionRepository.watchX().first`,
  /// which needs a genuine event-loop turn to settle its cancellation and
  /// hangs indefinitely if awaited directly inside a `testWidgets` body's
  /// fake-async zone (see `pumpUntilSessionData`'s source doc comment) —
  /// so all reads/writes to the controller below happen only after a
  /// widget is mounted and pumped, via `unawaited(...)` + `pumpUntilSessionData`.
  Future<void> seedPending(
    List<String> names, {
    int restSeconds = 0,
  }) async {
    final exercises = ExerciseRepository(db);
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    for (final n in names) {
      final e = await exercises.create(
          name: n, loggingType: LoggingType.strengthWeightRepsRir);
      await templates.addExercise(
        templateId: t.id,
        exerciseId: e.id,
        targetSets: 1,
        restSeconds: restSeconds,
      );
    }
    buildContainer();
    await container
        .read(sessionRepositoryProvider)
        .startFromTemplate(t.id, weightUnit: 'kg');
  }

  /// Session exercise names in current `sortOrder`, read straight off the
  /// DB rather than through the controller (see `seedPending`'s doc
  /// comment for why).
  Future<List<String>> orderedNames() async {
    final rows = await (db.select(db.sessionExercises)
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
    return rows.map((r) => r.name).toList();
  }

  Future<String> sessionExerciseIdOf(String name) async {
    final row = await (db.select(db.sessionExercises)
          ..where((t) => t.name.equals(name)))
        .getSingle();
    return row.id;
  }

  Future<String> onlySetIdOf(String sessionExerciseId) async {
    final row = await (db.select(db.sessionSets)
          ..where((t) => t.sessionExerciseId.equals(sessionExerciseId)))
        .getSingle();
    return row.id;
  }

  testWidgets('dragging an upcoming exercise updates the session order',
      (tester) async {
    // A, B, C — drag C's handle onto A's row. Mirrors Flutter's own
    // "bottom to top" ReorderableListView case, which lands the dragged
    // item exactly at the top.
    await seedPending(['A', 'B', 'C']);

    await tester.pumpWidget(reorderHarness());
    await pumpUntilSessionData(tester);

    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(3));

    await dragHandleTo(tester, handles.at(2), handles.at(0));
    await pumpUntilSessionData(tester);

    expect(await orderedNames(), ['C', 'A', 'B']);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      'a mid-list downward drag lands correctly (not at the very end)',
      (tester) async {
    // A, B, C, D — drag A's handle onto D's row. This is the discriminating
    // case: because `ReorderableListView.onReorder`'s `newIndex` is
    // computed BEFORE the dragged item is removed, dragging item 0 onto
    // item 3's row does NOT land it at index 3 — it lands at index 2,
    // exactly like Flutter's own "reorders its contents only when a drag
    // finishes" test. A downward drag to the very *end* of the list would
    // pass this test whether or not `reorderPending`'s `newIndex -= 1`
    // normalisation is applied (the off-by-one is absorbed by its
    // `.clamp()`), so it can't tell a correct pass-through from a
    // double-corrected one. This mid-list case can.
    await seedPending(['A', 'B', 'C', 'D']);

    await tester.pumpWidget(reorderHarness());
    await pumpUntilSessionData(tester);

    final handles = find.byIcon(Icons.drag_handle);
    await dragHandleTo(tester, handles.at(0), handles.at(3));
    await pumpUntilSessionData(tester);

    expect(await orderedNames(), ['B', 'C', 'A', 'D']);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('completed exercises are shown locked and have no drag handle',
      (tester) async {
    await seedPending(['A', 'B', 'C']);

    await tester.pumpWidget(reorderHarness());
    await pumpUntilSessionData(tester);

    final aId = await sessionExerciseIdOf('A');
    final aSetId = await onlySetIdOf(aId);
    unawaited(
      container.read(activeSessionControllerProvider.notifier).completeSet(aSetId),
    );
    await pumpUntilSessionData(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    expect(find.text('COMPLETED'), findsOneWidget);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('Do later moves the current exercise to the end',
      (tester) async {
    await seedPending(['A', 'B', 'C']);

    await tester.pumpWidget(sessionHarness());
    await pumpUntilSessionData(tester);

    // A is the current (pending index 0) exercise, so its card is
    // auto-expanded and its "Do later" button is showing.
    expect(find.text('Do later'), findsOneWidget);

    final doLaterButton = find.text('Do later');
    await tester.ensureVisible(doLaterButton);
    await tester.pump();
    await tester.tap(doLaterButton);
    await pumpUntilSessionData(tester);

    // A moved behind every other pending exercise; B is now first.
    expect(await orderedNames(), ['B', 'C', 'A']);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets(
      'reordering while a rest is running leaves rest.status, endsAt and '
      'afterSetId untouched', (tester) async {
    await seedPending(['A', 'B', 'C'], restSeconds: 300);

    await tester.pumpWidget(reorderHarness());
    await pumpUntilSessionData(tester);

    final aId = await sessionExerciseIdOf('A');
    final aSetId = await onlySetIdOf(aId);
    // Completing A's only set starts a genuine running rest (A becomes
    // locked/complete; B and C remain pending and draggable).
    unawaited(
      container.read(activeSessionControllerProvider.notifier).completeSet(aSetId),
    );
    await pumpUntilSessionData(tester);

    final restBefore =
        container.read(activeSessionControllerProvider).valueOrNull!.rest;
    expect(restBefore.status, RestTimerStatus.running);

    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));
    await dragHandleTo(tester, handles.at(1), handles.at(0));
    await pumpUntilSessionData(tester);

    final restAfter =
        container.read(activeSessionControllerProvider).valueOrNull!.rest;
    expect(restAfter.status, restBefore.status);
    expect(restAfter.endsAt, restBefore.endsAt);
    expect(restAfter.afterSetId, restBefore.afterSetId);

    await disposeAndDrainTimers(tester, container: container);
  });
}
