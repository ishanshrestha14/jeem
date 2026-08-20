import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatting.dart';
import '../../../core/widgets/empty_state.dart';
import '../../sessions/data/session_models.dart';
import '../../templates/data/template_repository.dart';
import '../../templates/providers/template_providers.dart';
import '../providers/history_providers.dart';

/// Read-only session history: a list of completed sessions, newest first.
/// There is no separate detail screen — tapping a row pushes
/// `SessionSummaryScreen(readOnly: true)`, the same screen the Finish flow
/// uses, at `/session/summary/:id?readOnly=true`. Each row also offers a
/// "Duplicate this workout as a template" overflow action when the session
/// still points at a template that exists.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: 'No completed sessions yet',
              message: 'Finish a workout and it will show up here.',
              actionLabel: 'Go to Home',
              onAction: () => context.go('/home'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => _HistoryTile(session: rows[i]),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = session.session;
    final endedAt = workout.endedAt;
    final duration = endedAt == null
        ? Duration.zero
        : endedAt.difference(workout.startedAt) -
            Duration(seconds: workout.pausedSeconds);
    final volume = session.completedVolume;

    var subtitle =
        '${DateFormat.yMMMd().format(workout.startedAt)} · ${mmss(duration)} · '
        '${session.completedSets}/${session.totalSets} sets';
    if (volume > 0) {
      subtitle += ' · ${volume.round()} ${workout.weightUnit}';
    }

    final templateId = workout.templateId;
    final templateAsync = templateId == null
        ? null
        : ref.watch(templateProvider(templateId));
    final canDuplicate = templateAsync?.valueOrNull != null;

    return ListTile(
      title: Text(workout.name),
      subtitle: Text(subtitle),
      onTap: () =>
          context.push('/session/summary/${workout.id}?readOnly=true'),
      trailing: canDuplicate
          ? PopupMenuButton<_HistoryAction>(
              onSelected: (action) =>
                  _handleAction(context, ref, action, templateId!),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _HistoryAction.duplicateTemplate,
                  child: Text('Duplicate this workout as a template'),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    _HistoryAction action,
    String templateId,
  ) async {
    switch (action) {
      case _HistoryAction.duplicateTemplate:
        final repo = ref.read(templateRepositoryProvider);
        final copy = await repo.duplicateTemplate(templateId);
        if (!context.mounted) return;
        context.push('/templates/${copy.id}');
    }
  }
}

enum _HistoryAction { duplicateTemplate }
