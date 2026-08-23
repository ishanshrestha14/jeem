# Screen / Surface Inventory (S)

- **Status:** Draft — reference rows are UNVERIFIED (no screenshots yet); our rows are verified from `lib/`
- **Last updated:** 2026-08-23

ID namespace covers **both apps** — read the `Source` column. See
[ADR-001](../../decisions/ADR-001-single-s-id-namespace.md).
Tab panes are sections of their parent's spec, not separate S-IDs (same ADR).

`Spec` is empty until the surface has a file in `../../specs/screens/`.

## Reference app

| ID | Source | Title | Type | Screenshots | Status | Counterpart | Spec |
|---|---|---|---|---|---|---|---|
| S-001 | reference | Home (feed + weekly summary) | screen | `ref-S001-home-populated.png`, `ref-S006-session-minimised-wip-bar.png` | **Draft (spec)** | S-007 | [S-001](../../specs/screens/S-001-reference-home.md) |
| S-002 | reference | Explore (tabs: Exercises · Programs · Coaches) | screen, tabbed | `ref-S002-explore-exercises.png` | **Draft (spec)** | S-011 | [S-002](../../specs/screens/S-002-reference-explore.md) |
| S-003 | reference | Workout | screen | `ref-S003-workout-tab-empty.png`, `ref-S003-workout-tab-logged.png` | **Draft (spec)** | S-008 | [S-003](../../specs/screens/S-003-reference-workout-tab.md) |
| S-004 | reference | Library | screen | — | Draft (UNVERIFIED) | split → S-008 + S-011 | — |
| S-005 | reference | **You** (tabs: Overview · Exercises · Measures · Photos) | screen, tabbed | `ref-S005-you-overview-log-prs.png`, `ref-S005-you-overview-charts-recovery.png` | **Draft (spec)** | S-019 + S-020 | [S-005](../../specs/screens/S-005-reference-you-tab.md) |
| S-023 | reference | "Finish Workout" form | screen (pushed) | `ref-S023-finish-workout-form.png` | **Draft (spec)** | S-018 (partial) | [S-023](../../specs/screens/S-023-reference-finish-workout-form.md) |
| S-024 | reference | Post-save celebration / share card | full-screen modal | `ref-S024-celebration-share.png` | **Draft (spec)** | none | [S-024](../../specs/screens/S-024-reference-celebration-share.md) |
| S-025 | reference | Exercise detail (About · History · Progress) | screen, tabbed | `ref-S025-exercise-detail-about.png` | **Draft (spec)** | S-013 (sheet) | [S-025](../../specs/screens/S-025-reference-exercise-detail.md) |
| S-026 | reference | Exercise browser / picker | full-screen modal | `ref-S026-exercise-browser-picker.png` | **Draft (spec)** | S-011, S-014 | [S-026](../../specs/screens/S-026-reference-exercise-browser.md) |
| S-006 | reference | Active session (full-screen takeover) | screen | `ref-S006-session-active.png` +5 | **Draft (spec written)** | S-015 | [S-006](../../specs/screens/S-006-reference-active-session.md) |

