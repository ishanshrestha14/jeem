# Gap Analysis

- **Status:** Partial — covers the **session loop** (S-006/S-015), **Workout tab** (S-003/S-008) and
  **Home** (S-001/S-007). Library (S-004) and You/Profile (S-005) are **not yet screenshotted** and
  are deferred to a second pass.
- **Last updated:** 2026-08-23
- **MVP code read:** `lib/db/tables.dart`, `lib/app/router.dart`, `lib/app/app_shell.dart`,
  `strength_set_row.dart`, `session_progress_header.dart`, `home_screen.dart`, `numeric_field.dart`

Effort: **S** ≈ one sitting · **M** ≈ a ticket with UI + provider work · **L** ≈ schema change,
migration, and multiple surfaces.

## 1. Session loop — the core of the app

| Area | Current MVP | Target UX | Gap | Effort | Priority |
|---|---|---|---|---|---|
| **Prior performance** | Nothing. A set row gives no indication of what was done before | `Previous` column: best set of the last session, `60kg x 6` | **No history surfaced during logging.** The single biggest functional gap | M | **Must** |
| **Set prescription** | `TemplateExercises` has `targetSets`, `restSeconds`, `defaultRir`, `defaultDurationSeconds` — but **no target weight and no target reps/range** | Routine prescribes sets · reps *or* range (mode toggle) · RIR · weight; session rows pre-fill from it | Narrower than first assumed — **RIR and targetSets already exist**. Needs `defaultWeight`, `targetReps`, `targetRepsMax` (or a rep-mode enum) on `TemplateExercises` **and** the same on `SessionExercises`, which snapshots the template | L | **Must** |
| **Empty vs. pre-filled rows** | `NumericField`s start empty; every set is typed from scratch | Pending rows carry the plan in muted text; to-plan set = one tap on ✓ | Depends on the row above. This is what makes logging fast | M | **Must** |
| **Numeric entry** | System keyboard via `numeric_field.dart` (`allowDecimal: true`) | Custom keypad: big digits, `.` **only when editing weight**, `RIR` key, `Next` that chains fields and wraps into the next set | Layout shift mid-set, small keys, no domain keys. Self-contained widget, **no schema change** | M | **Must** |
| **Session-level stats** | `SessionProgressHeader` shows `n/m sets`, `n/m exercises` + a hairline rule | Boxed strip: `Duration · Volume · Sets` (+ `Records` once PRs exist) | We show *progress through the plan*; they show *what you've done*. Different question answered — arguably both are worth having | S | **Should** |
| **Minimise / resume** | `_ResumeCard` on Home **only**; leave `/session` for any other tab and the session is invisible | `Workout in Progress` strip above the bottom nav on every tab, `Resume` + `Discard`, pushes the FAB up | Session is route-owned, not app-owned. Needs to move into `app_shell.dart` | M | **Must** |
| **Ad-hoc session** | None — every session starts from a template (`start_workout_action.dart`) | FAB starts an empty session; add exercises as you go | `WorkoutSessions.templateId` is already nullable, so the model allows it | M | **Should** |
| **Exercise layout** | Per-exercise cards (`session_exercise_card.dart`) | **Single-open accordion**; collapsed rows show `n/m done` only | Screen real estate: theirs shows the whole routine at a glance | M | **Should** |
| **Notes & rest placement** | Behind sheets (S-010 / S-017) | Inline in the expanded exercise: `Notes…` and `⏱ Rest Timer: 3min` | Ours are more taps and less discoverable | S | **Should** |
| **Set completion feedback** | `SetBadge` + a 1px underline on the current row | Whole row tinted green; ✓ is a filled circle in both states | Ours is subtle by design ("ledger, not cards"). Theirs is readable at arm's length. **A genuine design tension — not automatically a defect** | S | **Should** |
| **Rest timer chrome** | `rest_bar.dart` / `rest_sheet.dart` | Reserved top-bar slot: idle stopwatch → accent countdown pill + thin progress line. Bar never reflows | Ours already persists across restarts, which theirs may not. Mostly a placement question | S | **Later** |
| **Finish flow** | `SessionSummaryScreen` — read-only summary with Save/Discard | Validation modal listing unfilled exercises → **editable** `Finish Workout` form (name, date, duration, media, difficulty) → celebration | Ours cannot correct a wrong duration or rename after the fact | M | **Should** |
| **Personal records** | None anywhere in `lib/` | Lifetime PRs on weight · est. 1RM · volume · reps ([ADR-004](../../decisions/ADR-004-pr-metrics.md)) | Purely additive; nothing depends on it | M | **Later** |

## 2. Workout tab

