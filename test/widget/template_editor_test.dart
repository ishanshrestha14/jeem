import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';
import 'package:gymflow/features/templates/ui/template_editor_screen.dart';
import '../db/test_database.dart';
import 'pump_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Widget harness(String templateId) => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: TemplateEditorScreen(templateId: templateId),
        ),
      );

  testWidgets('renders the template name and its exercises with sets and rest',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Legs A');
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(
        templateId: t.id, exerciseId: squat.id, targetSets: 5, restSeconds: 180);

    await tester.pumpWidget(harness(t.id));
    // template_editor_screen.dart is backed by a Drift stream (templateProvider):
    // its loading branch renders an indeterminate CircularProgressIndicator, so
    // pumpAndSettle would spin for its full timeout. Pump until data lands
    // instead (see pump_helpers.dart).
    await pumpUntilData(tester);

    expect(find.widgetWithText(TextField, 'Legs A'), findsOneWidget);
    expect(find.text('Back Squat'), findsOneWidget);
    expect(find.textContaining('5 sets'), findsOneWidget);
    expect(find.textContaining('3:00 rest'), findsOneWidget);
    expect(find.byType(ReorderableListView), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('an archived exercise in a template is flagged', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    final e = await exercises.create(
        name: 'Old Machine', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(templateId: t.id, exerciseId: e.id);
    await exercises.archive(e.id);

    await tester.pumpWidget(harness(t.id));
    await pumpUntilData(tester);

    expect(find.text('Archived'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'backing out of an untouched draft with no name and no exercises deletes it',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TemplateEditorScreen(),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // A plain pumpUntilData() right after tap() can race the tap's own
    // gesture-arena resolution and the push transition itself: the *old*
    // screen also has zero CircularProgressIndicators, so the default
    // "no spinner" exit condition can be satisfied before the destination
    // route has even been built. Wait on real destination content instead.
    await tester.tap(find.text('Open editor'));
    await pumpUntilData(tester, until: find.byType(BackButton));

    final templates = TemplateRepository(db);
    final all = await db.select(db.workoutTemplates).get();
    expect(all, hasLength(1));

    // The AppBar back button routes through the same cleanup path as the
    // system back gesture (see PopScope in template_editor_screen.dart).
    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(milliseconds: 350));

    final remaining = await db.select(db.workoutTemplates).get();
    expect(remaining, isEmpty);
    // Sanity: the repository is still usable afterwards.
    expect(await templates.createTemplate(name: 'x'), isNotNull);

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'a name edit typed just before dispose is flushed, not discarded',
      (tester) async {
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Old Name');

    await tester.pumpWidget(harness(t.id));
    await pumpUntilData(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Old Name'),
      'New Name',
    );
    // Deliberately do NOT pump out the 300ms debounce. Tear the widget down
    // immediately instead — dispose() must flush the pending write itself.
    await disposeAndDrainTimers(tester);

    final row = await (db.select(db.workoutTemplates)
          ..where((row) => row.id.equals(t.id)))
        .getSingle();
    expect(row.name, 'New Name');
  });
}
