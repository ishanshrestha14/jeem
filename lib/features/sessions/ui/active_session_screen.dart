import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../db/app_database.dart';
import '../providers/active_session_controller.dart';
import 'widgets/rest_bar.dart';
import 'widgets/session_exercise_card.dart';
import 'widgets/session_progress_header.dart';

enum _SessionMenuAction { settings, reorder, pauseResume, finish, cancel }

/// The screen used mid-workout, one-handed, between sets (PRD §9.4).
/// Renders the live session snapshot from [activeSessionControllerProvider]
/// and every set row; all mutations go through the controller — this screen
/// never writes to `SessionRepository` directly.
class ActiveSessionScreen extends ConsumerStatefulWidget {
  const ActiveSessionScreen({super.key});

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  // One GlobalKey per exercise so a later task can
  // `Scrollable.ensureVisible` the focused target.
  final Map<String, GlobalKey> _cardKeys = {};

  final Set<String> _expandedIds = {};
  bool _expandedHydrated = false;

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Repaints the elapsed-time chip in the app bar once a second. Purely a
    // repaint signal — elapsed time is always recomputed from
    // `session.elapsed(now)`, never stored in state.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  GlobalKey _keyFor(String exerciseId) =>
      _cardKeys.putIfAbsent(exerciseId, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeSessionControllerProvider);
    return PopScope(
      canPop: true,
      child: async.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        data: (state) {
          if (state == null) {
            // The session ended (finished/cancelled) from within this
            // screen — nothing left to render; hand control back to Home.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && context.canPop()) context.pop();
            });
            return const Scaffold(body: SizedBox.shrink());
          }
          return _buildScaffold(context, state);
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, ActiveSessionState state) {
    final session = state.session;
    final weightUnit = session.session.weightUnit;
    final currentSetId = state.currentTarget?.setId;

    if (!_expandedHydrated) {
      _expandedHydrated = true;
      final current = state.currentTarget;
      if (current != null) _expandedIds.add(current.sessionExerciseId);
    }

    final completed =
        session.exercises.where((e) => e.isComplete).toList(growable: false);
    final pending = pendingExercises(session);
    final currentExerciseId = state.currentTarget?.sessionExerciseId;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                session.session.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              mmss(session.elapsed(DateTime.now())),
              style: AppTheme.elapsedTime.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_SessionMenuAction>(
            onSelected: (action) => _handleMenu(context, state, action),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _SessionMenuAction.settings,
                child: Text('Session settings'),
              ),
              const PopupMenuItem(
                value: _SessionMenuAction.reorder,
                child: Text('Reorder exercises'),
              ),
              PopupMenuItem(
                value: _SessionMenuAction.pauseResume,
                child: Text(
                  session.session.status == SessionStatus.paused
                      ? 'Resume'
                      : 'Pause',
                ),
              ),
              const PopupMenuItem(
                value: _SessionMenuAction.finish,
                child: Text('Finish'),
              ),
              const PopupMenuItem(
                value: _SessionMenuAction.cancel,
                child: Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _ProgressHeaderDelegate(session: session),
          ),
          if (completed.isNotEmpty)
            SliverToBoxAdapter(
              child: ExpansionTile(
                title: Text('Completed (${completed.length})'),
                initiallyExpanded: false,
                children: [
                  for (final entry in completed)
                    SessionExerciseCard(
                      key: ValueKey('completed-${entry.exercise.id}'),
                      cardKey: _keyFor(entry.exercise.id),
                      entry: entry,
                      expanded: false,
                      weightUnit: weightUnit,
                      currentSetId: currentSetId,
                      onToggleExpand: () {},
                    ),
                ],
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            sliver: SliverList.list(
              children: [
                for (final entry in pending)
                  SessionExerciseCard(
                    key: ValueKey(entry.exercise.id),
                    cardKey: _keyFor(entry.exercise.id),
                    entry: entry,
                    expanded: _expandedIds.contains(entry.exercise.id) ||
                        entry.exercise.id == currentExerciseId,
                    weightUnit: weightUnit,
                    currentSetId: currentSetId,
                    canDoLater: entry.exercise.id != pending.last.exercise.id,
                    onToggleExpand: () => setState(() {
                      if (!_expandedIds.remove(entry.exercise.id)) {
                        _expandedIds.add(entry.exercise.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: state.rest.isActive || state.restJustFinished
          ? const RestBar()
          : null,
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    ActiveSessionState state,
    _SessionMenuAction action,
  ) async {
    final controller = ref.read(activeSessionControllerProvider.notifier);
    switch (action) {
      case _SessionMenuAction.settings:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session settings coming soon')),
        );
      case _SessionMenuAction.reorder:
        await _showReorderSheet(context, state.session);
      case _SessionMenuAction.pauseResume:
        if (state.session.session.status == SessionStatus.paused) {
          await controller.resumeSession();
        } else {
          await controller.pauseSession();
        }
      case _SessionMenuAction.finish:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Finish workout?'),
            content: const Text('This ends the session.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Finish'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) await controller.finish();
      case _SessionMenuAction.cancel:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cancel workout?'),
            content: const Text(
              'This discards the session. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep going'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) await controller.cancelSession();
    }
  }

  Future<void> _showReorderSheet(
    BuildContext context,
    ActiveSession session,
  ) {
    final controller = ref.read(activeSessionControllerProvider.notifier);
    final pending = pendingExercises(session);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.6,
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            onReorder: (oldIndex, newIndex) =>
                controller.reorder(oldIndex, newIndex),
            itemBuilder: (_, i) => ListTile(
              key: ValueKey(pending[i].exercise.id),
              title: Text(pending[i].exercise.name),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ProgressHeaderDelegate({required this.session});

  final ActiveSession session;

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // A SliverPersistentHeader requires its child to exactly fill the
    // extent it reports, or the sliver geometry assertion fails — pin the
    // content's height explicitly rather than letting it size to its
    // (shorter) intrinsic content height.
    return SizedBox(
      height: maxExtent,
      child: SessionProgressHeader(session: session),
    );
  }

  @override
  bool shouldRebuild(covariant _ProgressHeaderDelegate oldDelegate) =>
      oldDelegate.session != session;
}
