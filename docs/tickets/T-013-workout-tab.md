# T-013 — Rebuild the Workout tab against S-003

- **Status:** **Done** (2026-08-25) — `flutter analyze` clean, 326 tests pass.
- **Priority:** Must
- **Effort:** L
- **Specs:** S-003, S-006, CMP-005, CMP-020, T-012
- **Last updated:** 2026-08-25

## Goal

Our Workout tab is a **routine list** — cards with Start / Edit / Duplicate / Delete. Since
[T-011](T-011-routine-detail.md) put routines in the Library with play buttons and a detail screen,
that tab is largely a second copy of the Library.

S-003 describes something else entirely: a **day launchpad** answering *what am I doing today?*
Rebuild it as that. The duplication and T-011's routing inconsistency both disappear with the old
screen.

## Scope (in)

- Date header (`August 25`) and the week strip.
- **Workouts today** — one card per session logged today: name, time, duration, volume.
- **Empty state** — `No workouts today` plus a full-width row CTA, `Start new workout`.
- **Suggested routines** — a carousel, **hidden once a workout is logged that day**.
- **FAB** — `Start new workout`, starting T-012's ad-hoc session.
- Retire the routine list, `_TemplateCard` and its Edit/Duplicate/Delete menu.

## Scope (out)

- **Insights / AI feedback** (S-003 §5). We have no recovery or streak model and will not invent one.
- **The avatar and calendar icon** in the top bar — neither has a destination in our app.
- Home (S-001), which is its own drift.

## Decisions

- **Suggestions rank least-recently-performed first**, never-performed routines leading
  (owner-confirmed 2026-08-25). Uses `TemplateSummary.lastPerformedAt`, which already exists, and
  surfaces what you are neglecting — usually the right prompt.
- **The week strip stays Sunday–Saturday**, reusing the built `WeekDotStrip` (CMP-020)
  (owner-confirmed 2026-08-25). The reference runs a rolling week from today; two contradictory week
  models on two tabs would be a worse inconsistency than differing from the reference.
- **The FAB starts an ad-hoc session**, not a routine picker (owner-confirmed 2026-08-25) — the
  capability T-012 exists to provide.

## Deviations from S-003

- The week strip shows weekday initials and a trained dot, **not dates**, because that is what
  CMP-020 already renders on the You tab. Adding dates would have to change both.
- No Insights row, no avatar, no calendar icon (see Scope out).
- The reference offers start-workout **twice** in the empty state (row CTA *and* FAB). We keep both,
  since they are the same action and the FAB survives scrolling.

## Files touched

- `lib/features/templates/ui/workout_screen.dart` — rebuilt
- `lib/features/templates/domain/workout_day.dart` (new) — `suggestedRoutines`, `sessionsOn`
- `lib/features/templates/ui/start_workout_action.dart` — `startAdHocWorkout`, and the
  already-running-session dialog extracted so both entry points share it

## Model / DB changes

**None.**

## Retired tests

`test/widget/workout_screen_test.dart` covered the routine list, which no longer exists here. Its
three assertions are not lost — they moved with the behaviour:

| Retired assertion | Now covered by |
|---|---|
| empty state invites creating the first workout | `library_screen_test` (the create row) |
| a workout card shows its exercise and set counts | `library_screen_test` (exercise count) + `routine_detail_test` (total sets) |
| Start is disabled for a template with no exercises | `routine_detail_test` ("an empty routine cannot be started") |

## Edge cases

- **No routines at all** — no suggestions section; the CTA and FAB still start an ad-hoc session.
- **A session already running** — starting another goes through the existing resume-or-discard
  dialog.
- **A session logged today but not finished** — only *completed* sessions count as "workouts today".
- **Sessions spanning midnight** — a session is attributed to the day it **ended**, matching how
  history and the week strip already read it.

## Acceptance criteria

- [x] The tab shows today's date and the week strip.
- [x] With no workout today: `No workouts today` and a `Start new workout` row.
- [x] With a workout today: it is listed with its duration and volume, and the suggestions are gone.
- [x] Suggestions rank never-performed first, then least recently performed.
- [x] The FAB starts an ad-hoc session and lands on it.
- [x] The old routine list, and its Edit/Duplicate/Delete menu, are gone.
- [x] `flutter analyze` clean; `flutter test` passes (326).

## QA checklist (on device)

- [ ] Open the tab with nothing logged — empty state, suggestions, FAB.
- [ ] FAB → empty session → add an exercise → log a set → finish.
- [ ] Reopen the tab — the workout is listed and suggestions are gone.
- [ ] A never-performed routine leads the suggestions.

## Two more retired assertions

Beyond the routine-list tests, `shell_navigation_test` carried two expectations this ticket
invalidates:

- **"the Workout tab's EXERCISES action opens the library"** — deleted. That header action is gone:
  Explore is a bottom-nav tab under ADR-005, and S-003's top bar carries no such control. The test's
  own comment already noted "Explore is a tab now".
- **`expect(find.widgetWithText(AppBar, 'Workout'))`** — the top bar shows the *date* now, so the
  tab is identified by its empty-state heading instead.

## Notes for next time

Two widget-test traps cost time here, both already known to this codebase and both worth re-reading
before writing session- or template-backed tests:

- **Never `await` a Drift stream's `.first` inside a `testWidgets` body.** It needs real async turns
  the fake clock does not provide, and the run *wedges* instead of failing. Have the fixture return
  the ids it created.
- **A test that fails before `disposeAndDrainTimers` wedges the whole file**, because the drift
  cleanup timer is left pending. A red run therefore looks like a hang. Read the head of the log.

## Revision log
- 2026-08-25 — created from S-003 after T-012 unblocked the FAB.
