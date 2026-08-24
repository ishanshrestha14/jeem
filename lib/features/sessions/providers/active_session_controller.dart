import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/haptics_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/session_feedback_settings.dart';
import '../../../core/services/sound_service.dart';
import '../../../db/app_database.dart';
import '../data/session_models.dart';
import '../data/session_repository.dart';
import '../domain/rest_timer.dart';
import '../domain/session_engine.dart';

export '../../../core/services/haptics_service.dart';
export '../../../core/services/notification_service.dart';
export '../../../core/services/session_feedback_settings.dart';
export '../../../core/services/sound_service.dart';
export '../data/session_models.dart';
export '../data/session_repository.dart';
export '../domain/rest_timer.dart';
export '../domain/session_engine.dart';

/// Everything the UI needs to render a live workout: the DB-backed session
/// snapshot, the pure rest-timer state, which set is manually focused (if
/// any), and whether a rest just finished (for one-shot UI reactions).
class ActiveSessionState {
  const ActiveSessionState({
    required this.session,
    required this.rest,
    this.focusedSetId,
    this.restJustFinished = false,
  });

  final ActiveSession session;
  final RestTimerState rest;
  final String? focusedSetId;
  final bool restJustFinished;

  /// The focused set if one is set and still pending, else the session's
  /// first pending target.
  SessionTarget? get currentTarget {
    final focused = focusedSetId;
    if (focused != null) {
      final owner = session.exerciseOf(focused);
      final set = session.setById(focused);
      if (owner != null && set != null && set.completedAt == null) {
        return SessionTarget(
          sessionExerciseId: owner.exercise.id,
          setId: set.id,
          setIndex: set.setIndex,
          exerciseName: owner.exercise.name,
          kind: TargetKind.sameExercise,
        );
      }
    }
    return firstPendingTarget(session);
  }

  /// [clearFocusedSetId] exists because focus legitimately returns to null
  /// and a plain nullable parameter can't distinguish "leave unchanged" from
  /// "clear it".
  ActiveSessionState copyWith({
    ActiveSession? session,
    RestTimerState? rest,
    String? focusedSetId,
    bool clearFocusedSetId = false,
    bool? restJustFinished,
  }) {
    return ActiveSessionState(
      session: session ?? this.session,
      rest: rest ?? this.rest,
      focusedSetId:
          clearFocusedSetId ? null : (focusedSetId ?? this.focusedSetId),
      restJustFinished: restJustFinished ?? this.restJustFinished,
    );
  }
}

class ActiveSessionController extends AutoDisposeAsyncNotifier<ActiveSessionState?> {
  SessionRepository get _repo => ref.read(sessionRepositoryProvider);

  /// Set by a [Ref.onDispose] hook registered in [build]. Guards every
  /// `state =` write below against a pre-existing race: a mutator (e.g.
  /// [completeSet]) awaits `_reload`'s `SessionRepository.watchSession(id)
  /// .first` mid-write, and the user can back out of the session screen
  /// fast enough that this `AutoDisposeAsyncNotifier` is torn down (last
  /// listener dropped, `autoDispose` fires) *before* that await resolves.
  ///
  /// Today, on riverpod 2.6.1, writing `state = ...` on an already-disposed
  /// notifier is harmless — `AsyncNotifierBase`'s `state` setter
  /// (`async_notifier/base.dart`) has a literal `// TODO assert Notifier
  /// isn't disposed` and currently does nothing else defensive, so the
  /// write is simply inert: no listener observes it, and the next time this
  /// provider is read it gets a brand-new notifier whose `build()` re-reads
  /// the DB from scratch anyway. So nothing was ever silently corrupted by
  /// this race. But relying on an upstream TODO staying un-implemented
  /// forever is fragile — a future riverpod upgrade could turn that comment
  /// into a thrown assertion. This flag makes the guard explicit and
  /// independent of that implementation detail.
  ///
  /// Deliberately does NOT skip the underlying DB write (`_repo.updateSet`,
  /// `_repo.saveRestState`, etc.) — those don't depend on this notifier's
  /// liveness, and letting an in-flight mutation actually persist is
  /// correct even if nothing is left mounted to display the result.
  bool _disposed = false;

  void _setState(AsyncValue<ActiveSessionState?> value) {
    if (_disposed) return;
    state = value;
  }

