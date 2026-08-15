import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../db/app_database.dart';
import '../data/exercise_repository.dart';
import '../providers/exercise_providers.dart';

const _categories = [
  'Chest',
  'Back',
  'Legs',
  'Shoulders',
  'Arms',
  'Core',
  'Stretching',
  'Cardio',
  'Other',
];

class ExerciseEditorScreen extends ConsumerStatefulWidget {
  const ExerciseEditorScreen({super.key, this.exerciseId});

  final String? exerciseId;

  bool get isEditing => exerciseId != null;

  @override
  ConsumerState<ExerciseEditorScreen> createState() =>
      _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends ConsumerState<ExerciseEditorScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  String? _category;
  LoggingType _loggingType = LoggingType.strengthWeightRepsRir;
  String? _nameError;
  String? _imagePath;
  Exercise? _loaded;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _hydrate(Exercise exercise) {
    if (_initialized) return;
    _initialized = true;
    _loaded = exercise;
    _nameController.text = exercise.name;
    _descriptionController.text = exercise.description ?? '';
    _notesController.text = exercise.notes ?? '';
    _category = exercise.category;
    _loggingType = exercise.loggingType;
    _imagePath = exercise.imagePath;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });

    final repo = ref.read(exerciseRepositoryProvider);
    final description = _descriptionController.text.trim();
    final notes = _notesController.text.trim();

    try {
      if (widget.isEditing && _loaded != null) {
        await repo.update(
          _loaded!.copyWith(
            name: name,
            category: Value(_category),
            description: Value(description.isEmpty ? null : description),
            notes: Value(notes.isEmpty ? null : notes),
            loggingType: _loggingType,
            imagePath: Value(_imagePath),
          ),
        );
      } else {
        await repo.create(
          name: name,
          loggingType: _loggingType,
          category: _category,
          description: description.isEmpty ? null : description,
          notes: notes.isEmpty ? null : notes,
          imagePath: _imagePath,
        );
      }

      if (!mounted) return;
      await Navigator.of(context).maybePop();
    } finally {
      // If maybePop() actually popped this route, the widget is disposed and
      // this setState is skipped (guarded by `mounted`). If it returned
      // false (e.g. this is the root route in a test harness), Save/Cancel
      // must not stay permanently disabled.
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archive() async {
    if (_loaded == null) return;
    final confirmed = await confirmDestructive(
      context,
      title: 'Archive exercise?',
      message:
          '${_loaded!.name} will be hidden from the exercise library. You can restore it later.',
      confirmLabel: 'Archive',
    );
    if (!confirmed) return;
    if (!mounted) return;

    final exercise = _loaded!;
    final repo = ref.read(exerciseRepositoryProvider);
    // Capture the messenger before the archive/pop async gap so the undo
    // snackbar reliably shows on whatever screen ends up visible after this
    // one pops — MaterialApp provides a single ScaffoldMessenger shared by
    // both this editor and the list screen underneath it.
    final messenger = ScaffoldMessenger.of(context);

    await repo.archive(exercise.id);
    if (!mounted) return;
    Navigator.of(context).maybePop();

    messenger.showSnackBar(
      SnackBar(
        content: Text('${exercise.name} archived'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.unarchive(exercise.id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      final asyncExercise = ref.watch(exerciseByIdProvider(widget.exerciseId!));
      return asyncExercise.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Exercise')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Exercise')),
          body: Center(child: Text('$e')),
        ),
        data: (exercise) {
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Exercise')),
              body: const Center(child: Text('Exercise not found')),
            );
          }
          _hydrate(exercise);
          return _buildForm(context);
        },
      );
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit exercise' : 'New exercise'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archive',
              onPressed: _archive,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              for (final c in _categories)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 16),
          Text('Logging type', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<LoggingType>(
            segments: const [
              ButtonSegment(
                value: LoggingType.strengthWeightRepsRir,
                label: Text('Strength'),
                icon: Icon(Icons.fitness_center),
              ),
              ButtonSegment(
                value: LoggingType.durationOnly,
                label: Text('Duration'),
                icon: Icon(Icons.timer_outlined),
              ),
            ],
            selected: {_loggingType},
            onSelectionChanged: (s) =>
                setState(() => _loggingType = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            minLines: 2,
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            minLines: 2,
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          _ImageField(
            imagePath: _imagePath,
            onChoosePhoto: () {
              // TODO(Task 5): wire up the real image picker.
            },
            onTakePhoto: () {
              // TODO(Task 5): wire up the real camera capture.
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Placeholder image field. Renders the "choose photo" / "take photo"
/// affordances but does nothing on tap — Task 5 wires the real picker.
class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.imagePath,
    required this.onChoosePhoto,
    required this.onTakePhoto,
  });

  final String? imagePath;
  final VoidCallback onChoosePhoto;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.fitness_center,
            size: 40,
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onChoosePhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose photo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onTakePhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Take photo'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
