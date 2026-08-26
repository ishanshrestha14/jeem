# GymFlow Docs

Documentation home for the GymFlow personal workout app (Flutter + Riverpod + GoRouter + Drift, Android-first, offline, dark theme default).

Created: 2026-08-23. Phase A (documentation) is active. No app code changes happen from this folder.

---

## 1. Folder map

```
docs/
  README.md                     <- you are here: ID registry, conventions, templates, status
  research/reference-app/
    00-overview.md              reference app IA: tabs, nav model, mental model
    01-feature-inventory.md     F-IDs
    02-screen-inventory.md      S-ID index table
    03-user-flow-inventory.md   FL-ID index table
    04-ui-patterns.md           reusable UI patterns + our Flutter component mapping
    05-gap-analysis.md          reference UX vs current MVP
    06-roadmap.md               phases, priorities, implementation order
    screenshots/                dropped images, referenced by filename only
  specs/screens/S-00X-<slug>.md
  specs/flows/FL-00X-<slug>.md
  specs/components/CMP-00X-<slug>.md
  tickets/T-00X-<slug>.md
  decisions/ADR-00X-<slug>.md
  design/gymflow-design-system.md   (pre-existing) visual language
  MANUAL_TEST_PLAN.md               (pre-existing) on-device QA
  BUILD_ENVIRONMENT.md              Android SDK / JDK setup, and the two build failures it caused
  superpowers/plans/                (pre-existing) original MVP build plan
```

## 2. ID rules

| Prefix | Meaning | Lives in |
|---|---|---|
| `S` | Any UI surface: screen, bottom sheet, dialog, overlay, banner. Record its **type**. | `specs/screens/` |
| `FL` | User flow (multi-step task across surfaces) | `specs/flows/` |
| `CMP` | Reusable component / widget | `specs/components/` |
| `F` | Feature (capability, not a surface) | `research/reference-app/01-feature-inventory.md` |
| `T` | Implementation ticket | `tickets/` |
| `ADR` | Architecture / product decision | `decisions/` |

Rules:
- IDs are zero-padded to 3 digits (`S-001`), assigned in order of first appearance.
- **IDs are never reused**, even if a spec is deprecated. Mark it `Status: Superseded by S-0XX` instead of deleting.
- The **same surface seen in multiple screenshots merges into one spec**. Add the extra screenshot filenames to that spec's `Screenshots:` list and log a dated revision note.
- Anything not directly visible/derivable from a screenshot or from `lib/` is tagged **UNVERIFIED**.
- Filenames are `<ID>-<kebab-slug>.md`.

## 3. Conventions

- Every spec starts with the standard front block: ID, Title, Type, Status, Source, Screenshots, Last updated.
- `Status` values: `Draft` | `Reviewed` | `Implemented` | `Superseded`.
- Never delete history. Each edit appends a line to the spec's **Revision log** with the date (`YYYY-MM-DD`) and what changed.
- Reference-app material describes **UX patterns only**. No branding, copy, icons, images, or asset names are copied. Our implementation is original.
- Open questions live in the spec's **Open questions** section and are restated (max 3 at a time) at the end of each reply.

---

## 4. ID registry

### Screens / surfaces (S)

One namespace for both apps — read `Source`. See [ADR-001](decisions/ADR-001-single-s-id-namespace.md).
Full detail, counterparts and gaps: [`02-screen-inventory.md`](research/reference-app/02-screen-inventory.md).

