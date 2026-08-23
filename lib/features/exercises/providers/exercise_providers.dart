import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../db/app_database.dart';
import '../data/exercise_repository.dart';

final exerciseListProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(exerciseRepositoryProvider).watchAll(),
);

final exerciseSearchQueryProvider = StateProvider<String>((ref) => '');

/// Whether the exercise library is filtered to favourites. Kept as app state
/// rather than local widget state so the list and the picker agree, and so the
/// filter survives navigating away and back mid-flow.
final exerciseFavouritesOnlyProvider = StateProvider<bool>((ref) => false);

final filteredExercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final query = ref.watch(exerciseSearchQueryProvider);
  final favouritesOnly = ref.watch(exerciseFavouritesOnlyProvider);
  return ref.watch(exerciseRepositoryProvider).watchSearch(
        query,
        favouritesOnly: favouritesOnly,
      );
});

final exerciseTaxonomyProvider =
    FutureProvider.family<ExerciseTaxonomy, String>((ref, exerciseId) {
  return ref.watch(exerciseRepositoryProvider).taxonomy(exerciseId);
});

/// Body parts for every exercise in one query, so list rows can render their
/// subtitle without a query each.
final bodyPartsByExerciseProvider =
    StreamProvider<Map<String, List<BodyPart>>>((ref) {
  return ref.watch(exerciseRepositoryProvider).watchBodyPartsByExercise();
});

final exerciseByIdProvider =
    FutureProvider.family<Exercise?, String>((ref, id) async {
  return ref.watch(exerciseRepositoryProvider).findById(id);
});
