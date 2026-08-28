import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/features/dashboard/domain/weekly_summary.dart';

import '../support/session_fixtures.dart';

/// T-026 — weekly volume added kg and lb together.
void main() {
  final now = DateTime.utc(2026, 8, 26); // a Wednesday

  test('sums this week volume after converting each session', () {
    // 100 lb x 10 reps = 1000 lb of work = 453.59 kg.
    final sessions = [
      completedSession(unit: 'lb', sets: [(100.0, 10)], endedAt: now),
    ];

    final summary = weeklySummary(sessions, now: now, displayUnit: 'kg');

    expect(summary.volume, closeTo(453.59237, 1e-5));
  });

  test('computes the delta from unrounded sums', () {
    // Two weeks whose volumes differ by less than a whole unit must not
    // display a whole-unit delta: rounding each week first and subtracting
    // would manufacture one.
    final lastWeek = now.subtract(const Duration(days: 7));
    final sessions = [
      completedSession(unit: 'kg', sets: [(10.4, 1)], endedAt: now),
      completedSession(unit: 'kg', sets: [(10.0, 1)], endedAt: lastWeek),
    ];

    final summary = weeklySummary(sessions, now: now, displayUnit: 'kg');

    expect(summary.volumeDelta, closeTo(0.4, 1e-9));
  });
}
