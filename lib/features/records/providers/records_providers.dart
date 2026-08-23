import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/providers/history_providers.dart';
import '../data/personal_records.dart';

/// Lifetime personal records, recomputed from completed sessions.
///
/// Deliberately derived rather than stored: with one user's history this is a
/// cheap pass, and a cached table would need invalidating on every set edit —
/// including edits to *completed* sets, which this app allows. Worth caching
/// once it is walking years of data, not before.
final personalRecordsProvider = Provider<List<ExerciseRecords>>((ref) {
  final sessions = ref.watch(historyProvider).valueOrNull ?? const [];
  return computePersonalRecords(sessions);
});