  /// Awaits the controller's own [future] before reading state, so a
  /// mutation called immediately after `container.read(provider.notifier)`
  /// (before anyone has awaited the initial build) doesn't race the still-
  /// pending `build()`.
  Future<ActiveSessionState> _ready() async {
    final value = await future;
    if (value == null) {
      throw StateError('ActiveSessionController: no active session');
    }
    return value;
  }

  /// Fetches the active session (via [SessionRepository.watchActiveSession]'s
  /// first emission) and rehydrates it.
  ///
  /// This deliberately does **not** keep a live subscription that re-emits
  /// [state] on every subsequent DB change. Every mutator method below
  /// already reloads the post-write session and calls [_emit] itself,
  /// which is the single, deterministic source of truth for this
  /// controller's own writes. A second, independently-scheduled watcher
  /// reacting to those same writes raced it: two DB writes issued close
  /// together (e.g. [setExerciseRest]'s `updateSessionExercise` followed by
  /// `saveRestState`) fire as two separate table-update events, and the
  /// watcher's rehydration of the *first* (still-stale) event could finish
  /// — and overwrite [state] — strictly after a mutator's own correct
  /// `_emit` for the *second* had already landed, silently reverting a
  /// just-completed rest back to idle. That was caught by
  /// `doLater sends the current exercise to the back without touching rest`
  /// failing intermittently once this was serialized (see the fix report).
  /// `container.invalidate(activeSessionControllerProvider)` remains the
  /// supported way to force a fresh read (used by the "survives a
  /// controller rebuild" test, and appropriate for e.g. app resume).
  @override
  Future<ActiveSessionState?> build() async {
    // `ref.onDispose` fires before every rebuild of this element — not only
    // at final teardown. With an active listener (e.g. the screen still
    // mounted, or a test's `container.listen`), `ref.invalidate` reruns
    // `build()` on this SAME notifier instance rather than replacing it, so
    // the dispose hook from the *previous* build fires and then `build()`
    // runs again immediately after — confirmed by logging `hashCode`
    // through both. Resetting the flag here (rather than only in the field
    // initializer) is what keeps `_disposed` meaning "this notifier is
    // truly gone" instead of "a rebuild happened once" — the "TODO assert
    // Notifier isn't disposed" this guards against is specifically the
    // notifier's actual final teardown, not a mid-lifetime rebuild.
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final repo = ref.watch(sessionRepositoryProvider);
    final active = await repo.watchActiveSession().first;
    if (active == null) return null;
    final (rest: rest, lapsed: lapsed) = await _settledRest(repo, active);
    if (!lapsed) {
      return ActiveSessionState(session: active, rest: rest);
    }

    // The rest's deadline passed while nobody was watching (app backgrounded,
    // or the process killed and relaunched). Settling it to `finished` in
    // isolation is not enough: without the auto-focus decision and the
    // `restJustFinished` flag, the screen comes back looking exactly as the
    // user left it minus the countdown — no rest bar, no auto-advance — even
    // though their phone buzzed when rest was up (Task 18's scheduled
    // notification). Route the restore through the same resolution
    // [_handleRestFinished] uses so the user-visible outcome matches a rest
    // that finished with the app open (PRD FR-108/109).
    //
    // Deliberately WITHOUT [_onRestFinished]'s side effects: the notification
    // already fired (or is moot), and haptics/sound for a moment the user
    // wasn't present for would be noise.
    final outcome = _resolveRestFinished(rest, active);
    return ActiveSessionState(
      session: active,
      rest: outcome.rest,
      focusedSetId: outcome.focusedSetId,
      restJustFinished: outcome.restJustFinished,
    );
  }

  /// Rehydrates rest state from the DB row (recomputing `nextTarget`, which
  /// isn't persisted) and runs it through [RestTimer.settle] so a deadline
  /// that passed while unobserved (backgrounded, process death) is reflected
  /// immediately. Persists only if settling actually changed the status.
  ///
  /// `lapsed` reports whether settling actually flipped a running rest to
  /// finished during *this* rehydration — the signal [build] needs to tell
  /// "rest ran out while we weren't looking" apart from "rest was already
  /// finished (or idle/paused) when it was persisted".
  Future<({RestTimerState rest, bool lapsed})> _settledRest(
    SessionRepository repo,
    ActiveSession active,
  ) async {
    final now = DateTime.now();
    var rest = repo.restStateFrom(active);
    final settled = RestTimer.settle(rest, now);
    final lapsed = settled.status != rest.status;
    if (lapsed) {
      await repo.saveRestState(active.session.id, settled);
      rest = settled;
    }
    return (rest: rest, lapsed: lapsed);
  }

