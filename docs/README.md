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
| S-001 | reference | Home | screen | **Draft — [spec](specs/screens/S-001-reference-home.md)** |
| S-002 | reference | Explore | screen, tabbed | **Draft — [spec](specs/screens/S-002-reference-explore.md)** |
| S-003 | reference | Workout | screen | **Draft — [spec](specs/screens/S-003-reference-workout-tab.md)** |
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

Next free S-ID: **S-028**.

`Status: Implemented` on our rows means the surface exists in `lib/`; it does **not** mean a written
spec exists. No `specs/screens/` files have been authored yet.

### Flows (FL)
| ID | Title | Status | Spec |
|---|---|---|---|
| _none yet_ | | | |

### Components (CMP)

Detail: [`04-ui-patterns.md`](research/reference-app/04-ui-patterns.md). "Candidate" = identified, not yet specced.

| ID | Title | Status |
|---|---|---|
| CMP-001 | Minimised-session bar ("WIP" bar) | Candidate |
| CMP-002 | Live session stats strip (duration · volume · sets) | Candidate |
| CMP-003 | Set-completion-triggered rest timer | Candidate |
| CMP-004 | Add-exercise affordance inside a live session | Candidate |
| CMP-005 | Week strip / date header | Candidate |
| CMP-006 | Suggested-routine card | Candidate |
| CMP-007 | Insights block | Candidate |
| CMP-008 | Weekly summary header | Candidate |
| CMP-009 | Sub-tab bar within a primary tab | Candidate |
| CMP-010 | Utility buttons in the top bar | Candidate |
| CMP-011 | Initials tile (routine thumbnail) | Candidate |
| CMP-012 | Workout summary card | Candidate |
| CMP-013 | Delta chip | Candidate |
| CMP-014 | First-run onboarding card | Candidate |
| CMP-015 | **Set table row** (Previous · pre-filled · green complete) | Candidate |
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
| [T-006](tickets/T-006-programs.md) | Programs: a container above routines (schema v5) | Mini-plan — awaiting go | L | S-004 |

Next free T-ID: **T-007**.

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

## 6. Current status (2026-08-23)

| Type | Count |
|---|---|
| S (surfaces) | 27 registered (11 reference · 16 ours) — **11 written specs** |
| FL (flows) | 0 |
| CMP (components) | 27 candidates — 0 written specs |
| F (features) | 0 |
| T (tickets) | 6 — 4 done, 1 blocked (T-002), 1 planned (T-006) |
| ADR (decisions) | 6 |

**Last updated:** **five-tab shell live** — `Home · Explore · Workout · Library · You` (ADR-005),
pulled forward from Phase 3 at the owner's request. 219 tests pass.

**Screenshot workflow:** paste into any note under `docs/`; Obsidian writes the PNG to disk and I
rename it into `screenshots/` under its manifest name.

**Next step:** two paths, either order:
1. `ref-S004-library-routine-edit.png` — unblocks **T-002** (the schema change). The last blocker.
2. Fill the new tabs: Library and You are deliberately thin. **T-002** (prescription schema) is the
   last Must, still waiting on `ref-S004-library-routine-edit.png`.
