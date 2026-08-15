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
    // gesture-arena resolution and the push transition itself (before either
    // has produced a spinner to wait out), so let one immediate frame plus
    // the bounded 300ms push transition play out first — both finite, so
    // this is not the pumpAndSettle-on-a-stream trap.
    await tester.tap(find.text('Open editor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await pumpUntilData(tester);

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
}
