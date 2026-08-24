import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../history/providers/history_providers.dart';
import '../domain/previous_best.dart';

/// `exerciseId ?? name` -> the best set of the last session that contained it.
///
/// Derived from [historyProvider] rather than queried, for the same reason
/// `personalRecordsProvider` is: the completed-session list is already watched
/// and already in memory, so this costs one pass and stays live through set
/// edits — including edits to *completed* sets, which this app allows and a
/// cached table would have to invalidate on.
final previousBestProvider = Provider<Map<String, PreviousBest>>((ref) {
  final sessions = ref.watch(historyProvider).valueOrNull ?? const [];
  return previousBestByExercise(sessions);
});
