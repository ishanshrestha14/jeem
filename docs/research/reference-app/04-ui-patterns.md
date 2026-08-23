# UI Patterns -> Flutter Component Mapping

- **Status:** Draft — patterns from owner's description; all UNVERIFIED until screenshots land
- **Last updated:** 2026-08-23

CMP IDs are assigned on first sighting and are never reused, even if the pattern is later dropped.
A CMP with no file in `../../specs/components/` is a **candidate** — identified, not yet specced.

| CMP | Pattern | Where seen | Behaviour | Our Flutter mapping | Status |
|---|---|---|---|---|---|
| CMP-001 | **Minimised-session bar ("WIP" bar)** | S-006 → all tabs | Persistent strip directly above the bottom nav while a session is minimised. Centred title **`Workout in Progress`** (not the literal "WIP"), then **`▶ Resume`** (accent) and **`✕ Discard`** (red). **No elapsed time** — verified in `ref-S006-session-minimised-wip-bar.png`. Discard confirms via modal (*Discard workout* / *Keep working out*). **Occupies layout** — pushes the FAB up rather than overlaying it. | **New.** Must live in `lib/app/app_shell.dart` (above `bottomNavigationBar`), driven by `activeSessionProvider`. Because it occupies layout, any FAB in the tab below it must reflow. Today the equivalent is `_ResumeCard` inside `home_screen.dart` — Home-only, so the session vanishes from every other tab. | Candidate |
| CMP-002 | **Live session stats strip** | S-006 | Small boxed strip below the chevron showing **duration · volume · sets** for the current session, updating live. Present in routine-started *and* empty ad-hoc sessions. Volume = total weight moved, shown on every session type ([ADR-003](../../decisions/ADR-003-volume-as-total-weight.md)). | Partly exists as `session_progress_header.dart` (UNVERIFIED which metrics it shows). Likely extend rather than replace. | Candidate |
| CMP-003 | **Set-completion-triggered rest timer** | S-006 | Rest countdown appears *because* a set was marked complete — not user-started. | Exists: `rest_bar.dart` + `rest_sheet.dart` (S-021), `domain/rest_timer.dart`. Closest-matching pattern we already ship. | Candidate |
| CMP-004 | **Add-exercise affordance inside a live session** | S-006 | Present in every active session; the only content affordance in an empty ad-hoc session. | Exists as `exercise_picker_sheet.dart` (S-014). UNVERIFIED whether it is reachable from S-015 mid-session. | Candidate |
| CMP-005 | **Week strip / date header** | S-003 | Current date in the top bar, scrollable week of dates below it. | **New.** No calendar or week-strip widget in `lib/`. | Candidate |
| CMP-006 | **Suggested-routine card** | S-003 | Routine suggestions derived from previously-completed routines. | **New.** No suggestion logic exists; would read session history. | Candidate |
| CMP-007 | **Insights block** | S-003 | Summary/analytics block at the bottom of the Workout tab. | **New.** UNVERIFIED what it contains. | Candidate |
| CMP-008 | **Weekly summary header** | S-001 | Aggregate recap at the top of Home, above the session list. | **New.** UNVERIFIED whether `home_screen.dart` shows any aggregates. | Candidate |
| CMP-009 | **Sub-tab bar within a primary tab** | S-002 (3 panes), S-005 (4 panes) | A primary tab whose content is itself tabbed. Per [ADR-001](../../decisions/ADR-001-single-s-id-namespace.md) these panes are spec sections, not S-IDs. | **New.** No `TabBar` usage found in `lib/`; our tabs are `StatefulShellRoute` branches only. | Candidate |
| CMP-010 | **Utility buttons in the top bar** | S-005 | Settings + calendar demoted to top-bar icons rather than occupying nav space. | **New.** Ours puts Settings on a whole bottom-nav tab (`/profile` → `SettingsScreen`). | Candidate |
| CMP-011 | **Initials tile** | S-003 | Routine thumbnail = flat generated colour + 2-letter initials (`PU`), no image. | **New.** Cheap: no image pipeline, no empty-thumbnail state. Strong candidate for our template cards. | Candidate |
| CMP-012 | **Workout summary card** | S-001, S-003 | icon/thumb · name · timestamp · Duration + Volume stat pair · optional records count. | Partly exists in `history_screen.dart` (UNVERIFIED contents). | Candidate |
| CMP-013 | **Delta chip** | S-001 | Small pill under a stat: `▲ 720 kg`, green when positive — change vs. previous period. | **New.** | Candidate |
| CMP-014 | **First-run onboarding card** | S-001 | Illustration + question headline + one-line rationale + outlined CTA. Shown only until the first workout exists. | Partly: we have `core/widgets/empty_state.dart`. | Candidate |
| CMP-015 | **Set table row** | S-006 | `Set · Previous · Kg · Reps · ✓`. Completed row tinted green full-width; pending values **pre-filled muted from the routine's prescription**; `Previous` separately shows last session's actual; ✓ is a filled circle in both states. | Rework of `strength_set_row.dart` **plus a template data change** — see CMP-017. **The highest-detail pattern in the whole teardown.** | Candidate |
| CMP-018 | **In-session numeric keypad** | S-006 | App-built keypad replacing the system keyboard when editing a set value: digits + `⌫`, keyboard-switch, **`RIR`** key, **`Next`** to commit-and-advance (wraps into the next set's first field). Focused value is pre-selected so typing overwrites. **Key set varies by field** — `.` shown for Kg, withheld for Reps. | **New.** We have `core/widgets/numeric_field.dart` using the system keyboard. Self-contained widget, no data change. | Candidate |
| CMP-017 | **Per-exercise prescription editor** | S-004 (routine build) | When adding an exercise to a routine: sets · **reps *or* rep range** (small dropdown toggling the mode) · RIR · weight. Feeds the pre-filled values in CMP-015. | **New, and it's a model change**: our `template_exercise` has no prescribed weight/reps/range/RIR. Closest existing surface is `template_exercise_settings_sheet.dart` (S-010), which today only carries rest. | Candidate |
| CMP-016 | **Top-bar rest slot** | S-006 | A reserved slot beside the chevron: idle = outline stopwatch icon; resting = accent pill with countdown + thin progress bar across the content top. Slot is always present so the bar never reflows. | Rework of `rest_bar.dart`. | Candidate |

## Patterns worth stealing, ranked

0. **CMP-015 + CMP-017 (prescription → pre-filled set table)** — promoted to the top, and they are one job, not two. The reference app carries **two** distinct kinds of prior information into a set row, and the value comes from having both:
   - **The plan** — muted pre-filled Kg/Reps from the routine's prescription (CMP-017), so a set
     that goes to plan is one tap on the ✓ with no typing.
   - **The past** — the `Previous` column, last session's actual result for that set, the core
     progressive-overload affordance.

   We have neither. CMP-017 is a **template data-model change** (prescribed sets/reps/range/RIR/
   weight), which makes this the largest and highest-value item in the teardown.
1. **CMP-001 (WIP bar)** — the single highest-value pattern. It converts a session from *a route you are trapped in* into *global state you can step away from*. Small surface area, large UX change, and our `activeSessionProvider` already exposes what it needs.
2. **CMP-018 (in-session keypad)** — the best effort-to-payoff item on the board. A self-contained
   widget, no schema change, and it fixes the worst moment in our session UX: the system keyboard
   appearing mid-set, shifting the layout, with small keys and no domain actions. `Next` chaining
   weight → reps → next set removes most of the tapping from logging.
3. **Ad-hoc empty session** (not a component — a flow) — one entry point, no template required. Ours is template-only.
4. **CMP-002 (stats strip)** — cheap, and makes the session feel live.

## Patterns to skip

- Anything in Explore's Programs / Coaches panes (community, marketplace) — [out of scope](00-overview.md#5-explicitly-out-of-scope).

## Revision log
- 2026-08-23 — created as stub during docs bootstrap.
- 2026-08-23 — added CMP-018 (in-session numeric keypad) and ranked it #2 to steal.
- 2026-08-23 — added CMP-017 (per-exercise prescription editor) after owner clarified the pre-filled values come from the routine, not history; rewrote the top of the steal-list around plan-vs-past.
- 2026-08-23 — corrected CMP-001 from screenshot (title is `Workout in Progress`, no elapsed time); added CMP-011–CMP-016; promoted the set table to the top of the steal-list.
- 2026-08-23 — seeded CMP-001–CMP-010 from the owner's IA + session-mode answers; added ranking.