| ID | Source | Title | Type | Status |
|---|---|---|---|---|
| S-001 | reference | Home | screen | **Implemented — [spec](specs/screens/S-001-reference-home.md)** |
| S-002 | reference | Explore | screen, tabbed | **Draft — [spec](specs/screens/S-002-reference-explore.md)** |
| S-003 | reference | Workout | screen | **Implemented — [spec](specs/screens/S-003-reference-workout-tab.md)** |
| S-004 | reference | Library | screen | **Draft — [spec](specs/screens/S-004-reference-library.md)** |
| S-005 | reference | You | screen, tabbed | **Draft — [spec](specs/screens/S-005-reference-you-tab.md)** |
| S-006 | reference | Active session | screen | **Draft — [spec](specs/screens/S-006-reference-active-session.md)** |
| S-007 | ours | Home / dashboard | screen | Implemented |
| S-008 | ours | Workout (templates) | screen | Implemented |
| S-009 | ours | Template editor | screen | Implemented |
| S-010 | ours | Template exercise settings | bottom sheet | Implemented |
| S-011 | ours | Exercise list | screen | Implemented |
| S-012 | ours | Exercise editor | screen | Implemented |
| S-013 | ours | Exercise info | bottom sheet | Implemented |
| S-014 | ours | Exercise picker | bottom sheet | Implemented |
| S-015 | ours | Active session | screen | Implemented |
| S-016 | ours | Session reorder | screen | Implemented |
| S-017 | ours | Session settings | bottom sheet | Implemented |
| S-018 | ours | Session summary | screen | Implemented |
| S-019 | ours | History | screen | Implemented |
| S-020 | ours | Settings | screen | Implemented |
| S-021 | ours | Rest sheet | bottom sheet | Implemented |
| S-022 | ours | Notification permission prompt | overlay | Implemented |
| S-023 | reference | "Finish Workout" form | screen | **Draft — [spec](specs/screens/S-023-reference-finish-workout-form.md)** |
| S-024 | reference | Post-save celebration / share | modal | **Draft — [spec](specs/screens/S-024-reference-celebration-share.md)** |
| S-025 | reference | Exercise detail | screen, tabbed | **Draft — [spec](specs/screens/S-025-reference-exercise-detail.md)** |
| S-026 | reference | Exercise browser / picker | modal | **Draft — [spec](specs/screens/S-026-reference-exercise-browser.md)** |
| S-027 | reference | "Create Exercise" form | screen | **Draft — [spec](specs/screens/S-027-reference-create-exercise.md)** |
| S-028 | reference | "Create Routine" / routine builder | screen | **Draft — [spec](specs/screens/S-028-reference-create-routine.md)** |
| S-029 | reference | Routine exercise menu | bottom sheet | **Draft — [spec](specs/screens/S-029-reference-routine-exercise-menu.md)** |
| S-030 | reference | Routine detail | screen | **Implemented — [spec](specs/screens/S-030-reference-routine-detail.md)** |

Next free S-ID: **S-031**.

S-028 and S-029 were written during T-002 but never added to this table — corrected 2026-08-25.

`Status: Implemented` on our rows means the surface exists in `lib/`; it does **not** mean a written
spec exists. No `specs/screens/` files have been authored yet.

### Flows (FL)
| ID | Title | Status | Spec |
|---|---|---|---|
| FL-001 | Start a workout | Draft | [spec](specs/flows/FL-001-start-a-workout.md) |
| FL-002 | Log a set | Draft | [spec](specs/flows/FL-002-log-a-set.md) |
| FL-003 | Finish a workout | Draft | [spec](specs/flows/FL-003-finish-a-workout.md) |
| FL-004 | Delete a logged workout | Draft | [spec](specs/flows/FL-004-delete-a-workout.md) |

Next free FL-ID: **FL-005**. Still underived: build/edit a routine, exercise info, and the
programs flows.

### Components (CMP)

Detail: [`04-ui-patterns.md`](research/reference-app/04-ui-patterns.md). "Candidate" = identified, not yet specced.

| ID | Title | Status |
|---|---|---|
| CMP-001 | Minimised-session bar ("WIP" bar) | Candidate |
| CMP-002 | Live session stats strip (duration · volume · sets) | Candidate |
| CMP-003 | Set-completion-triggered rest timer | Candidate |
| CMP-004 | Add-exercise affordance inside a live session | **Built** — [T-012](tickets/T-012-adhoc-sessions.md) |
| CMP-005 | Week strip / date header | Candidate |
| CMP-006 | Suggested-routine card | Candidate |
| CMP-007 | Insights block | Candidate |
| CMP-008 | Weekly summary header | **Built** — [T-015](tickets/T-015-home-tab.md) |
| CMP-009 | Sub-tab bar within a primary tab | Candidate |
| CMP-010 | Utility buttons in the top bar | Candidate |
| CMP-011 | Initials tile (routine thumbnail) | Candidate |
| CMP-012 | Workout summary card | Candidate |
| CMP-013 | Delta chip | **Built** — [T-015](tickets/T-015-home-tab.md) |
| CMP-014 | First-run onboarding card | **Built** — [T-015](tickets/T-015-home-tab.md) |
| CMP-015 | **Set table row** (Previous · pre-filled · completed wash) | **Built** — [T-008](tickets/T-008-plan-prefill.md) plan pre-fill, [T-009](tickets/T-009-previous-best.md) `Previous`, [T-010](tickets/T-010-completed-row-wash.md) completed-row wash (chalk, not green) |
| CMP-016 | Top-bar rest slot | Candidate |
| CMP-017 | **Per-exercise prescription editor** (sets · reps/range · RIR · weight) | Candidate |
| CMP-018 | **In-session numeric keypad** (RIR key, Next chaining) | Candidate |
| CMP-019 | Stat chart card (metric · value · delta · range · line chart) | Candidate |
| CMP-020 | Week dot-strip (workout log) | Candidate |
| CMP-021 | Personal-record row | Candidate |
| CMP-022 | Taxonomy grid cell (muscle / equipment) | Candidate |
| CMP-023 | Action chip row | Candidate |
| CMP-024 | Favourite (bookmark) toggle | Candidate |
| CMP-025 | Exercise card | Candidate |
| CMP-026 | Filter-count badge | Candidate |
| CMP-027 | Label/value detail row (opens a picker) | Candidate |

