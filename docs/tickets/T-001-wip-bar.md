# T-001 — "Workout in Progress" bar above the bottom nav

- **Status:** **Done** (2026-08-23) — `flutter analyze` clean, 206 tests pass.
- **Priority:** Must
- **Effort:** M
- **Specs:** CMP-001, S-001, S-006, S-015
- **Roadmap item:** Phase 1, item 6
- **Last updated:** 2026-08-23

## Goal

A live session must stay visible and resumable from **every** tab. Today `_ResumeCard` lives inside
`home_screen.dart`, so navigating to Workout, History or Profile mid-session hides the session
entirely — the only way back is to remember it exists and return to Home.

## Scope (in)

- A persistent strip rendered in `app_shell.dart`, directly above the bottom nav, visible on all tabs
  whenever a session is active and the user is not on `/session`.
- Anatomy per CMP-001: centred title **`Workout in Progress`**, then **`▶ Resume`** (accent) and
  **`✕ Discard`** (red). **No elapsed time** — matches the reference app, and avoids a second ticking
  clock to keep in sync.
- `Resume` → `context.go('/session')`.
- `Discard` → confirmation dialog, two options: **`Discard workout`** / **`Keep working out`**. On
  confirm, call the existing `cancelSession()` on `activeSessionControllerProvider`.
- The strip **occupies layout** (a `Column` above `bottomNavigationBar`), it does not overlay. Any
  bottom-anchored content in the tab below must reflow — verify nothing is obscured.
- Hidden while the user is already on `/session`.

## Scope (out)

- Elapsed time, progress, or any session stats in the bar.
- Changing how sessions start, finish, or persist.
- The five-tab navigation (ADR-005) — that is Phase 3.

## Files to touch

- `lib/app/app_shell.dart` — wrap `body`/`bottomNavigationBar` in a `Column`; insert the strip
- `lib/features/sessions/ui/widgets/` — new `workout_in_progress_bar.dart`
- `lib/features/dashboard/ui/home_screen.dart` — **remove `_ResumeCard`** (owner-confirmed
  2026-08-23): the bar supersedes it, and two resume affordances on one screen is worse than one
  consistent one everywhere
- `lib/core/widgets/confirm_dialog.dart` — reuse as-is if its labels are configurable

## Model / DB changes

**None.** `activeSessionProvider` is already a live stream (`home_screen.dart:22`), and
`activeSessionControllerProvider` already exposes `cancelSession()`.

## New components

- CMP-001 — `WorkoutInProgressBar`

## Edge cases

- **Already on `/session`** — bar must be hidden, not duplicated.
- **No active session** — bar absent, and the nav must not shift or animate awkwardly as it appears
  and disappears. Decide: animate in, or appear instantly?
- **App restart with a live session** — the session is restored from the DB; the bar must appear on
  whichever tab the user lands on. Note the reference app reopens **full-screen** after a restart
  (S-006 entry points) — we currently land on Home, so the bar is what makes the session findable.
- **Discard while `/session` is on the nav stack** — ensure the route is popped/redirected, not left
  pointing at a cancelled session.
- **Session finishes from the summary screen** — the bar must clear.
- Long-press or double-tap safety is not needed; the confirmation dialog covers accidental Discard.

## Acceptance criteria

- [ ] With an active session, the bar shows on every tab.
- [ ] `_ResumeCard` no longer appears on Home, and Home has no layout hole where it was.
- [ ] The bar is absent on `/session` and whenever no session is active.
- [ ] `Resume` opens the full-screen session with all state intact.
- [ ] `Discard` shows `Discard workout` / `Keep working out`; cancelling leaves the session untouched.
- [ ] Confirming Discard cancels the session, clears the bar, and does not leave `/session` on the stack.
- [ ] The bar pushes tab content up rather than covering it — no obscured buttons or list items.
- [ ] Both buttons have a ≥48dp touch target.
- [ ] Killing and relaunching the app with a live session shows the bar.

## QA checklist (on device)

- [x] Start a session, minimise, visit all four tabs — bar present on each.
- [x] Scroll each tab to the bottom — nothing hidden behind the bar.
- [x] Resume → verify sets, rest timer and elapsed time are unchanged.
- [x] Discard → `Keep working out` → session still live.
- [x] Discard → `Discard workout` → bar gone, session cancelled, no crash on back.
- [x] Force-stop the app mid-session, relaunch — bar present.
- [x] Rest timer running while minimised — confirm it still fires its notification.

## Open questions

- [x] `_ResumeCard` is **removed** (owner-confirmed 2026-08-23).
- [x] Animate the bar in/out, or appear instantly? Instant is simpler and avoids nav-bar jitter.

## What shipped

- `lib/features/sessions/ui/widgets/workout_in_progress_bar.dart` (CMP-001).
- Hosted in `app_shell.dart` inside the **`bottomNavigationBar` slot**, as a `Column` above the nav.
  Not in `body`: each shell branch keeps its own scroll view, so a body-level bar would mean every
  branch reserving space for it separately.
- Title `Workout in Progress` + session name + `▶ Resume` / `✕ Discard`, both 48dp minimum.
- Discard confirms via `confirmDestructive`, which gained an optional **`cancelLabel`** so the safe
  option reads `Keep working out` — "Cancel" sitting next to "Discard workout" reads as cancelling
  the *workout*, which is the opposite of what it does.
- `_ResumeCard` removed from `home_screen.dart`, along with its now-dead `activeSessionProvider`
  read and the doc comment describing it.
- `pumpUntilGone` added to `test/widget/pump_helpers.dart`.
- `test/widget/workout_in_progress_bar_test.dart` — 7 tests.

## Decisions made during implementation

- **No elapsed time on the bar**, matching the reference app. A live clock would mean a second
  ticker kept in step with the session screen's own, for no gain on a bar whose whole job is
  "tap to get back".
- **Nothing shown while the stream is loading or errored**, so a transient read cannot flash a bar
  for a session that may not exist.
- **No hide-on-`/session` logic needed.** That route sits outside the shell, so the bar is never
  built there — verified by ancestry in the tests, not by `find.text`, since Navigator keeps the
  obscured shell mounted underneath.
- **Instant, not animated** (the open question) — avoids nav-bar jitter.

## Test coverage moved, not deleted

Two Home tests covered the resume card, including a **regression test**: deleting the last template
mid-workout must not strand a live session behind the "No workouts yet" empty state. That guarantee
now belongs to the bar, so the test moved to the new file rather than being dropped. Home keeps one
test asserting it no longer surfaces a live session itself.

## Revision log
- 2026-08-23 — created from the roadmap (Phase 1, item 6).
- 2026-08-23 — implemented. Bar in the shell, `_ResumeCard` removed, resume-card coverage moved.
