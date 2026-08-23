# Screenshot Manifest

- **Last updated:** 2026-08-23

Drop reference-app screenshots in this folder using the exact filenames below. Specs reference
screenshots **by filename only** — no images, icons, or assets from the reference app are copied
into the app itself.

**Naming:** `ref-S0XX-<slug>.png` — the S-ID ties the shot to its spec.
Tick the box when the file lands. Extra unplanned shots are welcome: name them
`ref-S0XX-<slug>.png` too and I'll fold them in.

---

## Batch 1 — Session + Workout ✅ DONE (2026-08-23)

These map onto surfaces we already ship (S-015, S-008), so they convert straight into gap rows
and tickets.

| #   | Filename                                                                                                        | What to capture                                                                                                                           |
| --- | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | ✅ `ref-S006-session-active.png`                                                                                 | A started routine (e.g. Pull A), mid-workout. Must show the chevron, the duration/volume/sets box, Finish, and a few exercises with sets. |
| 2   | ⬜ `ref-S006-session-rest-timer.png` — *partly covered: the countdown pill is visible in the in-progress shot*   | Immediately after marking a set complete, with the rest timer visible.                                                                    |
| 3   | ✅ covered by `ref-S006-session-active-inprogress.png`                                                           | Close-up of one exercise's set rows — column headers, previous-performance hints, the complete-set control.                               |
| 4   | ✅ `ref-S006-session-minimised-wip-bar.png`                                                                      | Session minimised via the chevron — the WIP bar above the bottom nav, on **any tab other than Workout** so its persistence is visible.    |
| 5   | ✅ `ref-S006-session-empty-adhoc.png`                                                                            | Session started from the FAB with **no** exercises — the empty state plus the Add-exercise button.                                        |
| 6   | ⬜ `ref-S006-session-add-exercise.png` — still needed                                                            | The Add-exercise picker opened from inside a live session.                                                                                |
| 7   | ✅ `ref-S006-session-finish-confirm.png` + `ref-S023-finish-workout-form.png` + `ref-S024-celebration-share.png` | What Finish does — confirm dialog and/or the summary it lands on.                                                                         |
| 8   | ✅ `ref-S003-workout-tab-empty.png` + `ref-S003-workout-tab-logged.png`                                          | Workout tab, full scroll top: date top bar, week strip, start-new-workout, FAB.                                                           |
| 9   | ✅ covered by `ref-S003-workout-tab-empty.png`                                                                   | The suggested-routines section.                                                                                                           |
| 10  | ✅ covered by both Workout shots                                                                                 | The insights block at the bottom.                                                                                                         |

## Batch 2 — Home + Profile (largest IA gaps)

Our `/profile` is just Settings, and we have no body-stats surfaces at all.

| # | Filename | What to capture |
|---|---|---|
| 11 | ✅ `ref-S001-home-populated.png` + empty state in the WIP-bar shot | Home: weekly summary at top + the session list below it. |
| 12 | ✅ covered by `ref-S001-home-populated.png` | Close-up of one session row in that list — what's summarised per session. |
| 13 | `ref-S005-profile-overview.png` | Profile → Overview pane, including the top bar with settings + calendar buttons. |
| 14 | `ref-S005-profile-exercises.png` | Profile → Exercises pane (per-exercise stats/progress). |
| 15 | `ref-S005-profile-measures.png` | Profile → Measures pane. |
| 16 | `ref-S005-profile-photos.png` | Profile → Photos pane. |
| 17 | `ref-S005-profile-calendar.png` | The calendar view opened from the top bar. |

## Batch 3 — Library + Explore (content model)

**Now the highest priority alongside Batch 2** — `ref-S004-library-routine-edit.png` is the last
big unknown in the core loop (how routines/rep-ranges are defined feeds straight into CMP-015).

| # | Filename | What to capture |
|---|---|---|
| 18 | `ref-S004-library.png` | Library landing: create-new-program, routines, custom + favourite exercises. |
| 19 | `ref-S004-library-routine-edit.png` | Editing a routine — how exercises, sets, and rest are configured. |
| 20 | `ref-S002-explore-exercises.png` | Explore → Exercises pane: the muscle-group grouping. |
| 21 | `ref-S002-exercise-detail.png` | One exercise's detail page — this is our S-013 exercise-info sheet's counterpart. |

**Skip entirely:** Explore → Programs and Explore → Coaches. Out of scope; no shots needed.

## Newly needed (from the 2026-08-23 batch)

| Filename | What to capture | Why |
|---|---|---|
| `ref-S006-session-exercise-menu.png` | The per-exercise 3-dot menu, opened | Only remaining unknown on the session surface |
| `ref-S006-session-more.png` | What the **More** button opens | Likely their session-settings equivalent |
| `ref-S006-session-two-expanded.png` | Two exercises expanded at once, if possible | Determines single-open vs. multi-open accordion |
| `ref-S006-rest-editor.png` | Tapping `Rest Timer: 3min` | How per-exercise rest is edited inline |

## Optional extras (only if easy)

| Filename | What to capture |
|---|---|
| `ref-S006-session-reorder.png` | Reordering exercises mid-session (our S-016's counterpart). |
| `ref-S006-session-discard.png` | What Discard on the WIP bar does — confirm, or immediate. |
| `ref-S001-home-empty.png` | Any empty state you can reach — empty states are the thing screenshots capture worst. |

## Revision log
- 2026-08-23 — created; 21 planned shots in 3 batches + 3 optional.
- 2026-08-23 — Batch 1 filed (10 images). 8 of 10 rows satisfied; 2 still open. Added 4 new rows raised by what the batch revealed.
