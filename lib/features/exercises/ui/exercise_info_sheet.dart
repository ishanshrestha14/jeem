import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../db/app_database.dart';

Future<void> showExerciseInfoSheet(
  BuildContext context, {
  required String name,
  required LoggingType loggingType,
  String? description,
  String? notes,
  String? imagePath,
  String? category,
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
                  if (category != null) Chip(label: Text(category)),
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
