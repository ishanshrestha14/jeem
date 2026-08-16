import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/semantic_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../sessions/data/session_repository.dart';
import '../data/template_models.dart';
import '../data/template_repository.dart';
import '../providers/template_providers.dart';

enum _StartChoice { resume, discard }

/// Starts a session from [templateId] and navigates to it. If a session is
/// already running, offers to resume it or discard it in favour of the new
/// one, rather than silently starting a second session. Goes through
/// [sessionRepositoryProvider] directly (there is no controller yet before
/// a session exists to drive one).
Future<void> _startWorkout(
  BuildContext context,
  WidgetRef ref,
  String templateId,
) async {
  final repo = ref.read(sessionRepositoryProvider);
  final active = await repo.watchActiveSession().first;
  if (active != null) {
    if (!context.mounted) return;
    final choice = await showDialog<_StartChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Workout already in progress'),
        content: Text('"${active.session.name}" is still running.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_StartChoice.resume),
            child: const Text('Resume the running session'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_StartChoice.discard),
            child: const Text('Discard it and start this one'),
          ),
        ],
      ),
    );
    if (choice == null) return;
    if (choice == _StartChoice.resume) {
      if (context.mounted) context.push('/session');
      return;
    }
    await repo.cancelSession(active.session.id);
  }
  await repo.startFromTemplate(templateId, weightUnit: 'kg');
  if (context.mounted) context.push('/session');
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(templateSummariesProvider);
    final active = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/templates/new'),
        icon: const Icon(Icons.add),
        label: const Text('New workout'),
      ),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          final resumeBanner = active.maybeWhen(
            data: (session) => session == null
                ? null
                : Card(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text('Resume "${session.session.name}"'),
                      subtitle: const Text('You have a workout in progress'),
                      onTap: () => context.push('/session'),
                    ),
                  ),
            orElse: () => null,
          );

          if (rows.isEmpty) {
            return Column(
              children: [
                ?resumeBanner,
                Expanded(
                  child: EmptyState(
                    icon: Icons.fitness_center,
                    title: 'No workouts yet',
                    message:
                        'Build a template with your exercises so you can start a workout in seconds.',
                    actionLabel: 'Create your first workout',
                    onAction: () => context.push('/templates/new'),
                  ),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: rows.length + (resumeBanner == null ? 0 : 1),
            itemBuilder: (_, i) {
              if (resumeBanner != null) {
                if (i == 0) return resumeBanner;
                return _TemplateCard(summary: rows[i - 1]);
              }
              return _TemplateCard(summary: rows[i]);
            },
          );
        },
      ),
    );
  }
}

class _TemplateCard extends ConsumerWidget {
  const _TemplateCard({required this.summary});

  final TemplateSummary summary;

  String _pluralise(int count, String noun) =>
      count == 1 ? '1 $noun' : '$count ${noun}s';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.extension<SemanticColors>()!.muted;
    final template = summary.template;
    final canStart = summary.exerciseCount > 0;

    var metadata =
        '${_pluralise(summary.exerciseCount, 'exercise')} · ${_pluralise(summary.totalSets, 'set')}';
    if (summary.lastPerformedAt != null) {
      metadata +=
          ' · Last: ${DateFormat.MMMd().format(summary.lastPerformedAt!)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/templates/${template.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(template.name, style: theme.textTheme.titleLarge),
                  ),
                  PopupMenuButton<_TemplateAction>(
                    onSelected: (action) =>
                        _handleAction(context, ref, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: _TemplateAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: _TemplateAction.duplicate,
                        child: Text('Duplicate'),
                      ),
                      PopupMenuItem(
                        value: _TemplateAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                metadata,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: canStart
                      ? () => _startWorkout(context, ref, template.id)
                      : null,
                  child: const Text('Start'),
                ),
              ),
              if (!canStart) ...[
                const SizedBox(height: 4),
                Text(
                  'Add an exercise before you can start',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _TemplateAction action,
  ) async {
    final repo = ref.read(templateRepositoryProvider);
    switch (action) {
      case _TemplateAction.edit:
        context.push('/templates/${summary.template.id}');
      case _TemplateAction.duplicate:
        await repo.duplicateTemplate(summary.template.id);
      case _TemplateAction.delete:
        final confirmed = await confirmDestructive(
          context,
          title: 'Delete "${summary.template.name}"?',
          message:
              'This removes the workout template. This cannot be undone.',
          confirmLabel: 'Delete',
        );
        if (confirmed) {
          await repo.deleteTemplate(summary.template.id);
        }
    }
  }
}

enum _TemplateAction { edit, duplicate, delete }
