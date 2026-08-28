import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/features/sessions/domain/previous_best.dart';

import '../support/session_fixtures.dart';

/// T-026 — `Previous` scored raw numbers, so a set logged in lb could beat a
/// genuinely heavier kg set.
void main() {
  test('reports the previous best in the display unit', () {
    // Logged as 135 lb; shown to a kg user as 61.2 kg.
    final sessions = [completedSession(unit: 'lb', sets: [(135.0, 5)])];

    final best = previousBestByExercise(sessions, displayUnit: 'kg');

    expect(best.values.single.weight, closeTo(61.235, 1e-3));
  });

  test('ranks two sets from one session by converted weight', () {
    // Same session, so same unit — this guards that the ordering logic still
    // works once weights pass through conversion.
    final sessions = [
      completedSession(unit: 'kg', sets: [(60.0, 8), (70.0, 5)]),
    ];

    final best = previousBestByExercise(sessions, displayUnit: 'kg');

    // 70x5 estimates higher than 60x8 under Epley (ADR-004).
    expect(best.values.single.weight, closeTo(70, 1e-9));
  });
}
