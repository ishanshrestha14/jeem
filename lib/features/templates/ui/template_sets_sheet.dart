import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/numeric_field.dart';
import '../../../db/app_database.dart';
import '../data/template_repository.dart';

/// Plans an exercise's sets: what to lift, and for how many reps (S-028).
///
/// The reference app expands this in place inside the routine editor. Here it
/// is a sheet — the editor is a reorderable list, and embedding an editable
/// table inside a drag target is a fight not worth picking for the first
/// version. The **columns and behaviour match**, which is what the pre-fill
/// depends on; only the container differs.
///
/// Every write persists immediately, like every other mutation in this app.
Future<void> showTemplateSetsSheet(
  BuildContext context, {
  required String templateExerciseId,
  required String exerciseName,
  required LoggingType loggingType,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _TemplateSetsSheet(
        templateExerciseId: templateExerciseId,
        exerciseName: exerciseName,
        loggingType: loggingType,
      ),
    ),
  );
}

class _TemplateSetsSheet extends ConsumerStatefulWidget {
  const _TemplateSetsSheet({
    required this.templateExerciseId,
    required this.exerciseName,
    required this.loggingType,
  });

  final String templateExerciseId;
  final String exerciseName;
  final LoggingType loggingType;

  @override
  ConsumerState<_TemplateSetsSheet> createState() => _TemplateSetsSheetState();
}

class _TemplateSetsSheetState extends ConsumerState<_TemplateSetsSheet> {
  List<TemplateSet> _sets = const [];
  bool _loaded = false;

  /// Reps vs. range, per exercise rather than per set — the reference puts the
  /// toggle on the `Reps` column header, not on each row (S-028). Derived from
  /// the data on load so it cannot disagree with what is stored.
  bool _useRange = false;

  TemplateRepository get _repo => ref.read(templateRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await _repo.setsFor(widget.templateExerciseId);
    if (!mounted) return;
    setState(() {
      _sets = sets;
      if (!_loaded) _useRange = sets.any((s) => s.repsMax != null);
      _loaded = true;
    });
  }

  bool get _isDuration => widget.loggingType == LoggingType.durationOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.exerciseName, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Planned sets — the session starts pre-filled with these.',
              style: theme.textTheme.bodySmall?.copyWith(color: semantic.muted),
            ),
            const SizedBox(height: 16),
            _Header(
              isDuration: _isDuration,
              useRange: _useRange,
              onToggleRange: () => setState(() => _useRange = !_useRange),
            ),
            const SizedBox(height: 4),
            if (!_loaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (var i = 0; i < _sets.length; i++)
                _SetRow(
                  key: ValueKey(_sets[i].id),
                  index: i,
                  set: _sets[i],
                  isDuration: _isDuration,
                  useRange: _useRange,
                  onChanged: _write,
                  onRemove: () async {
                    await _repo.removeSet(_sets[i].id);
                    await _load();
                  },
                ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await _repo.addSet(widget.templateExerciseId);
                  await _load();
                },
                child: const Text('+ Add Set'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _write(
    String setId, {
    Value<double?> weight = const Value.absent(),
    Value<int?> reps = const Value.absent(),
    Value<int?> repsMax = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
  }) async {
    await _repo.updateSet(
      setId,
      weight: weight,
      reps: reps,
      repsMax: repsMax,
      durationSeconds: durationSeconds,
    );
    // Deliberately no reload: the fields own their text while being typed
    // into, and rebuilding under the user would fight the keyboard.
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isDuration,
    required this.useRange,
    required this.onToggleRange,
  });

  final bool isDuration;
  final bool useRange;
  final VoidCallback onToggleRange;

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<SemanticColors>()!;
    final style = AppTheme.columnHeader.copyWith(color: semantic.muted);
    return Row(
      children: [
        SizedBox(width: 32, child: Text('Set', style: style)),
        const SizedBox(width: 8),
        if (isDuration)
          Expanded(child: Text('Duration', style: style))
        else ...[
          Expanded(flex: 3, child: Text('Kg', style: style)),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            // The caret is the reps-vs-range toggle, on the column header
            // rather than on every row — the mode belongs to the exercise.
            child: InkWell(
              onTap: onToggleRange,
              child: Row(
                children: [
                  Text(useRange ? 'Reps range' : 'Reps', style: style),
                  Icon(Icons.arrow_drop_down, size: 18, color: semantic.muted),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(width: 40),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.isDuration,
    required this.useRange,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final TemplateSet set;
  final bool isDuration;
  final bool useRange;
  final Future<void> Function(
    String setId, {
    Value<double?> weight,
    Value<int?> reps,
    Value<int?> repsMax,
    Value<int?> durationSeconds,
  }) onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final numeral = AppTheme.setNumeral.copyWith(color: theme.colorScheme.onSurface);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 32, child: Text('${index + 1}', style: numeral)),
          const SizedBox(width: 8),
          if (isDuration)
            Expanded(
              child: NumericField(
                label: 'Duration',
                value: set.durationSeconds,
                dense: true,
                style: numeral,
                onChanged: (v) => onChanged(set.id,
                    durationSeconds: Value(v?.toInt())),
              ),
            )
          else ...[
            Expanded(
              flex: 3,
              child: NumericField(
                label: 'Weight',
                value: set.weight,
                allowDecimal: true,
                dense: true,
                style: numeral,
                onChanged: (v) =>
                    onChanged(set.id, weight: Value(v?.toDouble())),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: NumericField(
                label: useRange ? 'Min reps' : 'Reps',
                value: set.reps,
                dense: true,
                style: numeral,
                onChanged: (v) => onChanged(set.id, reps: Value(v?.toInt())),
              ),
            ),
            if (useRange) ...[
              const SizedBox(width: 4),
              Text('-', style: numeral),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: NumericField(
                  label: 'Max reps',
                  value: set.repsMax,
                  dense: true,
                  style: numeral,
                  onChanged: (v) =>
                      onChanged(set.id, repsMax: Value(v?.toInt())),
                ),
              ),
            ],
          ],
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Remove set',
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}
