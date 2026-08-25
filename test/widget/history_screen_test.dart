import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/history/ui/history_screen.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/sessions/ui/session_summary_screen.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:gymflow/features/templates/ui/template_editor_screen.dart';
import '../db/test_database.dart';
import 'pump_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const HistoryScreen(),
        ),
      );

  /// A real [GoRouter] wired for `/history`, `/session/summary/:id` and
  /// `/templates/:id` — needed to exercise tap-to-detail and the
  /// duplicate-template overflow action, both of which push via
  /// `context.push` (a go_router extension that throws without a
  /// [GoRouter] ancestor).
  Widget routedHarness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(
          theme: AppTheme.dark(),
          routerConfig: GoRouter(
            initialLocation: '/history',
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, _) => const HistoryScreen(),
              ),
              GoRoute(
                path: '/session/summary/:id',
                builder: (_, s) => SessionSummaryScreen(
                  sessionId: s.pathParameters['id']!,
                  readOnly: s.uri.queryParameters['readOnly'] == 'true',
                ),
              ),
              GoRoute(
                path: '/templates/:id',
                builder: (_, s) =>
                    TemplateEditorScreen(templateId: s.pathParameters['id']),
              ),
            ],
          ),
        ),
      );

  testWidgets('shows the empty state with an action returning to Home',
      (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('No completed sessions yet'));

    expect(find.text('No completed sessions yet'), findsOneWidget);
    expect(find.text('Go to Home'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'history lists completed sessions newest first, skips cancelled, '
      'and uses ListTile', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);

    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 2);

    // Push: completed yesterday.
    final pushSession = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    await db.update(db.workoutSessions).replace(pushSession.copyWith(
          startedAt: DateTime.now().subtract(const Duration(days: 1)),
        ));
    await sessions.finishSession(pushSession.id);

    // Pull: completed today, more recently.
    final pullTemplate = await templates.createTemplate(name: 'Pull');
    final row = await sessions.startFromTemplate(pullTemplate.id,
        weightUnit: 'kg');
    await sessions.finishSession(row.id);

    // Discarded: cancelled, must never appear.
    final discardTemplate = await templates.createTemplate(name: 'Discarded');
    final cancelled = await sessions.startFromTemplate(discardTemplate.id,
        weightUnit: 'kg');
    await sessions.cancelSession(cancelled.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Pull'));

    expect(find.text('Pull'), findsOneWidget);
    expect(find.text('Push'), findsOneWidget);
    expect(find.text('Discarded'), findsNothing);

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles, hasLength(2));
    expect((tiles.first.title! as Text).data, 'Pull');

    await disposeAndDrainTimers(tester);
  });

  testWidgets('subtitle shows date, duration, set count and volume',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);

    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 2);

    final session = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    final rows = await (db.select(db.sessionSets)).get();
    await sessions.updateSet(rows.first.copyWith(
      completedAt: Value(DateTime.now()),
      weight: const Value(80.0),
      reps: const Value(5),
    ));
    await sessions.finishSession(session.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Push'));

    final tile = tester.widget<ListTile>(find.byType(ListTile).first);
    final subtitle = (tile.subtitle! as Text).data!;
    expect(subtitle, contains('1/2 sets'));
    expect(subtitle, contains('400 kg')); // 80 * 5

    await disposeAndDrainTimers(tester);
  });

  testWidgets('tapping a row opens the read-only session summary',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);

    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 2);
    final session = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    await sessions.finishSession(session.id);

    await tester.pumpWidget(routedHarness());
    await pumpUntilData(tester, until: find.text('Push'));

    await tester.tap(find.byType(ListTile).first);
    await pumpUntilData(tester, until: find.text('Summary'));

    expect(find.text('Summary'), findsOneWidget);
    // Read-only: no Save/Discard bottom bar.
    expect(find.text('Discard'), findsNothing);
    expect(find.text('Save'), findsNothing);

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'duplicate action is offered when templateId is set and the '
      'template still exists, and creates a new template', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);

    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 2);
    final session = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    await sessions.finishSession(session.id);

    await tester.pumpWidget(routedHarness());
    await pumpUntilData(tester, until: find.text('Push'));
    // Wait for the per-row templateProvider watch to resolve so the
    // overflow button has appeared.
    await pumpUntilData(tester, until: find.byIcon(Icons.more_vert));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate this workout as a template'));
    await pumpUntilData(tester, until: find.byType(TemplateEditorScreen));

    expect(find.byType(TemplateEditorScreen), findsOneWidget);

    final all = await (db.select(db.workoutTemplates)).get();
    expect(all, hasLength(2));
    expect(all.any((tpl) => tpl.name == 'Push (copy)'), isTrue);

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'duplicate action is hidden when the session has no templateId',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);

    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 2);
    final session = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    await sessions.finishSession(session.id);

    // Null out templateId directly, simulating an orphaned session.
    final row = await (db.select(db.workoutSessions)
          ..where((s) => s.id.equals(session.id)))
        .getSingle();
    await db.update(db.workoutSessions).replace(
          row.copyWith(templateId: const Value(null)),
        );

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Push'));
    // Give the (absent) per-row template watch a beat to settle.
    await tester.pump(const Duration(milliseconds: 100));

    // The menu itself stays: Duplicate needs a surviving template, but Delete
    // applies to any logged workout — an ad-hoc session has no template at all
    // and must still be removable.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Duplicate this workout as a template'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'duplicate action is hidden when the template was deleted',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);

    final t = await templates.createTemplate(name: 'Push');
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: bench.id, targetSets: 2);
    final session = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    await sessions.finishSession(session.id);
    await templates.deleteTemplate(t.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Push'));
    await tester.pump(const Duration(milliseconds: 100));

    // The menu itself stays: Duplicate needs a surviving template, but Delete
    // applies to any logged workout — an ad-hoc session has no template at all
    // and must still be removable.
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Duplicate this workout as a template'), findsNothing);
    expect(find.text('Delete'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('a logged workout can be deleted from history', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    final e = await exercises.create(
        name: 'Bench', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: e.id, targetSets: 1);
    final s = await sessions.startFromTemplate(t.id, weightUnit: 'kg');
    await sessions.finishSession(s.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Push'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete workout'));
    await pumpUntilGone(tester, find.text('Push'));

    expect(find.text('Push'), findsNothing);

    await disposeAndDrainTimers(tester);
  });
}
