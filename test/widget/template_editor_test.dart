import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/widgets/empty_state.dart';
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

  testWidgets(
      'a template with no exercises shows a full empty state: icon, title, '
      'explanation and CTA (PRD §16.6)', (tester) async {
    final templates = TemplateRepository(db);
    final t = await templates.createTemplate(name: 'Empty Day');

    await tester.pumpWidget(harness(t.id));
    await pumpUntilData(tester, until: find.byType(EmptyState));

    final empty = tester.widget<EmptyState>(find.byType(EmptyState));
    expect(empty.icon, isNotNull);
    expect(empty.title, 'No exercises yet');
    expect(empty.message, isNotEmpty);
    expect(empty.actionLabel, 'Add exercise');
    expect(empty.onAction, isNotNull);

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'the picker disambiguates duplicate exercise names with a body-part '
      'subtitle (PRD §18.9)', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Pull');
    await exercises.create(
        name: 'Row',
        loggingType: LoggingType.strengthWeightRepsRir,
        primaryMuscles: [Muscle.lats]);
    await exercises.create(
        name: 'Row',
        loggingType: LoggingType.strengthWeightRepsRir,
        primaryMuscles: [Muscle.quadriceps]);

    await tester.pumpWidget(harness(t.id));
    await pumpUntilData(tester, until: find.text('Add exercise'));

    final addButton = find.text('Add exercise').last;
    await tester.ensureVisible(addButton);
    await tester.pump();
    await tester.tap(addButton);
    await pumpUntilData(
        tester, until: find.text('Back · Strength'), maxFrames: 120);

    // Duplicate names are allowed and both are offered...
    expect(find.text('Row'), findsNWidgets(2));
    // ...told apart only by the body part shown as a subtitle.
    expect(find.text('Back · Strength'), findsOneWidget);
    expect(find.text('Legs · Strength'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'the picker shows a full empty state for a search matching nothing, '
      'and the sheet stays draggable (PRD §16.6)', (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Pull');
    final row = await exercises.create(
        name: 'Row', loggingType: LoggingType.strengthWeightRepsRir);
    // Give the template one exercise already, so the screen *behind* the
    // sheet isn't itself showing an EmptyState (its own "no exercises yet"
    // state) while the sheet's "no matches" state is asserted below.
    await templates.addExercise(templateId: t.id, exerciseId: row.id);

    await tester.pumpWidget(harness(t.id));
    await pumpUntilData(tester, until: find.text('Add exercise'));

    final addButton = find.text('Add exercise').last;
    await tester.ensureVisible(addButton);
    await tester.pump();
    await tester.tap(addButton);
    await pumpUntilData(tester, until: find.text('Row'), maxFrames: 120);

    await tester.enterText(find.byType(TextField).last, 'zzz-nomatch');
    await pumpUntilData(tester, until: find.byType(EmptyState), maxFrames: 120);

    final empty = tester.widget<EmptyState>(find.byType(EmptyState));
    expect(empty.icon, Icons.search_off);
    expect(empty.title, 'No matches');
    expect(empty.message, contains('zzz-nomatch'));
    expect(empty.actionLabel, 'Create new exercise');
    expect(empty.onAction, isNotNull);

    // The DraggableScrollableSheet's scrollController must still be
    // attached to a scrollable while the empty state is showing, or the
    // sheet can no longer be dragged to resize/dismiss (Important 2). Find
    // the ListView that both wraps the EmptyState and carries an explicit
    // (non-null) controller — the sheet always passes its own
    // scrollController in, unlike a plain default-constructed ListView.
    final wrappingListView = tester.widgetList<ListView>(find.ancestor(
      of: find.byType(EmptyState),
      matching: find.byType(ListView),
    ));
    expect(wrappingListView, hasLength(1));
    expect(wrappingListView.single.controller, isNotNull);
    expect(tester.takeException(), isNull);

    await disposeAndDrainTimers(tester);
  });
}
