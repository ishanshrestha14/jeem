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
