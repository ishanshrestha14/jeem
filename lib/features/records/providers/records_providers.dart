import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/providers/history_providers.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/personal_records.dart';

/// Lifetime personal records, recomputed from completed sessions.
///
/// Deliberately derived rather than stored: with one user's history this is a
/// cheap pass, and a cached table would need invalidating on every set edit —
/// including edits to *completed* sets, which this app allows. Worth caching
/// once it is walking years of data, not before.
final personalRecordsProvider = Provider<List<ExerciseRecords>>((ref) {
  final sessions = ref.watch(historyProvider).valueOrNull ?? const [];
  // Watched, not read: switching units in Settings must restate every record
  // immediately. Without this the provider only recomputes when history
  // changes, leaving records visibly stale in the new unit (T-026).
  final unit = ref.watch(settingsProvider).weightUnit;
  return computePersonalRecords(sessions, displayUnit: unit);
});