Next free CMP-ID: **CMP-028**.

### Features (F)
| ID | Title | Status |
|---|---|---|
| _none yet_ | | |

### Tickets (T)
| ID | Title | Status | Effort | Specs |
|---|---|---|---|---|
| [T-001](tickets/T-001-wip-bar.md) | "Workout in Progress" bar above the bottom nav | **Done** | M | CMP-001 |
| [T-002](tickets/T-002-prescription-schema.md) | Set prescription on templates (schema v3) | **Blocked** — needs routine-builder screenshot | L | CMP-017 |
| [T-003](tickets/T-003-numeric-keypad.md) | In-session numeric keypad | **Done** | M | CMP-018 |
| [T-004](tickets/T-004-exercise-taxonomy.md) | Muscle group + equipment taxonomy on exercises | **Done** (schema v3) | L | S-002, S-026, CMP-022, CMP-024 |
| [T-005](tickets/T-005-plural-primary-muscles.md) | Correct the exercise taxonomy: body parts + plural muscles (schema v4) | **Done** (schema v4) | L | S-025, S-027 |
| [T-006](tickets/T-006-programs.md) | Programs: a container above routines (schema v5) | **Done** (schema v5) | L | S-004 |
| [T-007](tickets/T-007-you-overview.md) | Rebuild the You tab against S-005 | **Done** | M | S-005, ADR-004 |
| [T-008](tickets/T-008-plan-prefill.md) | Pre-fill live session rows from the plan | **Done** | M | S-006, CMP-015 |
| [T-009](tickets/T-009-previous-best.md) | `Previous`: last session's best set | **Done** | M | S-006, CMP-015, ADR-004 |
| [T-010](tickets/T-010-completed-row-wash.md) | Completed-row wash — closes CMP-015 | **Done** | S | S-006, CMP-015 |
| [T-011](tickets/T-011-routine-detail.md) | Routine detail screen + play button | **Done** | M | S-030, S-004, CMP-011 |
| [T-012](tickets/T-012-adhoc-sessions.md) | Ad-hoc sessions + add exercises mid-session | **Done** | M | S-006, CMP-004 |
| [T-013](tickets/T-013-workout-tab.md) | Workout tab rebuilt against S-003 | **Done** | L | S-003, CMP-005 |
| [T-014](tickets/T-014-delete-logged-workout.md) | Delete a logged workout (+ FAB hero-tag fix) | **Done** | S | S-003, S-019 |
| [T-015](tickets/T-015-home-tab.md) | Rebuild Home against S-001 | **Done** | M | S-001, CMP-008, CMP-013 |
| [T-016](tickets/T-016-missing-routine.md) | Starting a deleted routine crashed | **Done** | S | FL-001 |

Next free T-ID: **T-017**.

### Decisions (ADR)
| ID | Title | Status |
|---|---|---|
| [ADR-001](decisions/ADR-001-single-s-id-namespace.md) | One S-ID namespace for both apps, with a `Source` field | Accepted |
| [ADR-002](decisions/ADR-002-dark-only-theme.md) | Dark-only theme, no light mode | Accepted |
| [ADR-003](decisions/ADR-003-volume-as-total-weight.md) | Volume is total weight moved, shown on every session | Accepted (1 open question) |
| [ADR-004](decisions/ADR-004-pr-metrics.md) | Personal records: four metrics, estimated 1RM included | Accepted (formula open) |
| [ADR-005](decisions/ADR-005-adopt-five-tab-navigation.md) | Adopt the reference app's 5-tab navigation | Accepted |
| [ADR-006](decisions/ADR-006-exercise-library-phasing.md) | Custom exercises first, seeded library later | Accepted |

