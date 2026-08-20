import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/core/services/session_feedback_settings.dart';
import 'package:gymflow/core/theme/app_theme.dart';
import 'package:gymflow/db/app_database.dart';
import 'package:gymflow/features/settings/data/settings_repository.dart';
import 'package:gymflow/features/settings/providers/settings_providers.dart';
import 'package:gymflow/features/settings/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/test_database.dart';
import '../session_feedback_fakes.dart';

/// Covers Ruling-51: the Settings screen's sound/haptics/keep-screen-on
/// switches must bind to the PRE-EXISTING device-wide providers
/// (`soundEnabledSettingProvider` etc.), not a new duplicate under
/// `SettingsRepository`. Follows the harness pattern from
/// `session_settings_sheet_test.dart` (mock shared_preferences, override
/// `databaseProvider`/feedback providers, `AppTheme.dark()`).
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;
  late ProviderContainer container;

  setUp(() async {
    db = testDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    // Bounded pumps rather than pumpAndSettle — this screen transitively
    // reaches live Drift streams via other providers, same rationale as
    // session_settings_sheet_test.dart.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Widget harness() {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        // Real, prefs-backed SettingsRepository — settingsRepositoryProvider
        // throws UnimplementedError by default, so any render of
        // SettingsScreen without this override would crash.
        settingsRepositoryProvider.overrideWithValue(SettingsRepository(prefs)),
        ...sessionFeedbackOverrides(),
      ],
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const SettingsScreen(),
      ),
    );
  }

  testWidgets(
      'toggling the Sound switch flips soundEnabledSettingProvider (the '
      'same pre-existing provider, not a new duplicate)', (tester) async {
    await tester.pumpWidget(harness());
    await pump(tester);

    final before = await container.read(soundEnabledSettingProvider.future);
    expect(before, isTrue);

    await tester.tap(find.byKey(const Key('soundOnRestCompleteSwitch')));
    await pump(tester);

    final after = await container.read(soundEnabledSettingProvider.future);
    expect(after, isFalse);
    expect(prefs.getBool(soundEnabledPrefsKey), isFalse);
  });

  testWidgets(
      'changing the weight-unit SegmentedButton to lb updates settingsProvider',
      (tester) async {
    await tester.pumpWidget(harness());
    await pump(tester);

    expect(container.read(settingsProvider).weightUnit, 'kg');

    await tester.tap(find.text('lb'));
    await pump(tester);

    expect(container.read(settingsProvider).weightUnit, 'lb');
  });
}
