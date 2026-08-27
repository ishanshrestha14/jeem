# T-015 — Rebuild Home against S-001

- **Status:** **Done** (2026-08-25) — `flutter analyze` clean, 350 tests pass.
- **Priority:** Must
- **Effort:** M
- **Specs:** S-001, CMP-008, CMP-012, CMP-013, CMP-014
- **Last updated:** 2026-08-25

## Goal

Home was `Quick start` (routine cards with Start buttons) plus `Last workout` — which made it the
**fourth** place routines were listed, after the Library, the Workout tab's suggestions and the
routine detail screen. S-001 wants a recap: a weekly summary over a session list.

This is the last surface that was drifted from its spec.

## Scope (in)

- `Your weekly summary` — **Workouts · Duration · Volume** for this week, each with its change
  against last week (CMP-008 + CMP-013).
- `Recent workouts` — the last five, with `See all` to the History screen.
- The first-run card when nothing has been logged (CMP-014).
- Retire `Quick start` and `Last workout`.

## Scope (out)

- **The entire social layer** — feed framing, avatars, likes, comments, share, friends, challenges.
  S-001 scopes these out itself.
- **`Records 🏅 N` per session** (owner-confirmed 2026-08-25). We have ADR-004's PR metrics but no
  per-session record count, and building one needs a decision first: does a record count against the
  history *up to that session*, or against all history? Those differ, and the answer changes what the
  badge means. Left as an open question on S-001.
- **`See more`** on the summary — S-001 lists it as an open question (a dedicated weekly-stats
  surface); we have nowhere for it to go.
- The `Home ⌄` dropdown, streak flame, add-friend and bell in the top bar.

## Decisions

- **No routine list** (owner-confirmed 2026-08-25). Home is recap; the Workout tab is the launchpad
  (S-003) and the Library owns routines (S-004).
- **Five recent workouts, then `See all`** (owner-confirmed 2026-08-25). Home is a recap and History
  is the archive; listing everything in both would make them one screen twice.
- **The week is Sunday–Saturday**, via a `weekStart` helper now shared with CMP-020's strip — see
  below.
- **A delta chip appears only when something changed.** An unchanging `0` under every metric is
  noise, and the first week has nothing to compare against.
- **Only an increase is coloured.** A quieter week is not a failure and should not be painted like
  one; `danger` is reserved for destructive actions (design system).

## Deviations from S-001

- **No FAB.** S-001 §6 has one, but the Workout tab is the launchpad and the first-run card already
  carries a `Start workout` button. A third FAB would be a third start affordance — and, as T-014
  found, every extra FAB is another hero-tag hazard.
- Sessions are listed as rows, not feed posts, since the post framing is the social layer.

## Files touched

- `lib/features/dashboard/domain/weekly_summary.dart` (new)
- `lib/features/dashboard/ui/home_screen.dart` — rebuilt
- `lib/core/utils/formatting.dart` — `weekStart`
- `lib/features/profile/ui/widgets/week_dot_strip.dart` — now aliases `weekStart`

## One definition of "the week"

`WeekDotStrip` had its own `startOfWeek`. Rather than write a second copy for the summary, the
definition moved to `core/utils/formatting.dart` as `weekStart`, and the strip aliases it. Two views
of "this week" that disagreed would be a real bug and an invisible one — the strip would fill a dot
for a workout the summary had not counted.

## Retired tests

`dashboard_home_test.dart` is deleted; one screen now has one test file.

| Retired assertion | Where it went |
|---|---|
| shows the empty state when there are no templates | `home_screen_test` — the first-run card |
| quick start orders templates by most recently performed | Gone with Quick start. The Workout tab's suggestions cover routine ordering, least-recently-performed first (T-013) |
| Home does not surface a live session (T-001 guard) | **Carried over** into `home_screen_test` — it guards a rule this rebuild does not change |

`shell_navigation_test` keyed on Home's old `Go to Workout` copy; it now keys on the summary heading,
which is present whether or not anything is logged.

## Edge cases

- **No history** — every metric reads `0` rather than blank; a scoreboard showing zero is meaningful.
- **First week ever** — no deltas render, since there is no prior week to compare.
- **A session spanning midnight, or a week boundary** — attributed to the week it *ended* in,
  matching the Workout tab and history.
- **An incomplete set** adds no volume, matching `completedVolume` everywhere else.

## Acceptance criteria

- [x] The summary shows workouts, duration and volume for this week.
- [x] Deltas compare against the previous week, and are absent when unchanged.
- [x] With no history everything reads zero and the first-run card invites a workout.
- [x] Recent workouts are listed, capped at five, with `See all`.
- [x] No routines are listed.
- [x] Home still does not surface a live session (T-001).
- [x] `flutter analyze` clean; `flutter test` passes (350).

## QA checklist (on device)

- [x] Fresh install — zeros and the first-run card.
- [x] Log a workout — the summary moves and the card is replaced by the list.
- [x] Log a second week — deltas appear against the first.
- [x] `See all` opens History; tapping a row opens that session's summary.

## Revision log
- 2026-08-25 — created and shipped. Owner scoped out the routine list, capped the session list, and
  deferred the per-session record count.
