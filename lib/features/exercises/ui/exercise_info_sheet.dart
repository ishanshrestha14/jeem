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
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.fitness_center,
                            size: 48, color: theme.colorScheme.outline),
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
