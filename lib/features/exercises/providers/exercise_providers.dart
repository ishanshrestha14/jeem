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

/// The body part the library is filtered to, or null for all of them (S-026).
///
/// App state rather than local widget state, for the same reason as
/// [exerciseFavouritesOnlyProvider]: the list and the picker must agree, and
/// the filter should survive navigating away mid-flow.
final exerciseBodyPartFilterProvider = StateProvider<BodyPart?>((ref) => null);

final filteredExercisesProvider = StreamProvider<List<Exercise>>((ref) {
  final query = ref.watch(exerciseSearchQueryProvider);
  final favouritesOnly = ref.watch(exerciseFavouritesOnlyProvider);
  final bodyPart = ref.watch(exerciseBodyPartFilterProvider);
  final stream = ref.watch(exerciseRepositoryProvider).watchSearch(
        query,
        favouritesOnly: favouritesOnly,
      );
  if (bodyPart == null) return stream;

  // Filtered against the map `bodyPartsByExerciseProvider` already loads for
  // the list's subtitles, rather than a second query per exercise.
  //
  // An exercise with no body parts is excluded by any filter. Untagged is the
  // normal state early on (ADR-006), so this genuinely hides things — but a
  // filter that also returned everything untagged would not be a filter.
  final byExercise = ref.watch(bodyPartsByExerciseProvider).valueOrNull;
  // Not yet loaded: pass through unfiltered rather than treating "no data" as
  // "nothing matches". Filtering against an empty map would empty the list for
  // a frame and read as "you have no chest exercises", which is a lie the user
  // has no way to distinguish from the truth.
  if (byExercise == null) return stream;

  return stream.map((rows) => [
        for (final e in rows)
          if ((byExercise[e.id] ?? const []).contains(bodyPart)) e,
      ]);
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