  Future<ActiveSession> _reload(String sessionId) async {
    final session = await _repo.watchSession(sessionId).first;
    if (session == null) {
      throw StateError('Session $sessionId no longer exists');
    }
    return session;
  }

  /// Runs a side-effect [action] (haptics, sound, or a notification-channel
  /// call) and swallows anything it throws. `flutter_local_notifications`
  /// and `shared_preferences` can both throw a real `PlatformException` /
  /// `MissingPluginException` on-device — this is what stops such a throw
  /// from escaping into a mutator's caller and stranding the mutation before
  /// it reaches `_reload`/`saveRestState`/`_emit` (PRD §18.7/§24.5: never
  /// block a set/rest mutation on a side effect).
  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      // Deliberately swallowed — see doc comment above — but not silently:
      // a genuine programming bug in a side effect would otherwise leave no
      // trace at all. `debugPrint` is compiled out of release builds.
      debugPrint('ActiveSessionController: side effect failed: $e');
    }
  }

  /// Reads a `shared_preferences`-backed boolean setting, falling back to
  /// [fallback] if the read itself throws.
  ///
  /// The read — not just the service call it gates — has to sit inside a
  /// guarded boundary. These settings resolve through
  /// `sharedPreferencesProvider` -> `SharedPreferences.getInstance()`, which
  /// can throw a `MissingPluginException`/`PlatformException` on-device, and
  /// because they're backed by an `AsyncNotifier` that error is *cached for
  /// the container's lifetime*: one failure would otherwise strand every
  /// subsequent `completeSet`/`_onRestFinished` for the rest of the app run
  /// — exactly the C1-class defect [_safe] exists to prevent, just one call
  /// frame further out. Falling back to "on" matches these settings' own
  /// defaults (see `session_feedback_settings.dart`).
  Future<bool> _settingOrDefault(
    ProviderListenable<Future<bool>> setting, {
    bool fallback = true,
  }) async {
    try {
      return await ref.read(setting);
    } catch (e) {
      debugPrint('ActiveSessionController: setting read failed: $e');
      return fallback;
    }
  }

  /// Schedules the pending "rest complete" notification to match [rest] if
  /// it's running with a deadline, else cancels it — the schedule-or-cancel
  /// rule [completeSet] and [resumeRest] originally duplicated inline.
  /// [next] lets a caller that already computed a fresher target (e.g.
  /// [completeSet]'s `nextTargetAfter`) supply its label directly; other
  /// callers fall back to [rest]'s own carried `nextTarget`. Wrapped via
  /// [_safe] so a platform-channel throw here can never abort the mutation
  /// that called it.
  Future<void> _syncRestNotification(
    RestTimerState rest, {
    SessionTarget? next,
  }) {
    return _safe(() async {
      final notifications = ref.read(notificationServiceProvider);
      if (rest.status == RestTimerStatus.running && rest.endsAt != null) {
        await notifications.scheduleRestComplete(
          at: rest.endsAt!,
          nextLabel: next?.label ?? rest.nextTarget?.label ?? 'Session complete',
        );
      } else {
        await notifications.cancelRestComplete();
      }
    });
  }

  /// Cancels the pending "rest complete" notification, swallowing any
  /// platform-channel throw via [_safe] — used by callers that only ever
  /// need to cancel (never reschedule), e.g. ending a session mid-rest.
  Future<void> _cancelRestNotification() {
    return _safe(() => ref.read(notificationServiceProvider).cancelRestComplete());
  }

  void _emit(
    ActiveSession session,
    RestTimerState rest, {
    String? focusedSetId,
    bool clearFocusedSetId = false,
    bool? restJustFinished,
  }) {
    final prev = state.valueOrNull;
    if (prev == null) {
      _setState(AsyncData(ActiveSessionState(
        session: session,
        rest: rest,
        focusedSetId: clearFocusedSetId ? null : focusedSetId,
        restJustFinished: restJustFinished ?? false,
      )));
      return;
    }
    _setState(AsyncData(prev.copyWith(
      session: session,
      rest: rest,
      focusedSetId: focusedSetId,
      clearFocusedSetId: clearFocusedSetId,
      restJustFinished: restJustFinished,
    )));
  }

  // ---------------------------------------------------------------------
  // Sets
  // ---------------------------------------------------------------------

  /// Stamps [setId] complete, then recomputes rest **from scratch** on the
  /// post-write session: either starts a new rest for the just-completed
  /// exercise, or (rest == 0 / last set of session) leaves rest idle and
  /// focuses whatever comes next. Because this always recomputes rather than
  /// patching, completing a set while already resting correctly restarts
  /// rest from the new set (PRD §18.4).
  Future<void> completeSet(String setId) async {
    final current = await _ready();
    final repo = _repo;
    final now = DateTime.now();
    final set = current.session.setById(setId);
    if (set == null) return;

    // CMP-015: a pending row shows its snapshotted plan muted, so completing
    // an untouched set has to mean "I did what was planned" — otherwise the
    // one-tap the muted value invites would log nothing and undercount volume.
    // Only *empty* logged columns are filled: anything typed wins, and a set
    // with no plan stays empty exactly as before. A planned rep range logs its
    // lower bound (the honest floor of what was asked for).
    await repo.updateSet(set.copyWith(
      completedAt: Value(now),
      weight: set.weight == null && set.plannedWeight != null
          ? Value(set.plannedWeight)
          : const Value.absent(),
      reps: set.reps == null && set.plannedReps != null
          ? Value(set.plannedReps)
          : const Value.absent(),
    ));

    // Awaits the setting's own resolved value rather than
    // `.valueOrNull ?? true` — the `AsyncNotifier` backing it may still be
    // mid-`build()` (its first read of `shared_preferences`) this early in
    // a session, and a synchronous read in that window would silently fall
    // back to "on" regardless of what's actually persisted. Read through
    // [_settingOrDefault] so a throw from `shared_preferences` itself can't
    // strand this mutation before `_emit`.
    if (await _settingOrDefault(hapticsEnabledSettingProvider.future)) {
      await _safe(() => ref.read(hapticsServiceProvider).setCompleted());
    }

    final reloaded = await _reload(current.session.session.id);
    final restSeconds = restSecondsAfter(reloaded, setId);
    final next = nextTargetAfter(reloaded, setId);

    RestTimerState rest;
    String? focusedSetId;
    var clearFocus = false;
    if (restSeconds > 0) {
      rest = RestTimer.start(
        seconds: restSeconds,
        now: now,
        afterSetId: setId,
        nextTarget: next,
      );
    } else {
      rest = const RestTimerState.idle();
      if (next != null) {
        focusedSetId = next.setId;
      } else {
        clearFocus = true;
      }
    }

    await repo.saveRestState(reloaded.session.id, rest);

    // Schedule when rest STARTS, for the moment it's due — not fired from a
    // timer when rest ends (a scheduled OS notification survives the
    // process being killed; a Dart timer does not). `scheduleRestComplete`
    // cancels any previously-pending one first, which is what makes
    // completing a set while already resting correctly replace the old
    // notification with one for the new rest. No new rest (end of session,
    // or a zero-second exercise) means any stale pending notification from
    // the just-finished exercise must be explicitly cancelled instead.
    await _syncRestNotification(rest, next: next);

    // A fresh rest (or a fresh idle state) supersedes any stale "just
    // finished" flag from a previous rest — otherwise it could coexist with
    // a newly running timer and misfire Task 14's "rest complete" banner.
    _emit(
      reloaded,
      rest,
      focusedSetId: focusedSetId,
      clearFocusedSetId: clearFocus,
      restJustFinished: false,
    );
  }

  /// Clears completion. If the active rest was anchored on this set, cancel
  /// it; otherwise leave the running rest alone (PRD FR-106) — e.g.
  /// uncompleting an older, already-passed set must not disturb the rest
  /// owed for a later one.
  Future<void> uncompleteSet(String setId) async {
    final current = await _ready();
    final repo = _repo;
    final set = current.session.setById(setId);
    if (set == null) return;

    await repo.updateSet(set.copyWith(completedAt: const Value(null)));
    final reloaded = await _reload(current.session.session.id);

    if (current.rest.afterSetId == setId) {
      final cancelled = RestTimer.cancel();
      await repo.saveRestState(reloaded.session.id, cancelled);
      await _cancelRestNotification();
      _emit(reloaded, cancelled);
    } else {
      _emit(reloaded, current.rest);
    }
  }

  /// The `clearX` flags exist because Drift's nullable `Value` needs an
  /// explicit "set to null" signal — a plain `null` argument here means
  /// "leave unchanged".
  Future<void> updateSetValues(
    String setId, {
    double? weight,
    bool clearWeight = false,
    int? reps,
    bool clearReps = false,
    double? rir,
    bool clearRir = false,
    int? durationSeconds,
    bool clearDuration = false,
  }) async {
    final current = await _ready();
    final set = current.session.setById(setId);
    if (set == null) return;

    final updated = set.copyWith(
      weight: clearWeight
          ? const Value(null)
          : (weight != null ? Value(weight) : const Value.absent()),
      reps: clearReps
          ? const Value(null)
          : (reps != null ? Value(reps) : const Value.absent()),
      rir: clearRir
          ? const Value(null)
          : (rir != null ? Value(rir) : const Value.absent()),
      durationSeconds: clearDuration
          ? const Value(null)
          : (durationSeconds != null
              ? Value(durationSeconds)
              : const Value.absent()),
    );
    await _repo.updateSet(updated);
    final reloaded = await _reload(current.session.session.id);
    _emit(reloaded, current.rest);
  }

  Future<void> addSet(String sessionExerciseId) async {
    final current = await _ready();
    await _repo.addSet(sessionExerciseId);
    final reloaded = await _reload(current.session.session.id);
    _emit(reloaded, current.rest);
  }

  Future<void> removeSet(String setId) async {
    final current = await _ready();
    await _repo.removeSet(setId);
    final reloaded = await _reload(current.session.session.id);
    _emit(reloaded, current.rest);
  }

  // ---------------------------------------------------------------------
  // Focus
  // ---------------------------------------------------------------------

  void focusSet(String setId) {
    final current = state.valueOrNull;
    if (current == null) return;
    _setState(AsyncData(current.copyWith(focusedSetId: setId)));
  }

  void clearRestFinished() {
    final current = state.valueOrNull;
    if (current == null) return;
    _setState(AsyncData(current.copyWith(restJustFinished: false)));
  }

  /// Moves focus to the pending target on demand — what the rest bar's
  /// "Next set" / "Next exercise" button calls when auto-focus is off and
  /// the rest already finished. Recomputes the target from the session's
  /// *current* order (not whatever [RestTimerState.nextTarget] was captured
  /// with when rest started) so a mid-rest reorder is honoured here too.
  /// Also cancels the (already-finished) rest so the rest bar dismisses.
  ///
  /// Synchronous, like [focusSet]/[clearRestFinished] — this is a direct UI
  /// action (a button tap) and the caller expects [state] to reflect the new
  /// focus immediately, not after an awaited DB round trip. The
  /// `saveRestState` persistence is fired without waiting on it.
  void goToNextTarget() {
    final current = state.valueOrNull;
    if (current == null) return;
    final target = current.rest.afterSetId == null
        ? firstPendingTarget(current.session)
        : nextTargetAfter(current.session, current.rest.afterSetId!);

    final cancelled = RestTimer.cancel();
    unawaited(_repo.saveRestState(current.session.session.id, cancelled));

    _setState(AsyncData(current.copyWith(
      rest: cancelled,
      focusedSetId: target?.setId,
      clearFocusedSetId: target == null,
      restJustFinished: false,
    )));
  }

  // ---------------------------------------------------------------------
  // Session settings
  // ---------------------------------------------------------------------

  Future<void> setAutoFocusNextSet(bool value) async {
    final current = await _ready();
    await _repo.updateSession(
      current.session.session.copyWith(autoFocusNextSet: value),
    );
    final reloaded = await _reload(current.session.session.id);
    _emit(reloaded, current.rest);
  }

  Future<void> setAutoFocusNextExercise(bool value) async {
    final current = await _ready();
    await _repo.updateSession(
      current.session.session.copyWith(autoFocusNextExercise: value),
    );
    final reloaded = await _reload(current.session.session.id);
    _emit(reloaded, current.rest);
  }

  Future<void> setSessionNotes(String notes) async {
    final current = await _ready();
    await _repo.updateSession(
      current.session.session.copyWith(notes: Value(notes)),
    );
    final reloaded = await _reload(current.session.session.id);
    _emit(reloaded, current.rest);
  }

  // ---------------------------------------------------------------------
  // Exercise rest configuration
  // ---------------------------------------------------------------------

  /// Writes `restSeconds` on the session exercise. When the active rest
  /// belongs to that exercise and [applyToActiveRest] is true, rebuilds the
  /// running timer with the new total, anchored on the elapsed portion so
  /// the countdown doesn't jump backwards or lose progress (PRD FR-113).
  Future<void> setExerciseRest(
    String sessionExerciseId,
    int seconds, {
    bool applyToActiveRest = true,
  }) async {
    final current = await _ready();
    final repo = _repo;
    final se = current.session.exerciseById(sessionExerciseId);
    if (se == null) return;

    await repo.updateSessionExercise(se.exercise.copyWith(restSeconds: seconds));
    final reloaded = await _reload(current.session.session.id);

    var rest = current.rest;
    if (applyToActiveRest &&
        rest.status == RestTimerStatus.running &&
        rest.afterSetId != null) {
      final owner = current.session.exerciseOf(rest.afterSetId!);
      if (owner != null && owner.exercise.id == sessionExerciseId) {
        final now = DateTime.now();
        final elapsed = rest.totalSeconds - rest.remainingAt(now).inSeconds;
        final newRemaining = (seconds - elapsed).clamp(0, seconds);
        if (newRemaining <= 0) {
          final skipped = RestTimer.skip(rest).copyWith(totalSeconds: seconds);
          await repo.saveRestState(reloaded.session.id, skipped);
          // Shrinking the total below the elapsed portion effectively
          // finishes the rest early — route through the same finish path
          // as skipRest/settle/adjustRest so auto-focus and
          // restJustFinished fire consistently (PRD FR-113).
          await _handleRestFinished(skipped, session: reloaded);
          return;
        }
        rest = rest.copyWith(
          totalSeconds: seconds,
          endsAt: now.add(Duration(seconds: newRemaining)),
        );
        await repo.saveRestState(reloaded.session.id, rest);
        await _syncRestNotification(rest);
      }
    }

    _emit(reloaded, rest);
  }

  // ---------------------------------------------------------------------
  // Reordering — never touches the rest timer (PRD §18.8)
  // ---------------------------------------------------------------------

  Future<void> doLater(String sessionExerciseId) async {
    final current = await _ready();
    final ids = moveToEnd(current.session, sessionExerciseId);
    await _repo.reorderSessionExercises(current.session.session.id, ids);
    final reloaded = await _reload(current.session.session.id);
    _emit(reloaded, current.rest);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = await _ready();
    final ids = reorderPending(current.session, oldIndex, newIndex);
    await _repo.reorderSessionExercises(current.session.session.id, ids);
    final reloaded = await _reload(current.session.session.id);
    _emit(reloaded, current.rest);
  }

  // ---------------------------------------------------------------------
  // Rest timer controls
  // ---------------------------------------------------------------------

  Future<void> pauseRest() async {
    final current = await _ready();
    final rest = RestTimer.pause(current.rest, DateTime.now());
    await _repo.saveRestState(current.session.session.id, rest);
    await _cancelRestNotification();
    _emit(current.session, rest);
  }

  /// Resuming hands the timer a fresh `endsAt`, so — like [completeSet]
  /// starting a fresh rest — the pending notification is rescheduled to
  /// match rather than left pointing at the (cancelled, on pause) original
  /// deadline.
  Future<void> resumeRest() async {
    final current = await _ready();
    final rest = RestTimer.resume(current.rest, DateTime.now());
    await _repo.saveRestState(current.session.session.id, rest);
    await _syncRestNotification(rest);
    _emit(current.session, rest);
  }

  Future<void> skipRest() async {
    final current = await _ready();
    final skipped = RestTimer.skip(current.rest);
    await _repo.saveRestState(current.session.session.id, skipped);
    await _handleRestFinished(skipped);
  }

  Future<void> cancelRest() async {
    final current = await _ready();
    final cancelled = RestTimer.cancel();
    await _repo.saveRestState(current.session.session.id, cancelled);
    await _cancelRestNotification();
    _emit(current.session, cancelled);
  }

  Future<void> adjustRest(Duration delta) async {
    final current = await _ready();
    final now = DateTime.now();
    final rest = RestTimer.adjust(current.rest, delta, now);
    await _repo.saveRestState(current.session.session.id, rest);
    if (current.rest.status == RestTimerStatus.running &&
        rest.status == RestTimerStatus.finished) {
      await _handleRestFinished(rest);
    } else {
      // Covers both the still-running case (e.g. `+30s`, whose `endsAt`
      // just moved — the pending notification must move with it or it
      // fires early) and paused, which cancels.
      await _syncRestNotification(rest);
      _emit(current.session, rest);
    }
  }

  /// Re-runs [RestTimer.settle] against the wall clock; called from a 1s
  /// ticker and on app resume. Fires the finish side effects only on a
  /// running -> finished transition (see [_handleRestFinished] for why the
  /// brief's original short-circuit made auto-focus unreachable).
  Future<void> settle() async {
    final current = await _ready();
    final now = DateTime.now();
    final settled = RestTimer.settle(current.rest, now);
    if (settled.status == current.rest.status) return;

    await _repo.saveRestState(current.session.session.id, settled);
    if (current.rest.status == RestTimerStatus.running &&
        settled.status == RestTimerStatus.finished) {
      await _handleRestFinished(settled);
    } else {
      _emit(current.session, settled);
    }
  }

  /// Single home for "a rest just finished": the finish side effects, the
  /// auto-focus decision, and the state write. Both [skipRest] (an
  /// already-finished status the moment this runs) and a genuine
  /// running -> finished [settle] transition route through here so the
  /// behaviour — which toggle governs which target kind — only needs to be
  /// implemented once.
  ///
  /// Idempotent: a no-op when the state already reflects a finished,
  /// not-yet-cleared rest, so the 1s ticker calling [settle] repeatedly
  /// can't re-fire the side effects or clobber a focus change the user made
  /// in between.
  /// [session] lets a caller that already reloaded a fresher snapshot (e.g.
  /// [setExerciseRest], which just wrote a new `restSeconds`) hand it in
  /// directly rather than emitting the pre-update session held in [_ready].
  Future<void> _handleRestFinished(
    RestTimerState settled, {
    ActiveSession? session,
  }) async {
    final current = await _ready();
    if (current.rest.status == RestTimerStatus.finished &&
        current.restJustFinished) {
      return;
    }

    await _onRestFinished();

    final effectiveSession = session ?? current.session;
    final outcome = _resolveRestFinished(settled, effectiveSession);

    _emit(
      effectiveSession,
      outcome.rest,
      focusedSetId: outcome.focusedSetId,
      clearFocusedSetId: outcome.clearFocusedSetId,
      restJustFinished: outcome.restJustFinished,
    );
  }

  /// The pure half of "a rest just finished": which target comes next,
  /// whether the governing auto-focus toggle moves focus there, and the rest
  /// state to emit. Shared by [_handleRestFinished] (a rest that finished
  /// with the app open) and [build]'s restore path (a rest whose deadline
  /// lapsed while backgrounded), so both produce the same user-visible
  /// outcome — the restore path just skips the side effects.
  ({
    RestTimerState rest,
    String? focusedSetId,
    bool clearFocusedSetId,
    bool restJustFinished,
  }) _resolveRestFinished(RestTimerState settled, ActiveSession session) {
    // Recomputed against the session's *current* order, not the order
    // captured in `settled.nextTarget` when rest started — the user can
    // reorder mid-rest (e.g. a machine is occupied) and the auto-focus
    // decision must reflect that (PRD §18.8).
    final target = settled.afterSetId == null
        ? firstPendingTarget(session)
        : nextTargetAfter(session, settled.afterSetId!);

    String? focusedSetId;
    var clearFocusedSetId = false;
    var autoFocus = false;
    if (target == null) {
      clearFocusedSetId = true;
    } else {
      autoFocus = target.kind == TargetKind.sameExercise
          ? session.session.autoFocusNextSet
          : session.session.autoFocusNextExercise;
      if (autoFocus) {
        focusedSetId = target.setId;
      }
    }

    // Keep the emitted rest's `nextTarget` in sync with the recomputed
    // target rather than the (possibly stale, pre-reorder) one it was
    // carrying, so the rest bar's "NEXT" label agrees with where focus goes.
    // Built explicitly rather than via `copyWith` because `copyWith`'s
    // `nextTarget` param can't express "clear it to null" (a null target —
    // end of session — falls back to whatever was already there).
    final resolvedRest = RestTimerState(
      status: settled.status,
      totalSeconds: settled.totalSeconds,
      endsAt: settled.endsAt,
      remainingSeconds: settled.remainingSeconds,
      afterSetId: settled.afterSetId,
      nextTarget: target,
    );

    // `restJustFinished` is consumed by the auto-focus (not "just finished"
    // for the UI's purposes) whenever the governing toggle actually moved
    // focus. When there's no target left (end of session) there's nothing to
    // auto-focus into either, so that's not a "rest complete, waiting on
    // you" state.
    return (
      rest: resolvedRest,
      focusedSetId: focusedSetId,
      clearFocusedSetId: clearFocusedSetId,
      restJustFinished: !autoFocus && target != null,
    );
  }

  /// Fires the three "notice this" side effects for a rest that just
  /// finished: cancel the pending notification (it either already fired, or
  /// the user was in-app the whole time and never needed it —
  /// `cancelRestComplete` is harmless either way), then
  /// haptics and sound, each only when its settings toggle is on. `await`ed
  /// by its one call site in [_handleRestFinished] — that's a small,
  /// necessary widening of this method's signature from the `void` no-op
  /// Task 18 inherited, not a restructure of the caller: haptics/sound must
  /// be awaited here (see below), and the caller needs the toggle decisions
  /// to have actually landed before it returns.
  Future<void> _onRestFinished() async {
    // The cancel is awaited rather than fired-and-forgotten: it can no
    // longer throw (it's wrapped in [_safe]), and awaiting closes a narrow
    // race where a fast next-set completion's `scheduleRestComplete` could
    // be overwritten by a stale in-flight cancel sharing the same
    // notification id.
    //
    // Haptics/sound are awaited too — [_handleRestFinished]'s caller (and
    // this file's tests) reasonably expect them to have fired by the time
    // this returns, and each setting read below may still be mid-`build()`
    // (its first read of `shared_preferences`) this early in a session, so a
    // synchronous `.valueOrNull ?? true` read would risk silently falling
    // back to "on" regardless of what's persisted.
    //
    // Every platform-channel call here is wrapped in [_safe], and every
    // setting read in [_settingOrDefault] — same reasoning as [completeSet]'s
    // C1 fix: a throw from `HapticFeedback`, `SystemSound` or
    // `shared_preferences` on-device must not escape and abort
    // [_handleRestFinished] before its own `_emit`, which would strand
    // skipRest/adjustRest/settle/setExerciseRest's rest-finished transition
    // after `saveRestState` already persisted it.
    await _cancelRestNotification();

    if (await _settingOrDefault(hapticsEnabledSettingProvider.future)) {
      await _safe(() => ref.read(hapticsServiceProvider).restFinished());
    }
    if (await _settingOrDefault(soundEnabledSettingProvider.future)) {
      await _safe(() => ref.read(soundServiceProvider).restComplete());
    }
  }

  // ---------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------

  Future<void> pauseSession() async {
    final current = await _ready();
    final repo = _repo;
    final now = DateTime.now();

    await repo.updateSession(
      current.session.session.copyWith(
        status: SessionStatus.paused,
        pausedAt: Value(now),
      ),
    );
    final rest = RestTimer.pause(current.rest, now);
    await repo.saveRestState(current.session.session.id, rest);
    await _cancelRestNotification();

    final reloaded = await _reload(current.session.session.id);
    _emit(reloaded, rest);
  }

  /// Adds the paused wall-time to `pausedSeconds`, measured from the
  /// `pausedAt` column [pauseSession] stamped — **not** `updatedAt`, which
  /// any unrelated write during the pause (e.g. correcting a logged weight)
  /// would restamp and silently shrink the measured pause.
  Future<void> resumeSession() async {
    final current = await _ready();
    final repo = _repo;
    final now = DateTime.now();

    final pausedAt = current.session.session.pausedAt;
    final pausedFor =
        pausedAt == null ? 0 : now.difference(pausedAt).inSeconds;
    final newPausedSeconds =
        current.session.session.pausedSeconds + (pausedFor > 0 ? pausedFor : 0);

    await repo.updateSession(current.session.session.copyWith(
      status: SessionStatus.active,
      pausedSeconds: newPausedSeconds,
      pausedAt: const Value(null),
    ));
    final rest = RestTimer.resume(current.rest, now);
    await repo.saveRestState(current.session.session.id, rest);
    await _syncRestNotification(rest);

    final reloaded = await _reload(current.session.session.id);
    _emit(reloaded, rest);
  }

  Future<void> finish({String? notes}) async {
    final current = await _ready();
    await _cancelRestNotification();
    await _repo.finishSession(current.session.session.id, notes: notes);
    _setState(const AsyncData(null));
  }

  Future<void> cancelSession() async {
    final current = await _ready();
    await _cancelRestNotification();
    await _repo.cancelSession(current.session.session.id);
    _setState(const AsyncData(null));
  }
}

final activeSessionControllerProvider = AsyncNotifierProvider.autoDispose<
    ActiveSessionController, ActiveSessionState?>(ActiveSessionController.new);

/// Emits every 500ms while watched — the UI is expected to watch this only
/// while `rest.isActive`, so `autoDispose` stops the ticker the moment rest
/// ends. The state itself is not recomputed from ticks; this is purely a
/// repaint signal.
final restTickerProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  while (true) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    yield DateTime.now();
  }
});
