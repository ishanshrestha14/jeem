import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'db/app_database.dart';
import 'features/exercises/data/exercise_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.open();
  await ExerciseRepository(db).seedIfEmpty();

  // Initialise once at startup (registers the notification channel and
  // pulls in timezone data for `zonedSchedule`) rather than lazily on first
  // use — by the time a session starts and might schedule a rest
  // notification, the plugin must already be ready.
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const GymFlowApp(),
    ),
  );
}
