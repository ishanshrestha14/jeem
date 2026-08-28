import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/features/history/providers/history_providers.dart';
import 'package:gymflow/features/records/data/personal_records.dart';
import 'package:gymflow/features/records/providers/records_providers.dart';
import 'package:gymflow/features/settings/data/settings_repository.dart';
import 'package:gymflow/features/settings/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/session_fixtures.dart';

/// T-026 — records compared raw numbers, so the unit a session was logged in
/// decided the ranking.
void main() {
  test('a heavier kg lift outranks a larger lb number', () {
    // 100 lb = 45.36 kg, so the 60 kg set is the real record even though
    // 100 > 60 as a bare number — the bug this ticket fixes.
    final sessions = [
      completedSession(unit: 'lb', sets: [(100.0, 5)]),
      completedSession(unit: 'kg', sets: [(60.0, 5)]),
    ];

    final records = computePersonalRecords(sessions, displayUnit: 'kg');

    expect(records.single.heaviestWeight!.value, closeTo(60, 1e-9));
  });

  test('restates every record in the display unit', () {
    final sessions = [completedSession(unit: 'kg', sets: [(60.0, 5)])];

    final records = computePersonalRecords(sessions, displayUnit: 'lb');

    // 60 kg = 132.277 lb.
    expect(records.single.heaviestWeight!.value, closeTo(132.277, 1e-3));
  });

  test('a zero-weight set sets no weight-derived record', () {
    // Bodyweight work. A 0 kg "record" is not a lift, and it is what the
    // progress chart would otherwise plot at zero. It still sets a reps
    // record (see the next test) — this one only guards the weight metrics.
    final sessions = [completedSession(unit: 'kg', sets: [(0.0, 10)])];

    final records = computePersonalRecords(sessions, displayUnit: 'kg');

    expect(records.single.heaviestWeight, isNull);
    expect(records.single.bestEstimatedOneRepMax, isNull);
    expect(records.single.bestSessionVolume, isNull);
  });

  test('a zero-weight set still sets a reps record but no weight record', () {
    // ADR-004: mostReps ignores weight entirely, so 0 kg x 25 is still a reps
    // record even though it is not a weight one (T-026).
    final sessions = [completedSession(unit: 'kg', sets: [(0.0, 25)])];

    final records = computePersonalRecords(sessions, displayUnit: 'kg');

    expect(records.single.mostReps?.value, closeTo(25, 1e-9));
    expect(records.single.heaviestWeight, isNull);
    expect(records.single.bestEstimatedOneRepMax, isNull);
    expect(records.single.bestSessionVolume, isNull);
  });

  test('switching the display unit restates records with no history edit',
      () async {
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

    expect(container.read(personalRecordsProvider).single.heaviestWeight!.value,
        closeTo(60, 1e-9));

    await container.read(settingsProvider.notifier).setWeightUnit('lb');

    expect(container.read(personalRecordsProvider).single.heaviestWeight!.value,
        closeTo(132.277, 1e-3),
        reason: 'the unit switch alone must recompute it');
  });
}
