import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/library/ui/library_screen.dart';
import 'package:gymflow/features/programs/data/program_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';
import 'pump_helpers.dart';

/// S-004: one flat list under filter chips, where the create row, the
/// Favourites pseudo-item and real items all share a single row shape.
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
      child: MaterialApp(theme: AppTheme.dark(), home: const LibraryScreen()),
    );
  }

  testWidgets('lists routines with their exercise count, create row first',
      (tester) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: 'Pull B');
    final row = await exercises.create(
        name: 'Barbell Row', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(templateId: t.id, exerciseId: row.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Pull B'));

    expect(find.text('Create new routine'), findsOneWidget);
    expect(find.text('1 exercise'), findsOneWidget);

    // The create row sits at the top of the list it adds to, rather than
    // floating over it.
    final yCreate = tester.getTopLeft(find.text('Create new routine')).dy;
    final yItem = tester.getTopLeft(find.text('Pull B')).dy;
    expect(yCreate, lessThan(yItem));

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('the Exercises chip swaps the list and adds Favourites',
      (tester) async {
    final exercises = ExerciseRepository(db);
    await exercises.create(
        name: 'Barbell Row', loggingType: LoggingType.strengthWeightRepsRir);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Create new routine'));

    // Favourites is exercise-only: routines carry no favourite flag yet.
    expect(find.text('Favourites'), findsNothing);

    await tester.tap(find.text('Exercises'));
    await tester.pumpAndSettle();

    expect(find.text('Create new exercise'), findsOneWidget);
    expect(find.text('Favourites'), findsOneWidget);
    expect(find.text('Barbell Row'), findsOneWidget);
    expect(find.text('Create new routine'), findsNothing);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('initials tiles are derived from the name, not stored',
      (tester) async {
    await TemplateRepository(db).createTemplate(name: 'Pull B');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Pull B'));

    // "Pull B" -> "PB": first letters of the first two words.
    expect(
      find.descendant(
        of: find.byType(InitialsTile),
        matching: find.text('PB'),
      ),
      findsOneWidget,
    );

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('the + button opens a create sheet with all three options',
      (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Create new routine'));

    await tester.tap(find.byTooltip('Add to library'));
    await tester.pumpAndSettle();

    expect(find.text('Program'), findsOneWidget);
    expect(find.text('Create a program with your routines'), findsOneWidget);
    expect(find.text('Routine'), findsOneWidget);
    expect(find.text('Create a reusable workout routine'), findsOneWidget);
    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('Create a custom exercise'), findsOneWidget);

    await disposeAndDrainTimers(tester, container: container);
  });

  testWidgets('opens on Routines, and Programs lists programs with counts',
      (tester) async {
    final templates = TemplateRepository(db);
    final program = await ProgramRepository(db).create(name: 'Upper / Lower');
    final upper = await templates.createTemplate(name: 'Upper A');
    await ProgramRepository(db)
        .addRoutine(programId: program.id, templateId: upper.id);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Create new routine'));

    // Opens on Routines, not Programs: landing on an empty first chip would
    // make the library look emptier than it is (owner decision).
    expect(find.text('Create new program'), findsNothing);

    await tester.tap(find.text('Programs'));
    await pumpUntilData(tester, until: find.text('Upper / Lower'));

    expect(find.text('Create new program'), findsOneWidget);
    expect(find.text('1 routine'), findsOneWidget);

    await disposeAndDrainTimers(tester, container: container);
  });
}