Next free ADR-ID: **ADR-007**.

---

## 4b. Verified stack

Read from `pubspec.yaml` and `lib/` on 2026-08-23. This section is the check against the project
facts drifting from the repo — update it when dependencies change.

| Layer | Actual |
|---|---|
| SDK | Dart `^3.11.5`, Flutter |
| State | `flutter_riverpod ^2.6.1` — **v2, hand-written providers, no codegen** (`riverpod_annotation`/`riverpod_generator` are not dependencies) |
| Routing | `go_router ^17.5.0` — `StatefulShellRoute.indexedStack`, 4 branches |
| Persistence | `drift ^2.34.3` + `drift_dev`, `NativeDatabase.createInBackground`, `schemaVersion: 2` |
| Design | Material 3 (`useMaterial3: true`), **dark only** — see [ADR-002](decisions/ADR-002-dark-only-theme.md) |
| Type | **Barlow** + **Barlow Condensed** bundled as app fonts (400/500/600, Condensed also 700) |
| Platforms | `android/`, `ios/`, `macos/` folders exist; **Android is the only target** |
| Network | **None.** No HTTP/backend/auth dependency of any kind — fully offline |

Capability dependencies beyond the core four: `flutter_local_notifications` + `timezone` (rest-timer
notifications), `wakelock_plus` (keep-screen-on), `shared_preferences` (settings),
`image_picker` + `image` (exercise images), `share_plus` + `file_picker` + `path_provider`
(JSON backup export/import), `uuid`, `intl`, `path`.

**No new dependencies without asking** (Phase B rule).

## 5. Templates

### 5.1 Screen / surface spec — `specs/screens/S-00X-<slug>.md`

```markdown
# S-00X — <Title>

- **Type:** screen | bottom sheet | dialog | overlay | banner
- **Status:** Draft
- **Source:** reference app | our MVP | both
- **Screenshots:** <filename.png>, ...
- **Last updated:** YYYY-MM-DD

## Purpose
One paragraph: what this surface is for and when the user is here.

## Entry points
- From <S-ID / trigger>

## Layout & sections
1. **<Section name>** — what it contains, ordering, density.

## Data shown
| Element | Data | Source (our app) | Notes |
|---|---|---|---|

## Primary actions
| Action | Result | Destination |
|---|---|---|

## Secondary actions
| Action | Result |
|---|---|

## Components used
- CMP-00X — <name>

## Navigation out
- <trigger> -> S-0XX

## States
- **Empty:**
- **Loading:**
- **Error:**
- **Success:**
- **Other (paused / offline / in-progress):**

## Edge cases
-

## Open questions
- [ ]

## Revision log
- YYYY-MM-DD — created from <screenshot>.
```

### 5.2 Flow spec — `specs/flows/FL-00X-<slug>.md`

```markdown
# FL-00X — <Title>

- **Status:** Draft
- **Surfaces involved:** S-00X, S-00Y
- **Last updated:** YYYY-MM-DD

## Trigger
## Preconditions
## Happy path
1.
## Alternate paths
## Error paths
## Data changes
| Step | Table / entity | Mutation | Persisted when |
|---|---|---|---|
## UI states
## Acceptance criteria
- [ ]
## Open questions
## Revision log
```

### 5.3 Component spec — `specs/components/CMP-00X-<slug>.md`

```markdown
# CMP-00X — <Title>

- **Status:** Draft
- **Used by:** S-00X, ...
- **Our implementation:** lib/... (or "new")
- **Last updated:** YYYY-MM-DD

## Purpose
## Anatomy
## Props / inputs
| Name | Type | Required | Notes |
|---|---|---|---|
## Variants
## States
default | pressed | disabled | loading | selected | error
## Interaction & gestures
## Accessibility & touch targets
## Do / Don't
## Revision log
```

### 5.4 Ticket — `tickets/T-00X-<slug>.md`

```markdown
# T-00X — <Title>

- **Status:** Not started | Planned | In progress | Done
- **Priority:** Must | Should | Later
- **Effort:** S | M | L
- **Specs:** S-00X, FL-00X, CMP-00X
- **Last updated:** YYYY-MM-DD

## Goal
## Scope (in)
## Scope (out)
## Files to touch
## Model / DB changes
## New components
## Edge cases
## Acceptance criteria
- [ ]
## QA checklist (on device)
- [ ]
## Revision log
```

### 5.5 Decision — `decisions/ADR-00X-<slug>.md`

