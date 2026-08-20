import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'db/app_database.dart';
import 'features/exercises/data/exercise_repository.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.open();
  await ExerciseRepository(db).seedIfEmpty();

  // Hydrated synchronously here, before `runApp`, so `settingsProvider` is
  // never an `AsyncValue` anywhere else in the app — `startWorkout` and the
  // template editor's draft-creation both need `weightUnit`/
  // `defaultRestSeconds` as a plain synchronous read.
  final prefs = await SharedPreferences.getInstance();
  final settingsRepository = SettingsRepository(prefs);
  final initialSettings = await settingsRepository.load();

  // Initialise once at startup (registers the notification channel and
  // pulls in timezone data for `zonedSchedule`) rather than lazily on first
  // use — by the time a session starts and might schedule a rest
  // notification, the plugin must already be ready.
  //
  // Guarded: a plugin/timezone-init failure must degrade to "no rest
  // notifications" rather than prevent the app from launching at all. The
  // service is still handed to the ProviderScope — every call site routes
  // through `ActiveSessionController._safe`, so an uninitialised plugin
  // throwing later is already contained.
  final notificationService = NotificationService();
  try {
    await notificationService.init();
  } catch (e) {
    debugPrint('NotificationService.init() failed; continuing without '
        'rest notifications: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notificationService),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        settingsProvider.overrideWith(() => SettingsNotifier(initialSettings)),
      ],
      child: const GymFlowApp(),
    ),
  );
}
