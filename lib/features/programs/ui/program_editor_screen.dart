import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../templates/providers/template_providers.dart';
import '../data/program_repository.dart';
import '../providers/program_providers.dart';

/// Create or edit a program: a name and an ordered list of routines (T-006).
///
/// Same shape as the template editor one level down — that screen already
/// solves "a named thing holding an ordered list of other things", and copying
/// its grammar means one fewer layout for the user to learn.
///
/// Creation happens on first save rather than on open, so backing out of a
/// blank editor leaves nothing behind.
class ProgramEditorScreen extends ConsumerStatefulWidget {
  const ProgramEditorScreen({super.key, this.programId});

  final String? programId;

  bool get isEditing => programId != null;

  @override
  ConsumerState<ProgramEditorScreen> createState() =>
      _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends ConsumerState<ProgramEditorScreen> {
  final _nameController = TextEditingController();
  String? _nameError;
  bool _hydrated = false;
  String? _createdId;

  String? get _id => widget.programId ?? _createdId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    final program =
        id == null ? null : ref.watch(programByIdProvider(id)).valueOrNull;
    if (program != null && !_hydrated) {
      _hydrated = true;
      _nameController.text = program.program.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit program' : 'New program'),
        actions: [
          if (id != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete program',
              onPressed: () => _delete(id),
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Program name',
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Routines',
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              TextButton.icon(
                onPressed: () => _addRoutine(context),
                icon: const Icon(Icons.add),
                label: const Text('Add routine'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (program == null || program.routines.isEmpty)
            // An empty program is valid — you name it before you fill it — so
            // this is an empty state with a way forward, not an error.
            const EmptyState(
              icon: Icons.list_alt_outlined,
              title: 'No routines yet',
              message:
                  'Add the routines this program cycles through, in the order '
                  'you train them.',
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: program.routines.length,
              onReorder: (oldIndex, newIndex) {
                // ReorderableListView reports the *insertion* index, which is
                // one past the target when moving down.
                final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
                unawaited(ref
                    .read(programRepositoryProvider)
                    .reorder(program.program.id, oldIndex, target));
              },
              itemBuilder: (context, i) {
                final entry = program.routines[i];
                return ListTile(
                  key: ValueKey(entry.membership.id),
                  minTileHeight: 56,
                  leading: const Icon(Icons.drag_handle),
                  title: Text(entry.template.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove from program',
                    onPressed: () => ref
                        .read(programRepositoryProvider)
                        .removeRoutine(entry.membership.id),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give the program a name');
      return;
    }
    final repo = ref.read(programRepositoryProvider);
    final id = _id;
    if (id == null) {
      final created = await repo.create(name: name);
      setState(() => _createdId = created.id);
    } else {
      await repo.rename(id, name);
    }
    if (mounted) context.pop();
  }

  Future<void> _delete(String id) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete program?',
      message: 'The routines in it are not deleted — only this grouping.',
      confirmLabel: 'Delete program',
    );
    if (!confirmed) return;
    await ref.read(programRepositoryProvider).delete(id);
    if (mounted) context.pop();
  }

  /// Adding a routine needs the program to exist, so a blank editor saves
  /// itself first rather than refusing.
  Future<void> _addRoutine(BuildContext context) async {
    var id = _id;
    if (id == null) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        setState(() => _nameError = 'Name the program before adding routines');
        return;
      }
      final created = await ref.read(programRepositoryProvider).create(name: name);
      if (!mounted) return;
      setState(() => _createdId = created.id);
      id = created.id;
    }

    final summaries = ref.read(templateSummariesProvider).valueOrNull ?? const [];
    if (!context.mounted) return;
    if (summaries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a routine first.')),
      );
      return;
    }

    final templateId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in summaries)
              ListTile(
                minTileHeight: 56,
                title: Text(s.template.name),
                subtitle: Text('${s.exerciseCount} '
                    '${s.exerciseCount == 1 ? 'exercise' : 'exercises'}'),
                onTap: () => Navigator.of(ctx).pop(s.template.id),
              ),
          ],
        ),
      ),
    );
    if (templateId == null) return;
    await ref
        .read(programRepositoryProvider)
        .addRoutine(programId: id, templateId: templateId);
  }
}

/// Shown by the Library row; kept here so the colour logic stays with the
/// program feature rather than leaking into the library widget.
Color programTileColour(BuildContext context) =>
    Theme.of(context).extension<SemanticColors>()!.surfaceHigh;
