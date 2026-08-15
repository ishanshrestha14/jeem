import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/image_storage_service.dart';
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

  /// Managed image files superseded by a replace or a remove. Deletion is
  /// deferred until save so cancelling never orphans a file the database
  /// still points to.
  final List<String> _pendingImageDeletions = [];

  /// Files this editing session wrote to disk (via pickAndStore) that have
  /// not yet been committed by a successful save. These are the mirror image
  /// of `_pendingImageDeletions`: "delete if I DON'T save" rather than
  /// "delete if I DO save". Cleared (without deleting) once a save commits
  /// them; deleted, on abandonment, by `_discardSessionImages`.
  final List<String> _sessionCreatedPaths = [];

  Future<void> _discardSessionImages() async {
    if (_sessionCreatedPaths.isEmpty) return;
    final service = ref.read(imageStorageServiceProvider);
    final paths = List<String>.of(_sessionCreatedPaths);
    _sessionCreatedPaths.clear();
    for (final path in paths) {
      await service.deleteIfManaged(path);
    }
  }

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

  Future<void> _pickImage(ImageSource source) async {
    final service = ref.read(imageStorageServiceProvider);
    String? picked;
    try {
      picked = await service.pickAndStore(source: source);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Could not open the camera: $e'
                : 'Could not open photos: $e',
          ),
        ),
      );
      return;
    }
    if (picked == null || !mounted) return;
    final newPath = picked;
    final old = _imagePath;
    setState(() {
      if (old != null) _pendingImageDeletions.add(old);
      _sessionCreatedPaths.add(newPath);
      _imagePath = newPath;
    });
  }

  void _removeImage() {
    final old = _imagePath;
    if (old == null) return;
    setState(() {
      _pendingImageDeletions.add(old);
      _imagePath = null;
    });
  }

  Future<void> _cancel() async {
    await _discardSessionImages();
    if (!mounted) return;
    Navigator.of(context).maybePop();
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

      if (_pendingImageDeletions.isNotEmpty) {
        final service = ref.read(imageStorageServiceProvider);
        for (final path in _pendingImageDeletions) {
          await service.deleteIfManaged(path);
        }
        _pendingImageDeletions.clear();
      }
      // Whatever remains as _imagePath (if anything) is now committed to the
      // database — it must survive, not be swept up as an abandoned pick.
      _sessionCreatedPaths.clear();

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
    // Covers the AppBar back button and the system back gesture, which
    // otherwise bypass the Cancel button's cleanup entirely and leak any
    // image this session picked but never saved. Cancel/Save/Archive already
    // discard or commit session images deterministically *before* calling
    // maybePop, so canPop stays true and every first-party pop proceeds
    // immediately and normally — this only ever needs to react, best-effort,
    // to a pop we didn't initiate ourselves.
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) return;
        unawaited(_discardSessionImages());
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
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
            onChoosePhoto: () => _pickImage(ImageSource.gallery),
            onTakePhoto: () => _pickImage(ImageSource.camera),
            onRemove: _removeImage,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _cancel,
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

/// Image field: shows a 16:9 preview of the stored photo (or a dashed
/// placeholder when there is none), plus buttons to choose/take a photo and,
/// when a photo is set, remove it. An exercise with no image remains fully
/// usable — the placeholder never blocks any action.
class _ImageField extends StatelessWidget {
  const _ImageField({
    required this.imagePath,
    required this.onChoosePhoto,
    required this.onTakePhoto,
    required this.onRemove,
  });

  final String? imagePath;
  final VoidCallback onChoosePhoto;
  final VoidCallback onTakePhoto;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final path = imagePath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: path == null
                ? _DashedPlaceholder(
                    color: theme.colorScheme.outline,
                    fill: theme.colorScheme.surfaceContainerHighest,
                  )
                : Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
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
        if (path != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove photo'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Dashed-border placeholder shown when an exercise has no photo.
class _DashedPlaceholder extends StatelessWidget {
  const _DashedPlaceholder({required this.color, required this.fill});

  final Color color;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: fill,
        child: Icon(Icons.fitness_center, size: 40, color: color),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;
  static const _dashWidth = 6.0;
  static const _dashSpace = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final borderPath = Path()..addRRect(rrect);
    final dashedPath = Path();
    for (final metric in borderPath.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        dashedPath.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + _dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
