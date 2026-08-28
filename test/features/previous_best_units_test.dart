import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/features/history/providers/history_providers.dart';
import 'package:gymflow/features/sessions/domain/previous_best.dart';
import 'package:gymflow/features/sessions/providers/previous_best_provider.dart';
import 'package:gymflow/features/settings/data/settings_repository.dart';
import 'package:gymflow/features/settings/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('a bodyweight-only session yields no PreviousBest entry', () {
    // Mirrors computePersonalRecords's treatment of a logged 0 as bodyweight
    // work, not a 0 kg lift (T-026) — Previous must not disagree and surface
    // "0kg x 10" for an exercise Records deliberately ignores.
    final sessions = [completedSession(unit: 'kg', sets: [(0.0, 10)])];

    final best = previousBestByExercise(sessions, displayUnit: 'kg');

    expect(best, isEmpty);
  });

  test('switching the display unit restates previousBestProvider with no '
      'history edit', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      historyProvider.overrideWith(
        (ref) => Stream.value([completedSession(unit: 'kg', sets: [(60.0, 5)])]),
      ),
      settingsRepositoryProvider.overrideWithValue(SettingsRepository(prefs)),
    ]);
    addTearDown(container.dispose);
    // Let the overridden stream deliver before reading the derived provider.
    await container.read(historyProvider.future);

    expect(container.read(previousBestProvider)['ex-1']!.weight,
        closeTo(60, 1e-9));

    await container.read(settingsProvider.notifier).setWeightUnit('lb');

    expect(container.read(previousBestProvider)['ex-1']!.weight,
        closeTo(132.277, 1e-3),
        reason: 'the unit switch alone must recompute it');
  });
}
