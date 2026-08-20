import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';

/// Overridden in `main()` (and in tests) with a real, prefs-backed
/// [SettingsRepository]. Reading it without an override is a bug — same
/// pattern as `databaseProvider`.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw UnimplementedError('settingsRepositoryProvider must be overridden'),
);

/// Holds the live [AppSettings]. [_initial] lets `main()` hand this notifier
/// its `SettingsRepository.load()` result up front (via
/// `settingsProvider.overrideWith(() => SettingsNotifier(loaded))`) so the
/// provider is synchronously hydrated everywhere else in the app — nothing
/// downstream (`startWorkout`, the template editor's default rest) has to
/// deal with an `AsyncValue`. The no-arg default keeps
/// `NotifierProvider(SettingsNotifier.new)` valid for tests/contexts that
/// don't need to override it explicitly.
class SettingsNotifier extends Notifier<AppSettings> {
  SettingsNotifier([this._initial = const AppSettings.defaults()]);

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;

  Future<void> setWeightUnit(String unit) async {
    state = state.copyWith(weightUnit: unit);
    await ref.read(settingsRepositoryProvider).save(state);
  }

  Future<void> setDefaultRestSeconds(int seconds) async {
    state = state.copyWith(defaultRestSeconds: seconds);
    await ref.read(settingsRepositoryProvider).save(state);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
