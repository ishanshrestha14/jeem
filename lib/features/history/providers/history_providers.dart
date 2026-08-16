import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sessions/data/session_models.dart';
import '../../sessions/data/session_repository.dart';

final completedSessionsProvider = StreamProvider<List<ActiveSession>>(
  (ref) => ref.watch(sessionRepositoryProvider).watchCompletedSessions(),
);
