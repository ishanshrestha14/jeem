import 'package:shared_preferences/shared_preferences.dart';

/// The genuinely new, device-wide settings this task introduces.
///
/// Deliberately NOT `soundEnabled`/`hapticsEnabled`/`keepScreenOn` — those
/// already exist as independent, already-shipped `shared_preferences`-backed
/// providers (`soundEnabledSettingProvider`/`hapticsEnabledSettingProvider`
/// in `core/services/session_feedback_settings.dart`,
/// `keepScreenOnSettingProvider` in `core/services/keep_screen_on_setting.dart`)
/// wired into `ActiveSessionController`/`WakelockService` and covered by
/// their own tests. Duplicating their storage here would create a second
/// source of truth for the same three booleans, so this model carries only
/// the two settings that don't have a home yet.
class AppSettings {
  const AppSettings({
    required this.weightUnit,
    required this.defaultRestSeconds,
  });

  const AppSettings.defaults()
      : weightUnit = 'kg',
        defaultRestSeconds = 90;

  final String weightUnit;
  final int defaultRestSeconds;

  AppSettings copyWith({String? weightUnit, int? defaultRestSeconds}) {
    return AppSettings(
      weightUnit: weightUnit ?? this.weightUnit,
      defaultRestSeconds: defaultRestSeconds ?? this.defaultRestSeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.weightUnit == weightUnit &&
      other.defaultRestSeconds == defaultRestSeconds;

  @override
  int get hashCode => Object.hash(weightUnit, defaultRestSeconds);
}

/// Persists [AppSettings] via `shared_preferences`. Constructed with an
/// already-resolved [SharedPreferences] instance (rather than a
/// `Future<SharedPreferences>`) so [load] can run synchronously inside
/// `main()` before `runApp`, per this task's architecture: `settingsProvider`
/// must be hydrated up front so every other provider can read it
/// synchronously.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _weightUnitKey = 'settings.weightUnit';
  static const _defaultRestSecondsKey = 'settings.defaultRestSeconds';

  Future<AppSettings> load() async {
    const defaults = AppSettings.defaults();
    return AppSettings(
      weightUnit: _prefs.getString(_weightUnitKey) ?? defaults.weightUnit,
      defaultRestSeconds:
          _prefs.getInt(_defaultRestSecondsKey) ?? defaults.defaultRestSeconds,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_weightUnitKey, settings.weightUnit);
    await _prefs.setInt(_defaultRestSecondsKey, settings.defaultRestSeconds);
  }
}