```markdown
# ADR-00X — <Title>

- **Status:** Proposed | Accepted | Superseded
- **Date:** YYYY-MM-DD

## Context
## Decision
## Consequences
## Alternatives considered
```

---

## 6. Known gaps in these docs

Two of the three spec folders are empty. Neither is an oversight to be quietly fixed — each has a
reason, recorded here so a fresh session does not mistake absence for loss.

### `specs/flows/` — partly closed (2026-08-26)

The brief listed a `derive flows` step; it went uninvoked through T-001..T-015, with the tickets
carrying flow detail inline instead. The **session lifecycle** is now derived — FL-001 start,
FL-002 log a set, FL-003 finish, FL-004 delete — written from the implementation rather than from
the brief, which is why each carries real open questions rather than restating what shipped.

Deriving them was worth it immediately, and for two things rather than one:

- **FL-001** surfaced that `startFromTemplate` threw an unhandled `StateError` when the routine is
  deleted between listing and starting — `deleteTemplate` is a *hard* delete, so the row is simply
  gone. No ticket had noticed. **Fixed the same day** as
  [T-016](tickets/T-016-missing-routine.md).
- Writing FL-004 exposed a **false claim in T-014 and in the code comment on `deleteSession`**, both
  of which said soft-delete was the pattern "every delete here" follows. It is not: `deleteTemplate`
  and `removeSet` drop rows outright. Corrected in all three places.

Still underived: build/edit a routine, exercise info, and the programs flows.

### `specs/components/` — empty, tracked elsewhere

CMP-001..CMP-027 are registered with behaviour, source surface and our Flutter mapping in
[`04-ui-patterns.md`](research/reference-app/04-ui-patterns.md), and several are now **built**
(CMP-001 the WIP bar, CMP-018 the keypad, CMP-020 the week strip, CMP-011 initials tiles). The
per-component template in §5.3 was never used, because the pattern table was enough to drive
implementation.

What that cost: built components have no spec of their own — no props table, no state list, no
do/don't. That matters more now that they are being reused rather than invented.

### Neither blocks anything

Every implemented ticket references the surface spec and ADR it came from. These gaps affect how
easy the *next* piece of work is to pick up, not whether the current state is understood.

## 7. Current status (2026-08-24)

| Type | Count |
|---|---|
| S (surfaces) | 30 registered (14 reference · 16 ours) — **16 written specs** |
| FL (flows) | **4 written** — the session lifecycle. Routine-building and programs still underived |
| CMP (components) | 27 candidates — **0 written specs.** See §6 |
| F (features) | 0 |
| T (tickets) | 16 — **all done** |
| ADR (decisions) | 6 |

**Last updated:** **T-015 shipped — every reference surface now matches its spec.** Home is a recap
(weekly summary with week-on-week deltas, then the last five workouts) instead of a fourth routine
list. Before it, T-012/T-013/T-014 gave us ad-hoc sessions, the S-003 Workout tab and workout
deletion. No schema change in any of the four. 354 tests pass, `flutter analyze` clean.

**Where the code is:** `main`, tracking `origin/main` at
`git@github.com:ishanshrestha14/jeem.git`. Schema **v6**. Local commits may be ahead of the remote. Five-tab shell
(Home · Explore · Workout · Library · You) live; Library and You rebuilt against S-004/S-005.

**Screenshot workflow:** paste into any note under `docs/`; Obsidian writes the PNG to disk and I
rename it into `screenshots/` under its manifest name.

**Next step (a fresh session starts here):**

1. **No reference surface is drifted any more** — S-001 through S-006 and S-030 are all built. The
   backlog is now the deferred pieces rather than a gap: per-session `Records 🏅 N` on Home (needs a
   decision on what window a record counts against), the estimated duration and muscle summary on
   S-030, and Insights on S-003.
2. Consider closing the §6 gaps — flows especially. T-008, T-009 and T-010 each carried their flow
   detail inline in the ticket again, which is the drift §6 warns about.
3. **RIR onto the keypad** (CMP-018 specs an `RIR` key) would free the set row's fifth column, and
   is the precondition for `Previous` becoming a per-row column as S-006 draws it.
4. **Nothing on the session screen is outstanding.** CMP-015, CMP-001, CMP-018 and CMP-020 are all
   built; the session work that has driven the last four tickets is done for now.

**Build/run:** see [`BUILD_ENVIRONMENT.md`](BUILD_ENVIRONMENT.md). `flutter run -d macos` is the
fast loop; `flutter build apk --release` for the phone.