Explore's **Programs** and **Coaches** panes are documented for completeness only — they are
[out of scope](00-overview.md#5-explicitly-out-of-scope).

## Our MVP (verified from `lib/`, 2026-08-23)

| ID | Source | Title | Type | File | Route | Counterpart | Spec |
|---|---|---|---|---|---|---|---|
| S-007 | ours | Home / dashboard | screen | `features/dashboard/ui/home_screen.dart` | `/home` | S-001 | — |
| S-008 | ours | Workout (templates) | screen | `features/templates/ui/workout_screen.dart` | `/workout` | S-003, S-004 | — |
| S-009 | ours | Template editor | screen | `features/templates/ui/template_editor_screen.dart` | `/templates/new`, `/templates/:id` | S-004 (create) | — |
| S-010 | ours | Template exercise settings | bottom sheet | `features/templates/ui/template_exercise_settings_sheet.dart` | — | UNVERIFIED | — |
| S-011 | ours | Exercise list | screen | `features/exercises/ui/exercise_list_screen.dart` | `/exercises` | S-002 (Exercises pane) | — |
| S-012 | ours | Exercise editor | screen | `features/exercises/ui/exercise_editor_screen.dart` | `/exercises/new`, `/exercises/:id` | S-004 (custom exercises) | — |
| S-013 | ours | Exercise info | bottom sheet | `features/exercises/ui/exercise_info_sheet.dart` | — | UNVERIFIED | — |
| S-014 | ours | Exercise picker | bottom sheet | `features/exercises/ui/exercise_picker_sheet.dart` | — | UNVERIFIED | — |
| S-015 | ours | Active session | screen | `features/sessions/ui/active_session_screen.dart` | `/session` | S-006 | — |
| S-016 | ours | Session reorder | screen | `features/sessions/ui/session_reorder_screen.dart` | `/session/reorder` | UNVERIFIED | — |
| S-017 | ours | Session settings | bottom sheet | `features/sessions/ui/session_settings_sheet.dart` | — | UNVERIFIED | — |
| S-018 | ours | Session summary | screen | `features/sessions/ui/session_summary_screen.dart` | `/session/summary/:id` | UNVERIFIED | — |
| S-019 | ours | History | screen | `features/history/ui/history_screen.dart` | `/history` | S-001 (session list) | — |
| S-020 | ours | Settings | screen | `features/settings/ui/settings_screen.dart` | `/profile` ⚠️ | S-005 (top-bar button only) | — |
| S-021 | ours | Rest sheet | bottom sheet | `features/sessions/ui/widgets/rest_sheet.dart` | — | S-006 (rest timer) | — |
| S-022 | ours | Notification permission prompt | overlay / prompt | `features/sessions/ui/notification_permission_prompt.dart` | — | none | — |

⚠️ **S-020 occupies the Profile tab.** `/profile` builds `SettingsScreen` directly
(`lib/app/router.dart`). The reference counterpart S-005 is a stats hub with settings demoted to a
top-bar button — the largest IA gap on the board.

## Gaps with no surface on our side

| Reference | What's missing here |
|---|---|
| **S-006 `Previous` column** | **No per-set history shown while logging** — the biggest functional gap found so far |
| **S-006 pre-filled pending sets** | Our set rows start empty; theirs pre-fill from the routine's prescription, so a to-plan set is one tap |
| **Routine prescription (model gap)** | Their routine stores per exercise: sets · reps **or** rep range (dropdown) · RIR · weight. Our `template_exercise` stores exercises + custom rest only — **no prescription at all**. This is a Drift schema change, not a UI change |
| **S-006 inline per-exercise notes + rest** | Ours are behind sheets (S-010/S-017), not inline in the expanded exercise |
| **S-023 editable post-session form** | Our S-018 is a read-only summary; theirs lets you edit name, date, duration, add media and a difficulty rating before saving |
| **S-006 custom numeric keypad** | We use the system keyboard (`numeric_field.dart`) — layout shift mid-set, small keys, no `RIR`/`Next` domain keys |
| **S-006 `Records` / PR tracking** | No personal-record concept anywhere in `lib/` |
| **S-002 muscle / equipment taxonomy** | `Exercises` has one nullable `category` — no muscle group, no equipment. Neither Explore browse axis is expressible ([T-004](../../tickets/T-004-exercise-taxonomy.md)) |
| **S-005 trend charts** | No charting anywhere in `lib/` |
| **S-005 Measures / Photos** | No body-measurement or progress-photo surfaces |
| **S-025 exercise History / Progress panes** | Our S-013 is a sheet with description/notes only — no per-exercise history, no per-exercise progress chart |
| **S-026 favourites** | No favourite flag on exercises ([T-004](../../tickets/T-004-exercise-taxonomy.md)) |
| **S-026 filter strip + filter-count badge** | No filtering by muscle group; no active-filter count |
| S-024 celebration | No post-save acknowledgement (mostly out of scope) |

| S-005 calendar button | No calendar view of training |
| S-003 suggested routines | No "based on what you did last" suggestion surface |
| S-003 insights | No insights block |
| S-002 grouped exercise repo | S-011 exists but UNVERIFIED whether it groups by muscle group |
| S-004 favourites | No favourite-exercise concept confirmed in `lib/` |

## Revision log
- 2026-08-23 — created as stub during docs bootstrap.
- 2026-08-23 — 9-screenshot batch filed; specs written for S-001, S-003, S-006; S-023 and S-024 registered as new surfaces; gap list extended with the set-table findings.
- 2026-08-23 — S-006 spec written from first screenshot.
- 2026-08-23 — seeded S-001–S-006 (reference, from owner's verbal IA) and S-007–S-022 (ours, from
  `lib/` + `router.dart`) per ADR-001; added counterpart mapping and no-counterpart gap list.
