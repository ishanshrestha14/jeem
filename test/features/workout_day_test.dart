import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/sessions/data/session_models.dart';
import 'package:gymflow/features/templates/data/template_models.dart';
import 'package:gymflow/features/templates/domain/workout_day.dart';

/// S-003's two questions: what did I do today, and what should I do next.
void main() {
  var seq = 0;
  final now = DateTime(2026, 8, 25, 13, 0);

  TemplateSummary summary(String name, {DateTime? lastPerformed}) {
    final t = DateTime.utc(2026, 1, 1);
    return TemplateSummary(
      template: WorkoutTemplate(
        id: 'tpl-${seq++}',
        name: name,
        defaultRestSeconds: 90,
        autoFocusNextSet: true,
        autoFocusNextExercise: true,
        createdAt: t,
        updatedAt: t,
      ),
      exerciseCount: 1,
      totalSets: 3,
      lastPerformedAt: lastPerformed,
    );
  }

  ActiveSession session({required DateTime endedAt}) {
    final t = DateTime.utc(2026, 1, 1);
    return ActiveSession(
      session: WorkoutSession(
        id: 'ses-${seq++}',
        name: 'Pull B',
        weightUnit: 'kg',
        status: SessionStatus.completed,
        autoFocusNextSet: true,
        autoFocusNextExercise: true,
        startedAt: endedAt.subtract(const Duration(hours: 1)),
        endedAt: endedAt,
        pausedSeconds: 0,
        restStatus: RestTimerStatus.idle,
        createdAt: t,
        updatedAt: t,
      ),
      exercises: const [],
    );
  }

  group('suggested routines', () {
    test('a never-performed routine leads', () {
      final out = suggestedRoutines([
        summary('Done recently', lastPerformed: DateTime(2026, 8, 24)),
        summary('Never done'),
      ]);

      expect(out.first.template.name, 'Never done');
    });

    test('then least recently performed first', () {
      final out = suggestedRoutines([
        summary('Yesterday', lastPerformed: DateTime(2026, 8, 24)),
        summary('Last month', lastPerformed: DateTime(2026, 7, 20)),
        summary('Last week', lastPerformed: DateTime(2026, 8, 18)),
      ]);

      expect(out.map((s) => s.template.name).toList(),
          ['Last month', 'Last week', 'Yesterday']);
    });

    test('no routines yields no suggestions', () {
      expect(suggestedRoutines(const []), isEmpty);
    });
  });

  group("today's workouts", () {
    test('a session that ended today counts', () {
      final out = sessionsOn(
        [session(endedAt: DateTime(2026, 8, 25, 7, 30))],
        day: now,
      );

      expect(out, hasLength(1));
    });

    test('yesterday does not', () {
      final out = sessionsOn(
        [session(endedAt: DateTime(2026, 8, 24, 23, 59))],
        day: now,
      );

      expect(out, isEmpty);
    });

    test('a session is attributed to the day it ended, not started', () {
      // Started 11pm yesterday, finished 12:30am today: it is today's workout,
      // which is how history and the week strip already read it.
      final out = sessionsOn(
        [session(endedAt: DateTime(2026, 8, 25, 0, 30))],
        day: now,
      );

      expect(out, hasLength(1));
    });
  });
}
