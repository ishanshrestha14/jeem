import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/exercises/data/exercise_repository.dart';
import 'package:gymflow/features/library/ui/library_screen.dart';
import 'package:gymflow/features/programs/data/program_repository.dart';
import 'package:gymflow/features/programs/ui/program_editor_screen.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';
import 'pump_helpers.dart';

/// T-011: a routine is something you *do*, so its row carries a play button
/// that starts it without opening anything. A program holds several routines,
/// so there is nothing single to start — its rows carry none.
void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Widget harness() => ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const LibraryScreen(),
        ),
      );

  Future<String> seedRoutine(String name) async {
    final templates = TemplateRepository(db);
    final exercises = ExerciseRepository(db);
    final t = await templates.createTemplate(name: name);
    final e = await exercises.create(
        name: 'Row', loggingType: LoggingType.strengthWeightRepsRir);
    await templates.addExercise(templateId: t.id, exerciseId: e.id);
    return t.id;
  }

  testWidgets('a routine row carries a play button', (tester) async {
    await seedRoutine('Pull B');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Pull B'));

    expect(find.byTooltip('Start Pull B'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('the create row carries none — there is nothing to start',
      (tester) async {
    await seedRoutine('Pull B');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Pull B'));

    // One routine, one play button: the create row must not have grown one.
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('program rows carry no play button', (tester) async {
    await ProgramRepository(db).create(name: 'PPL');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Programs'));
    await tester.tap(find.text('Programs'));
    await pumpUntilData(tester, until: find.text('PPL'));

    expect(find.byIcon(Icons.play_arrow), findsNothing,
        reason: 'a program holds several routines — none of them is "the" one');

    await disposeAndDrainTimers(tester);
  });


  testWidgets('a routine inside a program carries the same play button',
      (tester) async {
    final templates = TemplateRepository(db);
    final programs = ProgramRepository(db);
    final t = await templates.createTemplate(name: 'Pull B');
    final p = await programs.create(name: 'PPL');
    await programs.addRoutine(programId: p.id, templateId: t.id);

    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: ProgramEditorScreen(programId: p.id),
      ),
    ));
    await pumpUntilData(tester, until: find.text('Pull B'));

    expect(find.byTooltip('Start Pull B'), findsOneWidget);
    // The remove control is still there — the play button joins it rather
    // than replacing it.
    expect(find.byTooltip('Remove from program'), findsOneWidget);

    await disposeAndDrainTimers(tester);
  });

  testWidgets('starting a routine deleted underneath explains itself',
      (tester) async {
    final id = await seedRoutine('Pull B');

    await tester.pumpWidget(harness());
    await pumpUntilData(tester, until: find.text('Pull B'));

    // Deleted after the list rendered, so the row on screen is stale — the
    // real-world shape of this: another surface removed it while you were
    // looking at the list. (Never await a Drift stream's `.first` in a widget
    // test body; `seedRoutine` hands the id back instead.)
    await TemplateRepository(db).deleteTemplate(id);

    await tester.tap(find.byTooltip('Start Pull B'));
    // The repository call is real async, which the fake clock does not drive —
    // nudge real time forward, then pump the frame that shows the snackbar.
    await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.text('That routine no longer exists.'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'explained, not crashed');

    await disposeAndDrainTimers(tester);
  });
}
