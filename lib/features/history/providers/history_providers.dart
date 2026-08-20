import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sessions/data/session_models.dart';
import '../../sessions/data/session_repository.dart';

/// Completed sessions, newest first (per
/// `SessionRepository.watchCompletedSessions`, ordered by `endedAt DESC`).
/// Shared by [HistoryScreen] and the Home tab's "last workout" section —
/// both want the same live-updating completed-session list, so this is the
/// single provider for it rather than two separate ones.
final historyProvider = StreamProvider<List<ActiveSession>>(
  (ref) => ref.watch(sessionRepositoryProvider).watchCompletedSessions(),
);
