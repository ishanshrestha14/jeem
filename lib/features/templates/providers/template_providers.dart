import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/template_models.dart';
import '../data/template_repository.dart';

final templateSummariesProvider = StreamProvider<List<TemplateSummary>>(
  (ref) => ref.watch(templateRepositoryProvider).watchSummaries(),
);

final templateProvider =
    StreamProvider.family<TemplateWithExercises?, String>(
  (ref, id) => ref.watch(templateRepositoryProvider).watchTemplate(id),
);

/// How long this routine's last few sessions really took (T-025).
///
/// A `FutureProvider` rather than a stream: the routine detail reads it once
/// on open, and the value only moves when a session from this routine is
/// finished, edited or deleted — none of which can happen while this screen
/// is the one in front of you.
final recentDurationsProvider =
    FutureProvider.family<List<Duration>, String>(
  (ref, templateId) =>
      ref.watch(templateRepositoryProvider).recentDurations(templateId),
);
