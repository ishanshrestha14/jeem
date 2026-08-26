import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/data/session_repository.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';

/// FL-001's open question, closed. `deleteTemplate` is a hard delete, so a
/// routine can vanish between being listed and being started — from a stale
/// list, or a detail screen left open while it is deleted elsewhere.
void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  test('starting a routine that no longer exists throws RoutineNotFound',
      () async {
    final templates = TemplateRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    await templates.deleteTemplate(t.id);

    // Not a bare StateError from `getSingle`: callers need something they can
    // catch and explain, and "No element" is not an explanation.
    expect(
      () => sessions.startFromTemplate(t.id, weightUnit: 'kg'),
      throwsA(isA<RoutineNotFound>()),
    );
  });

  test('no half-built session is left behind', () async {
    final templates = TemplateRepository(db);
    final sessions = SessionRepository(db);
    final t = await templates.createTemplate(name: 'Push');
    await templates.deleteTemplate(t.id);

    await expectLater(
      () => sessions.startFromTemplate(t.id, weightUnit: 'kg'),
      throwsA(isA<RoutineNotFound>()),
    );

    expect(await db.select(db.workoutSessions).get(), isEmpty);
  });

  test('an id that never existed throws the same thing', () async {
    expect(
      () => SessionRepository(db).startFromTemplate('nope', weightUnit: 'kg'),
      throwsA(isA<RoutineNotFound>()),
    );
  });
}
