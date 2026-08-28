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
| S-007 | ours | Home / dashboard | screen | **Superseded by S-001** — rebuilt [T-015](tickets/T-015-home-tab.md) |
| S-008 | ours | Workout (templates) | screen | **Superseded by S-003** — the routine list was retired in [T-013](tickets/T-013-workout-tab.md) |
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
| S-023 | reference | "Finish Workout" form | screen | **Implemented — [spec](specs/screens/S-023-reference-finish-workout-form.md)** |
| S-024 | reference | Post-save celebration / share | modal | **Draft — [spec](specs/screens/S-024-reference-celebration-share.md)** |
| S-025 | reference | Exercise detail | screen, tabbed | **Implemented — [spec](specs/screens/S-025-reference-exercise-detail.md)** |
| S-026 | reference | Exercise browser / picker | modal | **Draft — [spec](specs/screens/S-026-reference-exercise-browser.md)** |
| S-027 | reference | "Create Exercise" form | screen | **Draft — [spec](specs/screens/S-027-reference-create-exercise.md)** |
| S-028 | reference | "Create Routine" / routine builder | screen | **Draft — [spec](specs/screens/S-028-reference-create-routine.md)** |
| S-029 | reference | Routine exercise menu | bottom sheet | **Draft — [spec](specs/screens/S-029-reference-routine-exercise-menu.md)** |
| S-030 | reference | Routine detail | screen | **Implemented — [spec](specs/screens/S-030-reference-routine-detail.md)** |

Next free S-ID: **S-031**.

S-028 and S-029 were written during T-002 but never added to this table — corrected 2026-08-25.

`Status: Implemented` on our rows means the surface exists in `lib/`; it does **not** mean a written
spec exists — none of S-007..S-022 has one. **Superseded** means the surface was rebuilt against a
reference spec and the old row is kept only so the ID is never reused (§2).

Verified against `lib/` on 2026-08-26: S-009..S-022 all still exist. S-007 and S-008 do not, in the
form these rows describe.

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

Detail: [`04-ui-patterns.md`](research/reference-app/04-ui-patterns.md). "Candidate" = identified,
not yet built. **Built** = in `lib/`; a linked spec means it also has a written contract.

Four have specs — the ones used across more than one surface, or complex enough that a props/states
table earns its keep. The rest are built or identified but unspecced; see §6.

| ID | Title | Status |
|---|---|---|
| CMP-001 | Minimised-session bar ("WIP" bar) | **Built** — [T-001](tickets/T-001-wip-bar.md) |
| CMP-002 | Live session stats strip (duration · volume · sets) | **Built** — `session_progress_header.dart` |
| CMP-003 | Set-completion-triggered rest timer | **Built** — `rest_bar.dart`, `rest_timer.dart` |
| CMP-004 | Add-exercise affordance inside a live session | **Built** — [T-012](tickets/T-012-adhoc-sessions.md) |
| CMP-005 | Week strip / date header | **Built** — satisfied by CMP-020 + S-003's date bar (T-013) |
| CMP-006 | Suggested-routine card | **Built** — [T-013](tickets/T-013-workout-tab.md) |
| CMP-007 | Insights block | Candidate |
| CMP-008 | Weekly summary header | **Built** — [T-015](tickets/T-015-home-tab.md) |
| CMP-009 | Sub-tab bar within a primary tab | Candidate |
| CMP-010 | Utility buttons in the top bar | Candidate |
| CMP-011 | Initials tile (routine thumbnail) | **Built — [spec](specs/components/CMP-011-initials-tile.md)** |
| CMP-012 | Workout summary card | **Built** — three variants (Home, Workout tab, History); not yet one component |
| CMP-013 | Delta chip | **Built** — [T-015](tickets/T-015-home-tab.md) |
| CMP-014 | First-run onboarding card | **Built** — [T-015](tickets/T-015-home-tab.md) |
| CMP-015 | **Set table row** ([spec](specs/components/CMP-015-set-table-row.md)) | **Built** — [T-008](tickets/T-008-plan-prefill.md) plan pre-fill, [T-009](tickets/T-009-previous-best.md) `Previous`, [T-010](tickets/T-010-completed-row-wash.md) completed-row wash (chalk, not green) |
| CMP-016 | Top-bar rest slot | Candidate |
| CMP-017 | **Per-exercise prescription editor** (sets · reps/range · RIR · weight) | Candidate |
| CMP-018 | **In-session numeric keypad** ([spec](specs/components/CMP-018-numeric-keypad.md)) | Candidate |
| CMP-019 | Stat chart card (metric · value · delta · range · line chart) | Candidate |
| CMP-020 | Week dot-strip (workout log) | **Built — [spec](specs/components/CMP-020-week-dot-strip.md)** |
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
| [T-017](tickets/T-017-restore-routine-delete.md) | Restore routine Delete and Duplicate | **Done** | S | S-030 |
| [T-018](tickets/T-018-exercise-detail.md) | Exercise detail screen (About · History · Records) | **Done** | M | S-025, ADR-004 |
| [T-019](tickets/T-019-in-session-info.md) | In-session ℹ opens the exercise detail | **Done** | S | S-025, S-013 |
| [T-020](tickets/T-020-finish-form.md) | Editable finish form: name + duration | **Done** | S | S-023, FL-003 |
| [T-021](tickets/T-021-body-part-filter.md) | Filter the exercise library by body part | **Done** | S | S-026, ADR-006 |
| [T-022](tickets/T-022-replace-exercise.md) | Replace an exercise in a routine | **Done** | S | S-029, S-028 |
| [T-023](tickets/T-023-recent-performed-picker.md) | `Recent Performed` leads the mid-session picker | **Done** | S | S-026, S-014 |
| [T-024](tickets/T-024-soft-delete-and-records-badge.md) | Soft-delete routines + `Records 🏅 N` badge | **Done** | M | S-001, ADR-004 |
| [T-025](tickets/T-025-routine-stats.md) | Routine detail stats: duration + body parts — closes S-030 | **Done** | M | S-030, ADR-006 |
| [T-026](tickets/T-026-weight-unit-normalisation.md) | Normalise weights to the display unit before comparing | **Done** | M | ADR-003, ADR-004 |

