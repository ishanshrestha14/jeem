import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/semantic_colors.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/numeric_field.dart';
import '../../../db/app_database.dart';
import '../../exercises/ui/exercise_info_sheet.dart';
import '../../exercises/ui/exercise_picker_sheet.dart';
import '../data/template_models.dart';
import '../data/template_repository.dart';
import '../providers/template_providers.dart';
import 'template_exercise_settings_sheet.dart';

/// Assembles a workout template: name, notes, defaults, and the ordered
/// list of exercises. When [templateId] is null, a draft template is
/// created immediately in [initState] so every field can persist as it is
/// edited — there is no separate "save" step anywhere in this screen.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, this.templateId});

  final String? templateId;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  late final bool _isDraft = widget.templateId == null;
  String? _templateId;

  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  Timer? _nameDebounce;
  Timer? _notesDebounce;
  Timer? _restDebounce;

  bool _metaHydrated = false;

  /// Last-known template row and exercise count, cached from the stream so
  /// async callbacks (back-out cleanup, add-exercise) that run outside of
  /// `build` have something to read.
  WorkoutTemplate? _template;
  int _exerciseCount = 0;
  bool _handlingBack = false;

  @override
  void initState() {
    super.initState();
    _templateId = widget.templateId;
    if (_templateId == null) {
      _createDraft();
    }
  }

  Future<void> _createDraft() async {
    final created =
        await ref.read(templateRepositoryProvider).createTemplate(name: '');
    if (!mounted) return;
    setState(() => _templateId = created.id);
  }

  @override
  void dispose() {
    _nameDebounce?.cancel();
    _notesDebounce?.cancel();
    _restDebounce?.cancel();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _hydrateMeta(WorkoutTemplate template) {
    if (_metaHydrated) return;
    _metaHydrated = true;
    _nameController.text = template.name;
    _notesController.text = template.notes ?? '';
  }

  Future<void> _persistTemplate(
    WorkoutTemplate Function(WorkoutTemplate) fn,
  ) async {
    final current = _template;
    if (current == null) return;
    await ref.read(templateRepositoryProvider).updateTemplate(fn(current));
  }

  void _onNameChanged(String value) {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 300), () {
      _persistTemplate((t) => t.copyWith(name: value.trim()));
    });
  }

  void _onNotesChanged(String value) {
    _notesDebounce?.cancel();
    _notesDebounce = Timer(const Duration(milliseconds: 300), () {
      _persistTemplate(
        (t) => t.copyWith(
          notes: Value(value.trim().isEmpty ? null : value.trim()),
        ),
      );
    });
  }

  void _onDefaultRestChanged(num? value) {
    _restDebounce?.cancel();
    final seconds = (value ?? 90).toInt();
    _restDebounce = Timer(const Duration(milliseconds: 300), () {
      _persistTemplate((t) => t.copyWith(defaultRestSeconds: seconds));
    });
  }

  Future<void> _handleBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    final tid = _templateId;
    // An untouched draft (blank name, no exercises) is discarded on the way
    // out so it never litters Home with an empty workout.
    if (_isDraft &&
        tid != null &&
        _nameController.text.trim().isEmpty &&
        _exerciseCount == 0) {
      await ref.read(templateRepositoryProvider).deleteTemplate(tid);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addExercise() async {
    final tid = _templateId;
    if (tid == null) return;
    final exerciseId = await showExercisePickerSheet(context);
    if (exerciseId == null || !mounted) return;
    await ref.read(templateRepositoryProvider).addExercise(
          templateId: tid,
          exerciseId: exerciseId,
          restSeconds: _template?.defaultRestSeconds,
        );
  }

  Future<void> _removeExercise(TemplateExerciseWithExercise te) async {
    final tid = _templateId;
    if (tid == null) return;
    final repo = ref.read(templateRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.removeTemplateExercise(te.config.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${te.name} removed'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.addExercise(
            templateId: tid,
            exerciseId: te.exercise.id,
            targetSets: te.config.targetSets,
            restSeconds: te.config.restSeconds,
            defaultRir: te.config.defaultRir,
            defaultDurationSeconds: te.config.defaultDurationSeconds,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tid = _templateId;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: tid == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : Consumer(
              builder: (context, ref, _) {
                final async = ref.watch(templateProvider(tid));
                return async.when(
                  loading: () => const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
                  data: (data) {
                    if (data == null) {
                      return const Scaffold(
                        body: Center(child: Text('Template not found')),
                      );
                    }
                    _template = data.template;
                    _exerciseCount = data.exercises.length;
                    _hydrateMeta(data.template);
                    return _buildScaffold(context, data);
                  },
                );
              },
            ),
    );
  }

  Widget _buildScaffold(BuildContext context, TemplateWithExercises data) {
    final exercises = data.exercises;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        // `PopScope(canPop: false)` below hides Scaffold's auto-detected
        // back button (it consults the same pop disposition), so the
        // leading back control is spelled out explicitly here and routed
        // through the same cleanup path as the system back gesture.
        leading: BackButton(onPressed: _handleBack),
        title: const Text('Edit workout'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              // Wired up in Task 9 once the session repository exists.
              onPressed: exercises.isNotEmpty ? () {} : null,
              child: const Text('Start workout'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Workout name'),
            onChanged: _onNameChanged,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 2,
            maxLines: 4,
            onChanged: _onNotesChanged,
          ),
          const SizedBox(height: 16),
          NumericField(
            label: 'Default rest',
            value: data.template.defaultRestSeconds,
            min: 0,
            max: 3600,
            suffix: 's',
            onChanged: _onDefaultRestChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-focus next set'),
            value: data.template.autoFocusNextSet,
            onChanged: (v) =>
                _persistTemplate((t) => t.copyWith(autoFocusNextSet: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-focus next exercise'),
            value: data.template.autoFocusNextExercise,
            onChanged: (v) => _persistTemplate(
              (t) => t.copyWith(autoFocusNextExercise: v),
            ),
          ),
          const SizedBox(height: 24),
          Text('Exercises', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Add exercises to build this workout.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: exercises.length,
              // Forward raw indices — TemplateRepository.reorderExercises
              // normalises the downward-drag off-by-one internally.
              onReorder: (oldIndex, newIndex) => ref
                  .read(templateRepositoryProvider)
                  .reorderExercises(data.template.id, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final te = exercises[index];
                return _ExerciseRow(
                  key: ValueKey(te.config.id),
                  index: index,
                  item: te,
                  onRemove: () => _removeExercise(te),
                );
              },
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addExercise,
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends ConsumerWidget {
  const _ExerciseRow({
    required super.key,
    required this.index,
    required this.item,
    required this.onRemove,
  });

  final int index;
  final TemplateExerciseWithExercise item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).extension<SemanticColors>()!.muted;
    return ListTile(
      title: Row(
        children: [
          Flexible(child: Text(item.name)),
          if (item.isArchived) ...[
            const SizedBox(width: 8),
            Chip(
              label: const Text('Archived'),
              backgroundColor: muted,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
      subtitle: Text(
        '${item.config.targetSets} sets · '
        '${formatDurationSeconds(item.config.restSeconds)} rest',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Exercise info',
            onPressed: () => showExerciseInfoSheet(
              context,
              name: item.exercise.name,
              loggingType: item.loggingType,
              description: item.exercise.description,
              notes: item.exercise.notes,
              imagePath: item.exercise.imagePath,
              category: item.exercise.category,
              isArchived: item.isArchived,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Exercise settings',
            onPressed: () => showTemplateExerciseSettings(
              context,
              config: item.config,
              loggingType: item.loggingType,
              onChanged: (updated) => ref
                  .read(templateRepositoryProvider)
                  .updateTemplateExercise(updated),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Remove',
            onPressed: onRemove,
          ),
          ReorderableDragStartListener(
            index: index,
            child: Container(
              width: 48,
              height: 48,
              color: Colors.transparent,
              alignment: Alignment.center,
              child: const Icon(Icons.drag_handle),
            ),
          ),
        ],
      ),
    );
  }
}
