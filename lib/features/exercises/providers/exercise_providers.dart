import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../data/exercise_repository.dart';

final exerciseListProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchAll(),
);

final exerciseSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredExercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final query = ref.watch(exerciseSearchQueryProvider);
  return ref.watch(exerciseRepositoryProvider).watchSearch(query);
});

final exerciseByIdProvider =
    FutureProvider.family<Exercise?, String>((ref, id) async {
  return ref.watch(exerciseRepositoryProvider).findById(id);
});
