import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/keep_screen_on_setting.dart';
import '../../../core/services/wakelock_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../db/app_database.dart';
import '../providers/active_session_controller.dart';
import 'session_settings_sheet.dart';
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

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen>
    with WidgetsBindingObserver {
  // One GlobalKey per exercise so a later task can
  // `Scrollable.ensureVisible` the focused target.
  final Map<String, GlobalKey> _cardKeys = {};

  final Set<String> _expandedIds = {};
  bool _expandedHydrated = false;

  // The exercise id the screen currently treats as "the current target" for
  // forcing a card open (`SessionExerciseCard.expanded`) — updated only by
  // [_applyTargetChange]/hydration, never read straight off
  // `state.currentTarget` in `build()`. That indirection is what makes the
  // typing guard's defer actually work: `build()` force-expands whatever
  // this holds regardless of `_expandedIds`, so if it tracked the live
  // controller value directly, a deferred move would still visibly expand
  // the new target's card the moment auto-focus set it (defeating the
  // guard entirely) even though `_expandedIds`/scroll were correctly held
  // back.
  String? _appliedCurrentExerciseId;

  Timer? _ticker;

  // Catch-up state for a target-change deferred by the typing guard: the
  // move (expand/collapse/scroll) that couldn't run because a different
  // set's field was focused, held until that field loses focus.
  FocusNode? _blockingFocusNode;
  VoidCallback? _blockingFocusListener;
  String? _pendingPreviousExerciseId;
  String? _pendingTargetExerciseId;

  // Cached in `initState` for the same reason `session_settings_sheet.dart`
  // caches its controller reference: `ConsumerStatefulElement.unmount` marks
  // the element defunct before `State.dispose()` runs, so `ref.read(...)`
  // inside `dispose()` throws. A plain Dart reference sidesteps that.
  late final WakelockService _wakelock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wakelock = ref.read(wakelockServiceProvider);
    // `ref.listen` (used elsewhere in this file, inside `build`) has no
    // `fireImmediately` in this riverpod version — it only reacts to
    // changes made *after* the listener is registered, so it would miss a
    // `keepScreenOnSettingProvider` value that resolved before this screen
    // ever mounted (a very live possibility: it's a device-wide setting,
    // not scoped to this session). `ref.listenManual`, meant for exactly
    // this — registering a listener from `initState` — does support it, and
    // auto-closes when this State is disposed.
    ref.listenManual<AsyncValue<bool>>(keepScreenOnSettingProvider, (
      previous,
      next,
    ) {
      final value = next.valueOrNull;
      if (value == null) return;
      if (value) {
        _wakelock.enable();
      } else {
        _wakelock.disable();
      }
    }, fireImmediately: true);
    // Repaints the elapsed-time chip in the app bar once a second (elapsed
    // time is always recomputed from `session.elapsed(now)`, never stored in
    // state) and re-runs `RestTimer.settle` against the wall clock — the
    // ticker that turns "rest deadline quietly passed while this screen sat
    // idle" into a finished state without waiting for the next user action.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      ref.read(activeSessionControllerProvider.notifier).settle();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleResume());
    }
  }

  /// Recomputes rest from the wall clock on resume rather than trusting
  /// ticks that never fired while backgrounded (PRD §10.4, §18.3).
  ///
  /// Per Ruling 35, `ActiveSessionController.build()` is a deliberate
  /// one-shot fetch with no live DB subscription, so it will not have
  /// noticed anything that happened to the session/rest row while this
  /// screen was backgrounded (including the process having been killed and
  /// restarted). `ref.invalidate` is what forces a fresh `build()` — but the
  /// invalidate must be awaited via `.future` *before* calling `settle()`:
  /// calling `settle()` immediately after `invalidate()` targets whatever
  /// notifier instance existed a moment ago, which Riverpod has already
  /// discarded — a no-op, since the freshly-rebuilt notifier only becomes
  /// current once its `build()` future resolves. (In practice `build()`
  /// already runs the rest through `RestTimer.settle` itself — and, when that
  /// settle flips a lapsed rest to finished, resolves the same auto-focus /
  /// `restJustFinished` outcome `_handleRestFinished` would have — so this
  /// `settle()` call is a belt-and-braces no-op in the common case; it's the
  /// ordering that matters, not double-settling.)
  Future<void> _handleResume() async {
    ref.invalidate(activeSessionControllerProvider);
    await ref.read(activeSessionControllerProvider.future);
    if (!mounted) return;
    await ref.read(activeSessionControllerProvider.notifier).settle();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _clearCatchUpListener();
    WidgetsBinding.instance.removeObserver(this);
    _wakelock.disable();
    super.dispose();
  }

  GlobalKey _keyFor(String exerciseId) =>
      _cardKeys.putIfAbsent(exerciseId, GlobalKey.new);

  /// Whether [focusContext] sits anywhere inside the subtree rooted at
  /// [cardContext] — used to tell whether the currently focused text field
  /// belongs to a particular exercise card.
  bool _cardContains(BuildContext cardContext, BuildContext focusContext) {
    if (identical(cardContext, focusContext)) return true;
    var found = false;
    void visit(Element e) {
      if (found) return;
      if (identical(e, focusContext)) {
        found = true;
        return;
      }
      e.visitChildren(visit);
    }

    (cardContext as Element).visitChildren(visit);
    return found;
  }

  /// True if the currently focused widget is a field that belongs to a
  /// *different* exercise card than [targetExerciseId]. Auto-focus must
  /// never steal focus/scroll away from whatever the user is actively
  /// typing into elsewhere — losing mid-set input is worse than a delayed
  /// scroll (PRD FR-108/109).
  bool _typingElsewhere(String targetExerciseId) {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    for (final entry in _cardKeys.entries) {
      if (entry.key == targetExerciseId) continue;
      final cardContext = entry.value.currentContext;
      if (cardContext != null && _cardContains(cardContext, focusContext)) {
        return true;
      }
    }
    return false;
  }

  /// Reacts to the controller's target exercise changing (a rest finished
  /// and auto-focus moved on): expands the new current exercise's card,
  /// collapses the previously-current one, and scrolls it into view. If the
  /// user is typing in a different set's field, the move is deferred and
  /// caught up once that field loses focus (see [_armCatchUp]) rather than
  /// silently dropped — otherwise the visual reaction PRD FR-108/109
  /// promises simply never happens for that rest-finish once the user stops
  /// typing without triggering any further target change.
  void _handleTargetChanged(String? previousExerciseId, String newExerciseId) {
    if (_typingElsewhere(newExerciseId)) {
      _armCatchUp(previousExerciseId, newExerciseId);
      return;
    }
    _clearCatchUp();
    _applyTargetChange(previousExerciseId, newExerciseId);
  }

  /// Records the deferred move and, if not already listening on the field
  /// that's currently blocking it, attaches a one-shot-in-effect listener to
  /// that field's [FocusNode] so the move re-evaluates the moment it loses
  /// focus. Re-arming (the target changed again while still blocked, or the
  /// blocking field itself changed) always keeps only the *latest* pending
  /// move and at most one live listener — attached to whichever node is
  /// currently blocking — so this can't accumulate listeners or apply a
  /// stale move.
  void _armCatchUp(String? previousExerciseId, String newExerciseId) {
    _pendingPreviousExerciseId = previousExerciseId;
    _pendingTargetExerciseId = newExerciseId;

    final node = FocusManager.instance.primaryFocus;
    if (node == null) return;
    if (identical(_blockingFocusNode, node)) return;

    _clearCatchUpListener();
    _blockingFocusNode = node;
    void listener() => _onBlockingFocusChange(node);
    _blockingFocusListener = listener;
    node.addListener(listener);
  }

  /// Fires on every notification from the blocking node (focus gained or
  /// lost) — bails out unless it actually lost focus, so a node re-gaining
  /// focus mid-notification-storm can't trigger the catch-up early. Removes
  /// itself and clears the pending fields *before* doing anything else, so
  /// this can never run twice for the same deferred move even if the node
  /// notifies more than once during the same blur.
  void _onBlockingFocusChange(FocusNode node) {
    if (node.hasFocus) return;
    _clearCatchUpListener();

    final targetId = _pendingTargetExerciseId;
    final previousId = _pendingPreviousExerciseId;
    _pendingTargetExerciseId = null;
    _pendingPreviousExerciseId = null;
    if (targetId == null || !mounted) return;

    // Re-validate against the controller's latest state rather than
    // trusting the captured ids blindly — if the target moved on again
    // while this node held focus, whatever `_handleTargetChanged` call
    // that produced has either already applied its own move or re-armed
    // this same catch-up with a newer target; either way this stale one
    // must not apply.
    final currentId = ref
        .read(activeSessionControllerProvider)
        .valueOrNull
        ?.currentTarget
        ?.sessionExerciseId;
    if (currentId != targetId) return;

    if (_typingElsewhere(targetId)) {
      // Focus moved straight to another set's field rather than clearing —
      // still blocked, so re-arm against whatever node is blocking now.
      _armCatchUp(previousId, targetId);
      return;
    }
    _applyTargetChange(previousId, targetId);
  }

  void _clearCatchUpListener() {
    if (_blockingFocusNode != null && _blockingFocusListener != null) {
      _blockingFocusNode!.removeListener(_blockingFocusListener!);
    }
    _blockingFocusNode = null;
    _blockingFocusListener = null;
  }

  void _clearCatchUp() {
    _clearCatchUpListener();
    _pendingPreviousExerciseId = null;
    _pendingTargetExerciseId = null;
  }

  void _applyTargetChange(String? previousExerciseId, String newExerciseId) {
    setState(() {
      _appliedCurrentExerciseId = newExerciseId;
      if (previousExerciseId != null && previousExerciseId != newExerciseId) {
        _expandedIds.remove(previousExerciseId);
      }
      _expandedIds.add(newExerciseId);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cardContext = _cardKeys[newExerciseId]?.currentContext;
      if (cardContext == null) return;
      final reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      Scrollable.ensureVisible(
        cardContext,
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeSessionControllerProvider, (previous, next) {
      final previousId = previous?.valueOrNull?.currentTarget?.sessionExerciseId;
      final nextId = next.valueOrNull?.currentTarget?.sessionExerciseId;
      if (nextId == null || nextId == previousId) return;
      _handleTargetChanged(previousId, nextId);
    });

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
    final controller = ref.read(activeSessionControllerProvider.notifier);

    if (!_expandedHydrated) {
      _expandedHydrated = true;
      final current = state.currentTarget;
      if (current != null) {
        _expandedIds.add(current.sessionExerciseId);
        _appliedCurrentExerciseId = current.sessionExerciseId;
      }
    }

    final completed =
        session.exercises.where((e) => e.isComplete).toList(growable: false);
    final pending = pendingExercises(session);
    // Deliberately NOT `state.currentTarget?.sessionExerciseId` — see
    // `_appliedCurrentExerciseId`'s doc comment. Using the live value here
    // would force a card open the instant auto-focus set it, bypassing the
    // typing guard's defer.
    final currentExerciseId = _appliedCurrentExerciseId;

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
                for (var i = 0; i < pending.length; i++)
                  SessionExerciseCard(
                    key: ValueKey(pending[i].exercise.id),
                    cardKey: _keyFor(pending[i].exercise.id),
                    entry: pending[i],
                    expanded: _expandedIds.contains(pending[i].exercise.id) ||
                        pending[i].exercise.id == currentExerciseId,
                    weightUnit: weightUnit,
                    currentSetId: currentSetId,
                    // Only the current (pending index 0) exercise gets "Do
                    // later" — everything else already sits behind it.
                    onDoLater: (i == 0 && pending.length > 1)
                        ? () => _handleDoLater(context, state)
                        : null,
                    // Every other pending exercise can jump straight to the
                    // front with "Do next".
                    onDoNext: i > 0 ? () => controller.reorder(i, 0) : null,
                    onToggleExpand: () => setState(() {
                      if (!_expandedIds.remove(pending[i].exercise.id)) {
                        _expandedIds.add(pending[i].exercise.id);
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
        await showSessionSettingsSheet(context, ref);
      case _SessionMenuAction.reorder:
        await context.push('/session/reorder');
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

  /// "Do later" on the current exercise: send it behind every other pending
  /// exercise, then offer an inline undo. Because "Do later" is only ever
  /// wired to the pending-index-0 card, undoing it is always "send whatever
  /// is now last back to the front" — no need to track the exercise id
  /// through the round trip.
  Future<void> _handleDoLater(
    BuildContext context,
    ActiveSessionState state,
  ) async {
    final controller = ref.read(activeSessionControllerProvider.notifier);
    final pending = pendingExercises(state.session);
    if (pending.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    await controller.doLater(pending.first.exercise.id);

    final after = ref.read(activeSessionControllerProvider).valueOrNull?.session;
    final newPendingCount = after == null ? 0 : pendingExercises(after).length;
    if (newPendingCount == 0) return;

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Moved to the end'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.reorder(newPendingCount - 1, 0),
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
