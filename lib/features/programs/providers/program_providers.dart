import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/program_repository.dart';

final programSummariesProvider = StreamProvider<List<ProgramSummary>>(
  (ref) => ref.watch(programRepositoryProvider).watchSummaries(),
);

final programByIdProvider =
    StreamProvider.family<ProgramWithRoutines?, String>((ref, id) {
  return ref.watch(programRepositoryProvider).watchProgram(id);
});
