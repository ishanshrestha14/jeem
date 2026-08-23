import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../db/app_database.dart';
import '../providers/exercise_providers.dart';

Future<void> showExerciseInfoSheet(
  BuildContext context, {
  required String name,
  required LoggingType loggingType,
  String? description,
  String? notes,
  String? imagePath,
  Equipment? equipment,
  /// When given, the sheet loads and shows the exercise's body parts and
  /// primary/secondary muscles. Omitted by callers working from a session
  /// snapshot, which has no library row to look up.
  String? exerciseId,
  bool isArchived = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final hasImage = imagePath != null && File(imagePath).existsSync();
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (equipment != null)
                    Chip(label: Text(equipmentLabel(equipment))),
                  Chip(
                    label: Text(
                      loggingType == LoggingType.durationOnly
                          ? 'Duration'
                          : 'Strength',
                    ),
                  ),
                  if (isArchived)
                    Chip(
                      label: const Text('Archived'),
                      backgroundColor:
                          theme.extension<SemanticColors>()!.muted,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasImage
                    ? Image.file(File(imagePath), height: 200,
                        width: double.infinity, fit: BoxFit.cover)
                    : Container(
                        height: 140,
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: theme.colorScheme.surfaceContainerHighest,
                        // Icon plus a sentence, rather than a bare icon —
                        // an unlabelled grey square reads as a failed image
                        // load rather than "this exercise has no photo".
                        // No CTA here on purpose: this sheet is read-only at
                        // every call site (session card, picker, template
                        // row); adding a photo belongs to the editor, which
                        // carries that CTA itself.
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported_outlined,
                                size: 40, color: theme.colorScheme.outline),
                            const SizedBox(height: 8),
                            Text(
                              'No photo for this exercise yet. Add one from '
                              'the exercise library.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              if (exerciseId != null)
                _TargetMuscles(exerciseId: exerciseId),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Description', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodyLarge),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Notes', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(notes, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Body parts plus primary/secondary muscles, mirroring the reference app's
/// "Target Muscles" legend (S-025): each role labelled, with a coloured dot
/// tying it to its meaning. Renders nothing at all when the exercise is
/// untagged — the common case early on (ADR-006), where an empty "Primary"
/// heading would read as a bug.
class _TargetMuscles extends ConsumerWidget {
  const _TargetMuscles({required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(exerciseTaxonomyProvider(exerciseId));
    final t = async.valueOrNull;
    if (t == null || t.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Target muscles', style: theme.textTheme.titleSmall),
        if (t.bodyParts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final b in t.bodyParts)
                Chip(
                  label: Text(bodyPartLabel(b)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        if (t.primary.isNotEmpty)
          _MuscleGroup(
            label: 'Primary',
            colour: theme.colorScheme.error,
            muscles: t.primary,
          ),
        if (t.secondary.isNotEmpty)
          _MuscleGroup(
            label: 'Secondary',
            colour: theme.colorScheme.primary,
            muscles: t.secondary,
          ),
      ],
    );
  }
}

class _MuscleGroup extends StatelessWidget {
  const _MuscleGroup({
    required this.label,
    required this.colour,
    required this.muscles,
  });

  final String label;
  final Color colour;
  final List<Muscle> muscles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = muscles.map(muscleLabel).toList()..sort();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(names.join(', '), style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
