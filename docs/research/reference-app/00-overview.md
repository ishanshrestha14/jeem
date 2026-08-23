# Reference App — Overview

- **Status:** Draft — session + Workout + Home verified from screenshots; Explore/Library/You still UNVERIFIED
- **Last updated:** 2026-08-23

> Purpose: capture the reference app's **information architecture and UX patterns only**.
> No branding, copy, icons, images, or assets from it are reproduced anywhere in this repo.
> Everything in sections 1–5 is **UNVERIFIED** — it comes from the owner's description on
> 2026-08-23 and has not yet been checked against a screenshot. Section 6 is verified from `lib/`.

## 1. Mental model

**UNVERIFIED.** The app treats a *routine* (named, reusable, e.g. "Pull A") as the unit the user
commits to, and a *session* as one full-screen run of that routine. Everything outside the session
is either **preparation** (pick or build a routine), **reference** (look an exercise up), or
**reflection** (stats, history, photos, measurements).

The primary loop appears to be: *Workout tab → pick or resume a routine → full-screen session →
summary → stats accumulate in Home + Profile.*

Notable: the app carries a large amount of **social/marketplace surface** (community programs,
coaches) that we explicitly do **not** want. That content lives entirely inside Explore, which
makes Explore the tab we borrow least from.

## 2. Navigation model

**UNVERIFIED.**