Next free T-ID: **T-027**.

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

Read from `pubspec.yaml` and `lib/` on 2026-08-23; **re-verified against the code 2026-08-26**, which
corrected the branch count (4 → 5) and the schema version (2 → 6). This section is the check against
project facts drifting from the repo — and it had drifted, so re-read it from `lib/` rather than
trusting it.

| Layer | Actual |
|---|---|
| SDK | Dart `^3.11.5`, Flutter |
| State | `flutter_riverpod ^2.6.1` — **v2, hand-written providers, no codegen** (`riverpod_annotation`/`riverpod_generator` are not dependencies) |
| Routing | `go_router ^17.5.0` — `StatefulShellRoute.indexedStack`, **5 branches** (ADR-005) |
| Persistence | `drift ^2.34.3` + `drift_dev`, `NativeDatabase.createInBackground`, **`schemaVersion: 6`** (T-002) |
| Design | Material 3 (`useMaterial3: true`), **dark only** — see [ADR-002](decisions/ADR-002-dark-only-theme.md) |
| Type | **Barlow** + **Barlow Condensed** bundled as app fonts (400/500/600, Condensed also 700) |
| Platforms | `android/`, `ios/`, `macos/` folders exist. **Android is the only shipping target**; macOS is the fast dev loop (`flutter run -d macos`) and is run regularly |
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

### `specs/components/` — partly closed (2026-08-26)

Four specs written: CMP-011, CMP-015, CMP-018, CMP-020 — chosen because they are used across more
than one surface, or dense enough that a props/states table earns its keep. Writing them was not
just recording:

- **The registry was wrong.** Ten components were marked "Candidate" while being built and shipped —
  CMP-001, CMP-002, CMP-003, CMP-005, CMP-006, CMP-011, CMP-012, CMP-020 among them. Corrected.
- **Two shared components lived in the wrong place.** `InitialsTile` sat inside `library_screen.dart`
  and was imported by S-030 *from another feature's screen file*; `WeekDotStrip` sat under
  `features/profile/` and was imported by the Workout tab. Both moved to `core/widgets/`. Writing
  "Our implementation: …" is what exposed it — the honest answer was embarrassing.

The remaining components are single-use or thin, and a spec for each would be ceremony. Worth writing
one the next time a component is picked up for a second surface — that is the moment the contract
matters.

### Neither blocks anything

Every implemented ticket references the surface spec and ADR it came from. These gaps affect how
easy the *next* piece of work is to pick up, not whether the current state is understood.

## 7. Current status (2026-08-28)

| Type | Count |
|---|---|
| S (surfaces) | 30 registered (14 reference · 16 ours) — **16 written specs**; S-007 and S-008 superseded |
| FL (flows) | **4 written** — the session lifecycle. Routine-building and programs still underived |
| CMP (components) | 27 registered — **14 built, 4 specced.** See §6 |
| F (features) | 0 |
| T (tickets) | 26 — **all done** |
| ADR (decisions) | 6 |

