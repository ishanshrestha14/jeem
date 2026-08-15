import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../../core/utils/constants.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/numeric_field.dart';
import '../../../db/app_database.dart';

/// Per-exercise settings for a template: target sets, rest, default RIR or
/// default duration (depending on logging type), and a per-template note.
/// Every field persists on change via [onChanged].
Future<void> showTemplateExerciseSettings(
  BuildContext context, {
  required TemplateExercise config,
  required LoggingType loggingType,
  required ValueChanged<TemplateExercise> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _TemplateExerciseSettingsSheet(
      config: config,
      loggingType: loggingType,
      onChanged: onChanged,
    ),
  );
}

class _TemplateExerciseSettingsSheet extends StatefulWidget {
  const _TemplateExerciseSettingsSheet({
    required this.config,
    required this.loggingType,
    required this.onChanged,
  });

  final TemplateExercise config;
  final LoggingType loggingType;
  final ValueChanged<TemplateExercise> onChanged;

  @override
  State<_TemplateExerciseSettingsSheet> createState() =>
      _TemplateExerciseSettingsSheetState();
}

class _TemplateExerciseSettingsSheetState
    extends State<_TemplateExerciseSettingsSheet> {
  late TemplateExercise _config = widget.config;
  late final TextEditingController _notesController =
      TextEditingController(text: _config.notes ?? '');
  Timer? _notesDebounce;

  @override
  void dispose() {
    _notesDebounce?.cancel();
    _notesController.dispose();
    super.dispose();
  }

  void _apply(TemplateExercise Function(TemplateExercise) fn) {
    setState(() => _config = fn(_config));
    widget.onChanged(_config);
  }

  void _onNotesChanged(String value) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 300), () {
      _apply((c) => c.copyWith(notes: Value(value.trim().isEmpty ? null : value.trim())));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exercise settings', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 16),
            NumericField(
              label: 'Target sets',
              value: _config.targetSets,
              min: 1,
              max: 20,
              onChanged: (v) =>
                  _apply((c) => c.copyWith(targetSets: (v ?? 3).toInt())),
            ),
            const SizedBox(height: 16),
            NumericField(
              label: 'Rest',
              value: _config.restSeconds,
              min: 0,
              max: 3600,
              suffix: 's',
              onChanged: (v) =>
                  _apply((c) => c.copyWith(restSeconds: (v ?? 90).toInt())),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in kRestPresets)
                  ActionChip(
                    label: Text(formatDurationSeconds(preset)),
                    onPressed: () =>
                        _apply((c) => c.copyWith(restSeconds: preset)),
                  ),
              ],
            ),
            if (widget.loggingType == LoggingType.strengthWeightRepsRir) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<double?>(
                initialValue: _config.defaultRir,
                decoration: const InputDecoration(labelText: 'Default RIR'),
                items: [
                  for (final rir in kRirValues)
                    DropdownMenuItem(value: rir, child: Text(formatRir(rir))),
                ],
                onChanged: (v) =>
                    _apply((c) => c.copyWith(defaultRir: Value(v))),
              ),
            ],
            if (widget.loggingType == LoggingType.durationOnly) ...[
              const SizedBox(height: 16),
              NumericField(
                label: 'Default duration',
                value: _config.defaultDurationSeconds,
                min: 0,
                suffix: 's',
                onChanged: (v) => _apply(
                  (c) => c.copyWith(defaultDurationSeconds: Value(v?.toInt())),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Note'),
              minLines: 2,
              maxLines: 5,
              onChanged: _onNotesChanged,
            ),
          ],
        ),
      ),
    );
  }
}
