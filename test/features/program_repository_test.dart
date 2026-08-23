import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/programs/data/program_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';

/// T-006: a program is a named, ordered collection of routines. Organisation
/// only — no scheduling.
void main() {
  late AppDatabase db;
  late ProgramRepository programs;
  late TemplateRepository templates;

  setUp(() {
    db = testDatabase();
    programs = ProgramRepository(db);
    templates = TemplateRepository(db);
  });
  tearDown(() => db.close());

  test('holds routines in order, and reordering persists', () async {
    final program = await programs.create(name: 'Upper / Lower');
    final a = await templates.createTemplate(name: 'Upper A');
    final b = await templates.createTemplate(name: 'Lower A');
    await programs.addRoutine(programId: program.id, templateId: a.id);
    await programs.addRoutine(programId: program.id, templateId: b.id);

    var loaded = await programs.watchProgram(program.id).first;
    expect([for (final r in loaded!.routines) r.template.name],
        ['Upper A', 'Lower A']);

    await programs.reorder(program.id, 1, 0);
    loaded = await programs.watchProgram(program.id).first;
    expect([for (final r in loaded!.routines) r.template.name],
        ['Lower A', 'Upper A']);
  });

  test('the same routine can appear twice — an A/B/A week is real', () async {
    final program = await programs.create(name: 'A/B/A');
    final a = await templates.createTemplate(name: 'Push A');
    await programs.addRoutine(programId: program.id, templateId: a.id);
    await programs.addRoutine(programId: program.id, templateId: a.id);

    final loaded = await programs.watchProgram(program.id).first;
    expect(loaded!.routines, hasLength(2));
    // Only sortOrder tells the two apart, so there is no unique constraint to
    // trip over.
    expect(loaded.routines[0].membership.id,
        isNot(loaded.routines[1].membership.id));
  });

  test('deleting a routine empties it out of programs, keeping the program',
      () async {
    final program = await programs.create(name: 'Upper / Lower');
    final a = await templates.createTemplate(name: 'Upper A');
    final b = await templates.createTemplate(name: 'Lower A');
    await programs.addRoutine(programId: program.id, templateId: a.id);
    await programs.addRoutine(programId: program.id, templateId: b.id);

    await templates.deleteTemplate(a.id);

    final loaded = await programs.watchProgram(program.id).first;
    expect(loaded, isNotNull, reason: 'the program itself must survive');
    expect([for (final r in loaded!.routines) r.template.name], ['Lower A'],
        reason: 'a soft-deleted routine must not still be listed');

    final summaries = await programs.watchSummaries().first;
    expect(summaries.single.routineCount, 1,
        reason: 'the count must not include the deleted routine');
  });

  test('removing a routine resequences the rest, leaving no gaps', () async {
    final program = await programs.create(name: 'Three');
    for (final name in ['One', 'Two', 'Three']) {
      final t = await templates.createTemplate(name: name);
      await programs.addRoutine(programId: program.id, templateId: t.id);
    }

    var loaded = await programs.watchProgram(program.id).first;
    await programs.removeRoutine(loaded!.routines[1].membership.id);

    loaded = await programs.watchProgram(program.id).first;
    expect([for (final r in loaded!.routines) r.membership.sortOrder], [0, 1],
        reason: 'gaps would collide with the next insert');
  });

  test('an empty program is valid and is listed with a zero count', () async {
    await programs.create(name: 'Planned but empty');
    final summaries = await programs.watchSummaries().first;
    expect(summaries.single.routineCount, 0);
  });

  test('a deleted program disappears from the library listing', () async {
    final program = await programs.create(name: 'Scrapped');
    await programs.delete(program.id);
    expect(await programs.watchSummaries().first, isEmpty);
  });
}
