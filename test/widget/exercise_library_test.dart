import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/core/widgets/empty_state.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/exercises/ui/exercise_list_screen.dart';
import '../db/test_database.dart';
import 'pump_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child:
            MaterialApp(theme: AppTheme.dark(), home: const ExerciseListScreen()),
      );

  testWidgets('shows an empty state with a call to action', (tester) async {
    await tester.pumpWidget(harness());
    await pumpUntilData(tester);
    expect(find.text('Create an exercise'), findsOneWidget);
    await disposeAndDrainTimers(tester);
  });

  testWidgets('lists exercises and filters them by search', (tester) async {
    final repo = ExerciseRepository(db);
    await repo.create(name: 'Lat Pulldown', loggingType: LoggingType.strengthWeightRepsRir);
    await repo.create(name: 'Leg Press', loggingType: LoggingType.strengthWeightRepsRir);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester);
    expect(find.text('Lat Pulldown'), findsOneWidget);
    expect(find.text('Leg Press'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'pull');
    await pumpUntilData(tester);
    expect(find.text('Lat Pulldown'), findsOneWidget);
    expect(find.text('Leg Press'), findsNothing);
    await disposeAndDrainTimers(tester);
  });

  testWidgets(
      'a search matching nothing shows a full empty state and "Clear '
      'search" restores the list (PRD §16.6)', (tester) async {
    final repo = ExerciseRepository(db);
    await repo.create(name: 'Lat Pulldown', loggingType: LoggingType.strengthWeightRepsRir);
    await repo.create(name: 'Leg Press', loggingType: LoggingType.strengthWeightRepsRir);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester);

    await tester.enterText(find.byType(TextField).first, 'zzz-nomatch');
    await pumpUntilData(tester, until: find.byType(EmptyState));

    final empty = tester.widget<EmptyState>(find.byType(EmptyState));
    expect(empty.icon, Icons.search_off);
    expect(empty.title, 'No matches');
    expect(empty.message, contains('zzz-nomatch'));
    expect(empty.actionLabel, 'Clear search');
    expect(empty.onAction, isNotNull);

    await tester.tap(find.text('Clear search'));
    await pumpUntilData(tester);

    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, isEmpty);
    expect(find.text('Lat Pulldown'), findsOneWidget);
    expect(find.text('Leg Press'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('tapping the info icon opens the info sheet', (tester) async {
    await ExerciseRepository(db).create(
      name: 'Plank',
      loggingType: LoggingType.durationOnly,
      description: 'Forearm plank with a neutral spine.',
    );

    await tester.pumpWidget(harness());
    await pumpUntilData(tester);
    await tester.tap(find.byIcon(Icons.info_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Forearm plank with a neutral spine.'), findsOneWidget);
    // The list tile behind the sheet also renders a plain "Duration" label
    // for this exercise's logging type, so scope this check to the sheet's
    // Chip to prove the sheet itself shows the logging type.
    expect(
      find.descendant(of: find.byType(Chip), matching: find.text('Duration')),
      findsOneWidget,
    );
    await disposeAndDrainTimers(tester);
  });

  testWidgets('body-part chips filter the list (S-026)', (tester) async {
    final exercises = ExerciseRepository(db);
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    final squat = await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await exercises.setTaxonomy(bench.id,
        primary: const [], secondary: const [], bodyParts: const [BodyPart.chest]);
    await exercises.setTaxonomy(squat.id,
        primary: const [], secondary: const [], bodyParts: const [BodyPart.legs]);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Bench Press'));

    expect(find.text('Back Squat'), findsOneWidget);

    // Filtering by a body part is what the taxonomy (T-005) exists for; until
    // now the library could only be searched by name.
    await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
    // Waits for the filtered state, not merely for one row to vanish: the
    // body-part map arrives on its own stream, so "Squat is gone" is briefly
    // true for the wrong reason.
    await pumpUntilData(
      tester,
      until: find.byWidgetPredicate((w) =>
          w is Text && w.data == 'Bench Press'),
    );
    await pumpUntilGone(tester, find.text('Back Squat'));

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Back Squat'), findsNothing);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('tapping the active chip again clears the filter',
      (tester) async {
    final exercises = ExerciseRepository(db);
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    await exercises.create(
        name: 'Back Squat', loggingType: LoggingType.strengthWeightRepsRir);
    await exercises.setTaxonomy(bench.id,
        primary: const [], secondary: const [], bodyParts: const [BodyPart.chest]);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Bench Press'));

    await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
    await pumpUntilGone(tester, find.text('Back Squat'));
    await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
    await pumpUntilData(tester, until: find.text('Back Squat'));

    expect(find.text('Back Squat'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('an untagged exercise is hidden by any body-part filter',
      (tester) async {
    final exercises = ExerciseRepository(db);
    final bench = await exercises.create(
        name: 'Bench Press', loggingType: LoggingType.strengthWeightRepsRir);
    await exercises.create(
        name: 'Mystery Move', loggingType: LoggingType.strengthWeightRepsRir);
    await exercises.setTaxonomy(bench.id,
        primary: const [], secondary: const [], bodyParts: const [BodyPart.chest]);

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Mystery Move'));

    await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
    await pumpUntilGone(tester, find.text('Mystery Move'));

    // Untagged is the normal state early on (ADR-006), so this is a real
    // consequence worth pinning: filtering hides everything untagged.
    expect(find.text('Mystery Move'), findsNothing);

    await disposeAndDrainTimers(tester);
  });
}
