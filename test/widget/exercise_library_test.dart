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
}
