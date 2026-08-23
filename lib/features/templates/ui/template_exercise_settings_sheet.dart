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
    // Flush, don't discard: a pending debounced note edit is real user
    // input. `widget.onChanged` is a plain closure (not tied to `ref`), so
    // it's safe to call here — just skip `setState`, which would throw once
    // the widget is being torn down.
    if (_notesDebounce?.isActive ?? false) {
      _notesDebounce!.cancel();
      final value = _notesController.text.trim();
      _config =
          _config.copyWith(notes: Value(value.isEmpty ? null : value));
      widget.onChanged(_config);
    }
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
            const SizedBox(height: 4),
            // Set count, RIR and duration moved out in schema v6: they are
            // per *set* now, edited in the planned-sets table where the
            // numbers are visible (S-028). What is left here is the
            // configuration that genuinely applies to the whole exercise.
            Text(
              'Sets, reps and weight are planned per set.',
              style: theme.textTheme.bodySmall,
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