**Last updated:** **T-026 shipped — weight-unit normalisation.** While designing the progress chart
(T-027), it turned out there is **no weight-unit conversion anywhere in `lib/`**: sessions snapshot
their own `weightUnit`, Settings lets it change at any time, and three surfaces compared or summed
weights across sessions without reading that field — a 100 lb lift out-ranked a 60 kg one on every
personal record. T-026 was not on this section's list at all; it was uncovered as a live bug while
scoping T-027, not planned work, and is recorded plainly as such. Fixed read-time only (no migration,
no schema change): `computePersonalRecords`, `previousBestByExercise` and `weeklySummary` all take a
`displayUnit` and their providers watch the settings unit, so a unit switch restates all three with
no history edit; Home's volume delta stopped hardcoding `kg`. One deliberate behaviour change rode
along — `computePersonalRecords` used to skip only a `null` weight, so a logged `0` set a 0 kg
personal record; it now skips `weight <= 0`, since a zero-weight set is bodyweight work, not a lift.
441 tests before the branch, **454 tests pass now** (13 added), `flutter analyze` clean.

Before it: T-025 closed S-030's open questions with measured duration and a body-part line; T-024
made routine deletes soft and put Records on Home.

**Where the code is:** `main`, tracking `origin/main` at
`git@github.com:ishanshrestha14/jeem.git`. Schema **v6**. Local commits may be ahead of the remote. Five-tab shell
(Home · Explore · Workout · Library · You) live; Library and You rebuilt against S-004/S-005.

**Screenshot workflow:** paste into any note under `docs/`; Obsidian writes the PNG to disk and I
rename it into `screenshots/` under its manifest name.

**Next step (a fresh session starts here): T-027, the progress chart** (no ticket file yet — next
free T-ID) — design doc at
[`docs/superpowers/specs/2026-08-27-progress-chart-design.md`](superpowers/specs/2026-08-27-progress-chart-design.md).
It was the reason T-026 got found in the first place (scoping the chart surfaced the missing
weight-unit conversion, which had to ship first so the chart isn't built on top of a comparison bug),
and it is now unblocked.

**Every reference spec is now built or explicitly closed.** S-001..S-006, S-023, S-025, S-026,
S-029, S-030 built; S-027 and S-028 reviewed 2026-08-26 and found to have no gap worth building;
S-024 deliberately not adopted. §6's documentation gaps are closed on both halves (FL-001..FL-004,
four component specs).

So there is no drift left to fix, and **no decision is currently blocking work** — the ones that
were are answered and shipped in [T-024](tickets/T-024-soft-delete-and-records-badge.md) and
[T-026](tickets/T-026-weight-unit-normalisation.md).

What else remains, all un-blocked:

1. ~~**S-030's estimated duration and muscle summary**~~ — **done**, [T-025](tickets/T-025-routine-stats.md)
   (2026-08-27). Not the formula this line proposed: the duration is **measured** from the last three
   sessions of that routine wherever there are any, and the sets × rest formula is only the
   never-performed fallback. Its 45-second per-set work constant is the one invented number, and it
   disappears the first time you run the routine. The muscle summary is body parts as text, in enum
   order; the reference's anatomical figure is now a recorded decision not to build rather than an
   open question. **S-030 has no open questions left.**
2. **S-003's Insights row** — still out, because we have no recovery or streak model. A streak *is*
   computable offline; recovery is not, and should not be invented.
3. **The remaining flows** — build/edit a routine, exercise info, programs. FL-001..FL-004 cover the
   session lifecycle only.
4. **A progress chart** — designed, not yet ticketed as **T-027**. S-025's fourth pane, CMP-019.
   Charting is entirely new to this codebase, which is why T-018 stopped at three panes; scoping it
   is what uncovered T-026.

**Working notes for a fresh session** — two traps this codebase sets, both of which have cost real
time and are written up in [T-013](tickets/T-013-workout-tab.md) and
[T-016](tickets/T-016-missing-routine.md):

- **Never `await` a Drift stream's `.first` inside a `testWidgets` body.** It needs real async turns
  the fake clock does not provide, and the run *wedges* rather than failing. Have the fixture return
  the ids it created.
- **Every widget test that pumps a Drift-backed provider must end with `disposeAndDrainTimers`**,
  or drift's cleanup timer is left pending and the whole file wedges. A red run therefore looks like
  a hang — read the head of the log, not the tail.

**Build/run:** see [`BUILD_ENVIRONMENT.md`](BUILD_ENVIRONMENT.md). `flutter run -d macos` is the
fast loop; `flutter build apk --release` for the phone.
