import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A device-wide (not per-session) preference: whether the screen should
/// stay awake while a workout is active. Backed directly by
/// `shared_preferences` rather than a `WorkoutSessions` column — "keep the
/// screen on during workouts" is a behaviour preference, not a fact about
/// any one session, so it shouldn't need re-setting per session and
/// shouldn't disappear when a session ends.
///
/// Task 21 later replaces this with a full `SettingsRepository` covering
/// every app preference; this is deliberately the minimum honest storage for
/// just this one setting now (Ruling 42) — Task 15's session settings sheet
/// left this switch out specifically because nothing backed it yet. Task 17
/// is what backs it: this file, plus [WakelockService] which reads it.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

const keepScreenOnPrefsKey = 'keepScreenOnDuringWorkout';

class KeepScreenOnSetting extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(keepScreenOnPrefsKey) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(keepScreenOnPrefsKey, value);
    state = AsyncData(value);
  }
}

final keepScreenOnSettingProvider =
    AsyncNotifierProvider<KeepScreenOnSetting, bool>(KeepScreenOnSetting.new);
