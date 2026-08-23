# Roadmap

- **Status:** Draft — sequences the [gap analysis](05-gap-analysis.md) under
  [ADR-005](../../decisions/ADR-005-adopt-five-tab-navigation.md)
- **Last updated:** 2026-08-23

Sequencing principle: **the session loop is the product.** Everything else is preparation or
reflection. Schema changes come before the UI that depends on them; navigation lands only when the
tabs it creates have something in them.

---

## Phase 1 — Make logging fast (Must)

The four Musts from the gap analysis, in dependency order. Nothing here touches navigation.

| # | Work | Effort | Depends on |
|---|---|---|---|
| 1 | **Prescription schema** — `defaultWeight`, `targetReps`, `targetRepsMax` (+ rep-mode) on `TemplateExercises` **and** `SessionExercises`; migrate to schema v3. `targetSets`, `restSeconds`, `defaultRir` already exist | L | — |
| 2 | **Prescription editor** (CMP-017) — sets · reps *or* range (mode dropdown) · RIR · weight, in the template exercise settings sheet (S-010) | M | 1 |
| 3 | **Pre-filled set rows** (CMP-015 part 1) — pending rows carry the plan in muted text; a to-plan set is one tap on ✓ | M | 1, 2 |
| 4 | **Custom numeric keypad** (CMP-018) — big digits, `.` only for weight, `RIR` key, `Next` chaining and wrapping | M | — |
| 5 | **`Previous` column** (CMP-015 part 2) — best set of the previous session, `60kg x 6` | M | 1 |
| 6 | **WIP bar** (CMP-001) — `Workout in Progress` above the bottom nav, on every tab | M | — |
| 6b | **[T-004](../../tickets/T-004-exercise-taxonomy.md) exercise taxonomy + favourites** — schema v3; primary/secondary muscles, single-valued equipment, `isFavourite` + list filter. Moved into MVP by owner 2026-08-23 | L | — |

Items 4 and 6 depend on nothing and can go first or in parallel. **6 is the best opener**: highest
visible change per unit of risk, and it touches `app_shell.dart`, which Phase 3 rebuilds anyway.

**Migration order:** T-004 takes **schema v3** (T-002 is blocked), so T-002 becomes **v4**. Do not
develop them in parallel without honouring that order.

**Phase 1 exit:** a to-plan set is one tap; the previous session is visible while logging; a session
can be left and resumed from any tab.

## Phase 2 — Make the session surface match (Should)

| # | Work | Effort |
|---|---|---|
| 7 | **Session stats strip** (CMP-002) — `Duration · Volume · Sets`, keeping the existing plan-progress rule alongside or replacing it | S |
| 8 | **Single-open accordion** — collapsed rows show `n/m done`; inline `Notes…` and `Rest Timer` in the expanded exercise | M |
| 9 | **Ad-hoc empty session** — FAB starts a session with no exercises (`templateId` is already nullable) | M |
| 10 | **Editable finish flow** (S-023) — validation modal listing unfilled exercises, then an editable record (name, date, duration, difficulty) before save | M |
| 11 | **Set-completion feedback** — decide the tension: full-row green tint vs. the current ledger-line grammar. **A design call, not a defect** | S |

## Phase 3 — Navigation (Should)

Only once the tabs have contents. Order matters: build the destination, then move the door.

| # | Work | Effort |
|---|---|---|
| 12 | **Weekly summary + session list on Home** (CMP-008, CMP-013, CMP-012) — absorbing History's content | M |
| 13 | **Date header + week strip + today's workouts** on Workout (CMP-005) | M |
| 14 | **`You` stats hub** — sub-tab bar, Overview pane (Workout Log dot-strip → full history, Personal Records), settings demoted to a top-bar gear (CMP-009, CMP-010, CMP-020, CMP-021) | L |
| 14b | **Muscle-based browsing UI** — the Explore grids over T-004's data (T-004 itself moved to Phase 1) | M |
| 15 ✅ | **Five-tab shell** (ADR-005) — **done 2026-08-23, pulled forward at the owner's request** — `Home · Explore · Workout · Library · You`; promote `/exercises` to a branch; move History under You → Overview; move Settings to a top-bar gear; check label truncation at five items | M |

~~**15 comes last on purpose.**~~ **Superseded 2026-08-23:** the owner chose to land the shell first
and fill the screens after. The trade-off stands — Library and You are thin until 12–14 land — but
the shell is now the thing the remaining screen work slots into, rather than a migration at the end.

## Phase 4 — Later

| Work | Effort | Note |
|---|---|---|
| Personal records (ADR-004) — weight · est. 1RM · volume · reps, lifetime | M | Purely additive; needs a caching strategy |
| Suggested routines + hide-once-logged | M | Needs a suggestion rule |
| Initials tiles for routines (CMP-011) | S | Cheap; no image pipeline |
| Rest-timer chrome (CMP-016) — reserved top-bar slot | S | Ours already survives process death; protect that |
| First-run onboarding card (CMP-014) | S | |
| Insights tiles, streaks | M | Motivation, not training |
| Post-save acknowledgement | S | The *timing* of S-024, none of the sharing |
| Per-exercise History / Progress panes (S-025) | L | Owner: explicitly **Later**, not MVP — needs history aggregation + charts |
| Pre-built exercise catalogue | L | Phase B of [ADR-006](../../decisions/ADR-006-exercise-library-phasing.md) |
| Multi-valued equipment | M | Only if single-value proves painful |

## Never

Community programs · coaches · feed, likes, comments, share · friend invites · challenges ·
`AI feedback` · `% Recovered` · share-card export.

---

## Blocked pending screenshots

- **Item 2** (prescription editor) is specified from description alone. `ref-S004-library-routine-edit.png`
  would confirm the reps/range mode toggle before the schema is fixed. **Item 1 should not ship
  before that shot**, since a migration is expensive to redo.
- ~~Item 14 needs S-005 screenshots~~ — **received 2026-08-23** (Overview pane). The `Exercises`,
  `Measures` and `Photos` panes are still unseen, but Overview is enough to start item 14.

## First three tickets

- [T-001](../../tickets/T-001-wip-bar.md) — WIP bar (item 6)
- [T-002](../../tickets/T-002-prescription-schema.md) — prescription schema (item 1)
- [T-003](../../tickets/T-003-numeric-keypad.md) — custom numeric keypad (item 4)

A fourth is now queued behind Phase 3: [T-004](../../tickets/T-004-exercise-taxonomy.md) — exercise
taxonomy (item 14b).

Chosen because all three depend on nothing else, cover the two riskiest areas (shell, schema) plus
the highest payoff-per-effort item, and can be reviewed independently.

## Revision log
- 2026-08-23 — added item 14b (T-004 taxonomy); History rehomed to You → Overview per owner decision.
- 2026-08-23 — created from the gap analysis, sequenced under ADR-005; first three tickets proposed.