- **Root navigation:** 5 bottom tabs — **Home · Explore · Workout · Library · You** (verified from screenshots; the Workout tab's icon is a `+` in a circle, framing training as a create action).
- **Secondary navigation:** two of the five tabs are themselves **tabbed screens** (Explore: 3 tabs;
  Profile: 4 tabs). Per [ADR-001](../../decisions/ADR-001-single-s-id-namespace.md), those panes are
  sections of one S spec, not separate S-IDs.
- **Session is a full-screen takeover**, not a mini-bar — see §4.
- **Top bars carry state and utilities**, not just titles: Workout shows the current date plus a week
  strip; Profile puts settings and calendar entry points in the top bar.
- **Start-workout is promoted twice** on the Workout tab: an inline "start new workout" entry *and* a
  FAB. The **FAB starts an empty, ad-hoc session** (no exercises, add-as-you-go) — see §4.3.
- **A session survives leaving its surface**: minimising leaves a persistent "WIP" bar above the
  bottom nav, so session state is global chrome, not owned by one route — see §4.2.

## 3. Tab-by-tab IA

**UNVERIFIED.**

| # | Tab | Purpose | Contents (as described) | S-ID | Our equivalent |
|---|---|---|---|---|---|
| 1 | **Home** | At-a-glance recap | Weekly summary at top; past sessions listed in sequence below | S-001 | S-007 (Home) |
| 2 | **Explore** | Discovery / content repo | 3 tabs: **Exercises** (big repo, grouped by muscle group), **Programs** (community — *not wanted*), **Coaches** (*not wanted*) | S-002 | partial — S-011 exercise list, no discovery layer |
| 3 | **Workout** | Launchpad for training | Date in top bar; week strip below it; "start new workout"; suggested routines derived from previously-done routines; insights at the bottom; floating start-workout button | S-003 | S-008 (Workout / templates) |
| 4 | **Library** | The user's own content | Create new program; routines; custom exercises; favourite exercises | S-004 | split across S-008 + S-011 |
| 5 | **You** (owner called it Profile) | Stats and account | 4 tabs: **Overview**, **Exercises**, **Measures**, **Photos** — mostly statistics; settings + calendar buttons in the top bar | S-005 | S-020 (Settings only — large gap) |

**Structural observation worth carrying over:** the reference app separates *"someone else's content"*
(Explore) from *"my content"* (Library) from *"what I do next"* (Workout). Our MVP collapses all three
into one Workout tab plus a pushed Exercises screen. Since we're dropping the community half of
Explore, the useful version of this split for us is likely **two** buckets, not three.

## 4. Session mode

**UNVERIFIED** (owner-described 2026-08-23; screenshots pending).

Starting a routine (e.g. "Pull A") **takes over the full screen**.

### 4.1 Session chrome

| Position | Element | Behaviour |
|---|---|---|
| Top left | Chevron | **Minimises** the session (see §4.2) — does not end it |
| Below the chevron | **Stats box** — duration · volume · sets | Small boxed strip, live-updating, for the current session only. **Volume = total weight moved** ([ADR-003](../../decisions/ADR-003-volume-as-total-weight.md)) |
| Top right | **Finish** | Ends the session (UNVERIFIED: straight to summary, or confirm first) |
| Body | Exercises in sequence | — |
| After a set is marked | **Rest timer** appears | Rest is *reactive to set completion*, not manually started |

Note: the stats strip is **not** a top-centre timer as first assumed. Duration is one of three
peer stats, not the surface's headline element.

### 4.2 Minimise / resume — the "WIP bar"

The chevron collapses the session to a **persistent bar sitting directly above the bottom nav**:

- Titled **`Workout in Progress`** (the owner's "WIP" was shorthand — verified from screenshot)
- Two buttons: **Resume** and **Discard**
- **Resume** re-opens the full-screen session
- **Discard** opens a confirmation modal with two buttons: *Discard workout* / *Keep working out* —
  the destructive option is never one tap away
- **Shows no elapsed time** — verified from `ref-S006-session-minimised-wip-bar.png`: the strip is
  title + two actions only. (Corrects the earlier note taken from description.)
- Visible across tabs, so the user can browse the app mid-workout without losing the session
- **It displaces layout rather than overlapping it**: the FAB is pushed up to sit above the bar.
  Confirmed by the owner. So the bar occupies real layout space in the shell — it is not a floating
  overlay, and anything bottom-anchored must reflow around it

This is the key pattern our MVP lacks. Ours has a *Resume card on Home only*
(`home_screen.dart` → `_ResumeCard`), so leaving the session and navigating to any other tab hides
every trace of it. → **CMP-001**.

### 4.3 Empty / ad-hoc sessions

The Workout tab's FAB **starts a session with no exercises**. That session:

- Shows the same three stats (duration · volume · sets)
- Offers an **Add exercise** button — the same one present in every active session

So "start from a routine" and "start from nothing" converge on **one** session surface; the routine
merely pre-seeds it. Our MVP has no ad-hoc path at all — every session originates from a template
(`start_workout_action.dart`). → gap.

### 4.4 Why this matters for us

The session surface itself is our **smallest gap** (we already have full-screen `/session`, rest
timer, reorder, summary). The gaps are around its edges: **minimise/resume across tabs**, **ad-hoc
start**, and the **live stats strip**.

## 5. Explicitly out of scope

Not to be built, regardless of how they look in the reference app:

- Community programs (Explore tab 2)
- Coaches / marketplace (Explore tab 3)
- Anything requiring an account, network, or other users

## 6. Our current MVP IA (verified from `lib/`, 2026-08-23)

Shell: `StatefulShellRoute.indexedStack` in `lib/app/router.dart`, chrome in `lib/app/app_shell.dart`.

**4 bottom tabs:** Home · Workout · History · Profile.

| Route | Screen | S-ID |
|---|---|---|
| `/home` | `HomeScreen` | S-007 |
| `/workout` | `WorkoutScreen` | S-008 |
| `/history` | `HistoryScreen` | S-019 |
| `/profile` | **`SettingsScreen`** | S-020 |
| `/exercises` | `ExerciseListScreen` (pushed, not a tab) | S-011 |
| `/exercises/new`, `/exercises/:id` | `ExerciseEditorScreen` | S-012 |
| `/templates/new`, `/templates/:id` | `TemplateEditorScreen` | S-009 |
| `/session` | `ActiveSessionScreen` | S-015 |
| `/session/reorder` | `SessionReorderScreen` | S-016 |
| `/session/summary/:id` | `SessionSummaryScreen` (`readOnly` query param) | S-018 |

Sheets/overlays (no route): template exercise settings (S-010), exercise info (S-013), exercise
picker (S-014), session settings (S-017), rest sheet (S-021), notification permission prompt (S-022).

> **Superseded by [ADR-005](../../decisions/ADR-005-adopt-five-tab-navigation.md) (2026-08-23):**
> we will adopt the reference app's five tabs — `Home · Explore · Workout · Library · You` —
> sequenced as Phase 3 of the [roadmap](06-roadmap.md), once those tabs have contents.

**Two findings already visible from routing alone:**

1. **Our Profile tab is Settings.** `/profile` builds `SettingsScreen` directly. The reference app's
   Profile is a four-pane statistics hub with settings demoted to a top-bar button. This is the
   single largest IA gap.
2. **Exercises has no tab.** It is a pushed route, so the exercise library sits one level deeper than
   in the reference app, where it is a primary tab pane (Explore) *and* mirrored in Library.

## 7. Open questions

**Resolved 2026-08-23** (owner):
- [x] Chevron **minimises** to a persistent "WIP" bar above the bottom nav, with Resume + Discard.
- [x] Duration is not a top-centre timer — it is one of three stats (duration · volume · sets) in a
      small box below the chevron. Top right is **Finish**.
- [x] The FAB starts an **empty ad-hoc session** with an Add-exercise button.

**Resolved 2026-08-23 (second round):**
- [x] **Discard** confirms via a modal: *Discard workout* / *Keep working out*.
- [x] Volume is **total weight moved**; we show the stat on every session for chrome consistency —
      [ADR-003](../../decisions/ADR-003-volume-as-total-weight.md).
- [x] The WIP bar shows **elapsed time only**, plus the "WIP" label and two buttons, and **pushes the
      FAB up** (occupies layout, does not overlay).

**Open:**
- [x] Does **Finish** go straight to a summary, or confirm first when sets are incomplete?
- [x] Are Library's "routines" the same objects as Workout's "suggested routines", or a different list?
- [x] Does the WIP bar persist across an app **restart**, or only while the process lives?

## Revision log
- 2026-08-23 — created as stub during docs bootstrap; MVP IA section filled from `lib/`.
- 2026-08-23 — 9-screenshot batch: corrected the WIP bar (title `Workout in Progress`, no elapsed
  time), confirmed the 5th tab is labelled `You`, verified the accordion logging model and the
  3-step finish flow. Raised S-023, S-024 and CMP-011–CMP-016; wrote specs S-001, S-003, S-006.
- 2026-08-23 — second answer round: Discard confirms via modal; WIP bar shows elapsed only and
  pushes the FAB up (occupies layout); volume = total weight moved. Raised ADR-002 (dark-only) and
  ADR-003 (volume). Resolved 3 more open questions.
- 2026-08-23 — rewrote §4 from owner's answers: chevron minimises to a "WIP" bar (Resume/Discard)
  above the bottom nav; stats box (duration/volume/sets) sits below the chevron, Finish top right;
  FAB starts an empty ad-hoc session. Raised CMP-001. Resolved 3 open questions, opened 5.
- 2026-08-23 — filled §§1–5 from owner's verbal IA description (5 tabs, Explore/Profile sub-tabs,
  full-screen session, out-of-scope social features); assigned S-001–S-005 to reference tabs and
  S-006 to the session surface; added routing-derived findings to §6.
