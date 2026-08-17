import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'keep_screen_on_setting.dart' show sharedPreferencesProvider;

/// Device-wide preferences for Task 18's rest-complete feedback, backed by
/// `shared_preferences` — same rationale and pattern as
/// [keep_screen_on_setting.dart]'s `KeepScreenOnSetting`: these are
/// behaviour preferences, not facts about any one session, so they persist
/// across sessions rather than resetting each time.
///
/// [sharedPreferencesProvider] is defined in `keep_screen_on_setting.dart`
/// and re-used here rather than redeclared, so both files share the exact
/// same `SharedPreferences` instance in a given `ProviderContainer`.

const soundEnabledPrefsKey = 'soundOnRestComplete';
const hapticsEnabledPrefsKey = 'hapticsEnabled';
const notificationPermissionAskedPrefsKey = 'notificationPermissionAsked';

/// Sound and haptics default ON — a silent/unfelt rest timer defeats the
/// point of this task, so an MVP user who never opens settings still gets
/// the noticeable behaviour.
class SoundEnabledSetting extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(soundEnabledPrefsKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(soundEnabledPrefsKey, value);
    state = AsyncData(value);
  }
}

final soundEnabledSettingProvider =
    AsyncNotifierProvider<SoundEnabledSetting, bool>(SoundEnabledSetting.new);

class HapticsEnabledSetting extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(hapticsEnabledPrefsKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(hapticsEnabledPrefsKey, value);
    state = AsyncData(value);
  }
}

final hapticsEnabledSettingProvider =
    AsyncNotifierProvider<HapticsEnabledSetting, bool>(
        HapticsEnabledSetting.new);

/// Whether the "let GymFlow notify you" rationale sheet has already been
/// shown once (PRD FR-119: ask the first time a session starts, never on
/// first launch, never a second time regardless of the user's answer).
class NotificationAskedSetting extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    return prefs.getBool(notificationPermissionAskedPrefsKey) ?? false;
  }

  Future<void> markAsked() async {
    final prefs = await ref.read(sharedPreferencesProvider.future);
    await prefs.setBool(notificationPermissionAskedPrefsKey, true);
    state = const AsyncData(true);
  }
}

final notificationAskedSettingProvider =
    AsyncNotifierProvider<NotificationAskedSetting, bool>(
        NotificationAskedSetting.new);