| Area | Current MVP | Target UX | Gap | Effort | Priority |
|---|---|---|---|---|---|
| **Date context** | None | Month + day header, 7-day strip starting at today, calendar button | No sense of "when" anywhere in the app | M | **Should** |
| **Today's workouts** | Template list only | `Workouts` section listing today's sessions with duration + volume | We show what you *could* do, never what you *did* today | S | **Should** |
| **Empty state** | UNVERIFIED (`empty_state.dart` exists) | `No workouts today` + full-width CTA row *and* a FAB — start offered twice | Ours is likely one CTA | S | **Later** |
| **Suggested routines** | None | Carousel of routine cards, **hidden once a workout is logged that day** | Needs a suggestion rule; the hiding behaviour is the clever half | M | **Later** |
| **Routine thumbnails** | UNVERIFIED | Generated colour tile + 2-letter initials — no images | Cheap: no image pipeline, no empty-thumbnail state | S | **Later** |
| **Insights** | None | Tile carousel | Mostly out of scope (`AI feedback`, `% Recovered`) | — | **Later** |

## 3. Home

| Area | Current MVP | Target UX | Gap | Effort | Priority |
|---|---|---|---|---|---|
| **Weekly summary** | UNVERIFIED whether any aggregate is shown | `Workouts · Duration · Volume` with green delta chips vs. last week | Same three metrics as the session strip, aggregated | M | **Should** |
| **Session list** | `_ResumeCard` + UNVERIFIED | Feed of completed sessions with name, time, duration, volume, records | The *card* is worth taking; the social frame is not | S | **Should** |
| **First-run** | `empty_state.dart` | Illustration + question headline + rationale + CTA | We have the component; may not have the copy | S | **Later** |
| **Nagging discipline** | UNVERIFIED | Home motivates; the session **never** does | Worth copying as a rule, not a feature | — | **Must** |

## 4. Navigation & IA

| Area | Current MVP | Target UX | Gap | Effort | Priority |
|---|---|---|---|---|---|
| **Profile tab** | `/profile` builds **`SettingsScreen`** directly | `You` = stats hub (Overview · Exercises · Measures · Photos); settings demoted to a top-bar icon | **Largest IA gap.** A whole primary tab spent on settings | L | **Should** |
| **Exercises placement** | Pushed route `/exercises`, no tab | Explore tab: pinned search + browse by muscle group and equipment | Depth, plus **[T-004](../../tickets/T-004-exercise-taxonomy.md)**: `Exercises` has one nullable `category` and **no muscle or equipment field** — neither browse axis is expressible | L | **Should** |
| **History placement** | `/history` primary tab | `You` → Overview → Workout Log dot-strip + `See full workout history` | Owner decision: History keeps its screen, loses its tab | M | **Should** |
| **Personal-record surface** | none | PR list on You → Overview: exercise, value, achieving set, date | Display side of [ADR-004](../../decisions/ADR-004-pr-metrics.md) | M | **Later** |
| **Trend charts** | none | Swipeable stat cards: metric, big value, delta, date range, line chart | Charting is entirely new for us — no chart code in `lib/` | L | **Later** |
| **Tab count** | 4: Home · Workout · History · Profile | 5: Home · Explore · Workout · Library · You | ~~Do not copy 5 tabs uncritically~~ — **superseded 2026-08-23 by [ADR-005](../../decisions/ADR-005-adopt-five-tab-navigation.md): adopt the 5-tab shell.** History's tab retires; its content moves to Home | M | **Should** |
| **Sub-tabs** | None; no `TabBar` anywhere in `lib/` | Explore (3) and You (4) are tabbed screens | Needed only if we build the stats hub | M | **Later** |

## 5. Deliberately not adopted

Community programs · coaches · likes/comments/share · friend invites · challenges · `AI feedback` ·
`% Recovered` · the share-card carousel (S-024). All out of scope per
[00-overview §5](00-overview.md#5-explicitly-out-of-scope). Streaks are computable offline but are
motivation, not training — `Later` at best.

## 6. What the MVP already does better

Worth protecting during any redesign:

- **Rest timer survives process death** — anchored on `restEndsAt` in the DB, with
  `restRemainingSeconds` authoritative while paused. Genuinely hard, already done.
- **Pause/resume with accurate accounting** — `pausedAt` is deliberately used instead of `updatedAt`
  so unrelated edits during a pause don't shrink the measured pause. That's a real bug, already fixed.
- **Completed sets stay editable** — nothing is ever disabled or blocks completion on missing values.
- **Session-only reordering** and a proper template **snapshot** at session start.
- **JSON export/import** — the reference app has no local backup story at all.
- **Duration-logged exercises** as a first-class logging type.

## 7. Pending — needs screenshots

- **S-004 Library** — how routines are built. Blocks the exact shape of the prescription schema.
- ~~S-005 You~~ — **received 2026-08-23** (Overview pane; Exercises/Measures/Photos panes still unseen).
- ~~S-002 Explore~~ — **received 2026-08-23** (Exercises pane).
- **S-005 sub-panes** — Exercises, Measures, Photos.
- **S-004 Library** — still the blocker on T-002.

## Revision log
- 2026-08-23 — created; covers the session loop, Workout tab, Home and IA. Library/You deferred.
- 2026-08-23 — §4 tab-count row superseded by ADR-005 (adopt 5 tabs).
