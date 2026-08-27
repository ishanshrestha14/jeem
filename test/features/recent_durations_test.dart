import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/templates/data/template_repository.dart';

import '../db/test_database.dart';

/// T-025 — the measured half of the routine detail's duration stat: what this
/// routine has actually cost you, not what the plan guesses.
///
/// Sessions are inserted directly rather than driven through the session flow,
/// because the point of every case here is an exact `startedAt`/`endedAt`/
/// `pausedSeconds` triple, and driving the flow would hide those behind a
/// clock.
void main() {
  late AppDatabase db;
  late TemplateRepository templates;

  setUp(() {
    db = testDatabase();
    templates = TemplateRepository(db);
  });
  tearDown(() => db.close());

  final base = DateTime.utc(2026, 8, 1, 18);
  var seq = 0;

  Future<void> aSession({
    required String templateId,
    required Duration ran,
    int pausedSeconds = 0,
    SessionStatus status = SessionStatus.completed,
    DateTime? deletedAt,
    int daysAgo = 0,
  }) async {
    final startedAt = base.subtract(Duration(days: daysAgo));
    await db.into(db.workoutSessions).insert(
          WorkoutSessionsCompanion.insert(
            id: 's-${seq++}',
            name: 'Push',
            status: status,
            startedAt: startedAt,
            createdAt: startedAt,
            updatedAt: startedAt,
            templateId: Value(templateId),
            endedAt: Value(startedAt.add(ran)),
            pausedSeconds: Value(pausedSeconds),
            deletedAt: Value(deletedAt),
          ),
        );
  }

  test('returns the elapsed time of this routine completed sessions',
      () async {
    final t = await templates.createTemplate(name: 'Push');
    await aSession(templateId: t.id, ran: const Duration(minutes: 50));

    expect(
      await templates.recentDurations(t.id),
      [const Duration(minutes: 50)],
    );
  });

  test('subtracts paused time, as the live session header does', () async {
    final t = await templates.createTemplate(name: 'Push');
    await aSession(
      templateId: t.id,
      ran: const Duration(minutes: 60),
      pausedSeconds: 600,
    );

    expect(
      await templates.recentDurations(t.id),
      [const Duration(minutes: 50)],
    );
  });

  test('takes the three most recent, newest first', () async {
    final t = await templates.createTemplate(name: 'Push');
    for (var i = 0; i < 5; i++) {
      await aSession(
        templateId: t.id,
        ran: Duration(minutes: 40 + i),
        daysAgo: i,
      );
    }

    expect(await templates.recentDurations(t.id), const [
      Duration(minutes: 40),
      Duration(minutes: 41),
      Duration(minutes: 42),
    ]);
  });

  test('ignores a session that is still running', () async {
    final t = await templates.createTemplate(name: 'Push');
    await aSession(
      templateId: t.id,
      ran: const Duration(minutes: 50),
      status: SessionStatus.active,
    );

    expect(await templates.recentDurations(t.id), isEmpty);
  });

  test('ignores a deleted session, so deleting a bad workout unskews it',
      () async {
    final t = await templates.createTemplate(name: 'Push');
    await aSession(
      templateId: t.id,
      ran: const Duration(minutes: 50),
      deletedAt: base,
    );

    expect(await templates.recentDurations(t.id), isEmpty);
  });

  test('ignores sessions from another routine', () async {
    final mine = await templates.createTemplate(name: 'Push');
    final other = await templates.createTemplate(name: 'Pull');
    await aSession(templateId: other.id, ran: const Duration(minutes: 50));

    expect(await templates.recentDurations(mine.id), isEmpty);
  });

  test('drops a non-positive duration as corrupt', () async {
    final t = await templates.createTemplate(name: 'Push');
    await aSession(
      templateId: t.id,
      ran: const Duration(minutes: 10),
      pausedSeconds: 600,
    );

    expect(await templates.recentDurations(t.id), isEmpty);
  });

  test('keeps an implausibly long session, because T-020 lets you edit it',
      () async {
    final t = await templates.createTemplate(name: 'Push');
    await aSession(templateId: t.id, ran: const Duration(hours: 5));

    expect(
      await templates.recentDurations(t.id),
      [const Duration(hours: 5)],
      reason: 'the finish form lets the user set this; overriding it here '
          'would silently discard their edit',
    );
  });
}
