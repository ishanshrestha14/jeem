# T-014 — Delete a logged workout

- **Status:** **Done** (2026-08-25) — `flutter analyze` clean, 339 tests pass.
- **Priority:** Must
- **Effort:** S
- **Specs:** S-003, S-019
- **Last updated:** 2026-08-25

## Goal

A completed session could not be removed anywhere in the app. `cancelSession` only marks a *running*
session cancelled; History offered "Duplicate this workout as a template" and nothing else. A
mis-logged or abandoned workout was permanent.

## Scope (in)

- `SessionRepository.deleteSession(id)` — a soft delete.
- Delete in the Workout tab's day card (⋮) and in the History row menu, both behind a confirmation.
- A regression guard for the FAB hero-tag collision found while testing this (below).

## Scope (out)

- Undo. See the decision below.
- Restoring a deleted workout. The row survives in the database, but nothing surfaces it.
- Deleting individual sets or exercises from a finished session.

## Decisions

- **Soft delete**, stamping `deletedAt`. Not the universal pattern here — `deleteTemplate` and
  `removeSet` are hard deletes — but right for a session, which is the only record that a workout
  happened. `_fetchCompletedSessions`
  already filters on it, so **one write** removes the workout from history, the week strips,
  `Previous` (T-009), personal records and every volume total — all of which are *derived* from
  completed sessions rather than stored.
- **Confirmation, not a snackbar undo.** Deleting a logged workout destroys real training history and
  silently re-derives your records; that deserves a deliberate yes rather than a four-second window
  you might miss.
- **The copy names the consequence** — "Its sets, and any records it set, will be removed from your
  history" — because the record change is correct but otherwise invisible: delete the session holding
  your best bench and the PR reverts to the next best.
- **The History row menu is now unconditional.** It used to appear only when the workout's template
  still existed, since Duplicate needs one. An ad-hoc session (T-012) has no template at all and
  would have had no menu, so Duplicate is now conditional *within* an always-present menu.

## Files touched

- `lib/features/sessions/data/session_repository.dart` — `deleteSession`
- `lib/features/templates/ui/workout_screen.dart` — the day card's ⋮
- `lib/features/history/ui/history_screen.dart` — Delete in the existing menu
- `lib/features/exercises/ui/exercise_list_screen.dart` — hero tag (see below)

## The bug this shook out

Running the app logged **`There are multiple heroes that share the same tag`**. Explore's FAB and the
Workout tab's FAB both used Flutter's default hero tag, and `StatefulShellRoute.indexedStack` keeps
every tab alive, so both were heroes in one subtree and any route push could throw.

**Pre-existing** — the old routine-list Workout tab had a FAB too — and only noticed because
[T-013](T-013-workout-tab.md) gave a reason to push from that tab. Both FABs now carry explicit tags.

Worth remembering: **two attempts at a regression test passed against the broken code.** `find` skips
offstage widgets by default, and the inactive tab is offstage — so the second FAB was invisible to
the test. `find.byType(FloatingActionButton, skipOffstage: false)` is what made it fail properly.

## Scrolling

Prompted by the owner asking what happens with many workouts logged. Verified rather than assumed,
with four tests on deliberately short (400x500 / 400x600) surfaces:

- Twelve workouts in one day scroll; `Log another workout` is reachable below them.
- An empty ad-hoc session's centred actions do not overflow a 500px-tall screen — the case
  `SliverFillRemaining(hasScrollBody: false)` would have got wrong.
- A ten-exercise session scrolls to its bottom actions.
- A fifteen-exercise routine detail scrolls, and `Start workout` stays reachable because it is
  pinned outside the scroll view.

All four passed first time; nothing needed fixing. They are guards, not fixes.

## Edge cases

- **Deleting the workout that held a record** — the record reverts to the next best. Covered.
- **Deleting the only workout** — records go empty, not stale. Covered.
- **An unknown id** is a no-op rather than an error: the caller is a menu on a row that may already
  have been deleted elsewhere.
- **An ad-hoc workout** has no template, and is still deletable.

## Acceptance criteria

- [x] A logged workout can be deleted from the Workout tab and from History.
- [x] It asks first, and backing out keeps the workout.
- [x] The row is soft-deleted, not dropped.
- [x] Records and volume re-derive without it.
- [x] Deleting an unknown id does not throw.
- [x] Every live FAB carries a unique hero tag.
- [x] `flutter analyze` clean; `flutter test` passes (339).

## QA checklist (on device)

- [x] Delete a workout from the Workout tab — confirmed by the owner.
- [ ] Delete one from History.
- [ ] Delete a workout that set a PR; check the You tab's records.
- [ ] Switch between Explore and Workout, then start a session — no hero exception.

## Revision log
- 2026-08-25 — created and shipped after the owner found the gap while testing T-013.
