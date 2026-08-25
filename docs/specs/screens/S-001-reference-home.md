# S-001 — Home tab (reference app)

- **Type:** screen (primary tab)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-007 (ours, `home_screen.dart`)
- **Screenshots:** `ref-S006-session-minimised-wip-bar.png` (empty + WIP bar), `ref-S001-home-populated.png`
- **Last updated:** 2026-08-23

## Purpose

Recap and **social feed**. The weekly summary is the useful half; below it, completed workouts render
as feed posts with avatar, likes, and comments.

> **Most of this surface is out of scope.** The reference Home is a social product. What we want is
> the **weekly summary header** and the **session list**; what we discard is the feed framing,
> likes/comments/share, friend invites, and challenges.

## Layout & sections

1. **Top bar** — `Home ⌄` (dropdown, UNVERIFIED what it switches) · streak flame · add-friend · bell
2. **`Your weekly summary`** + **`See more`** link
3. **Three stats** — `Workouts` · `Duration` · `Volume`, each with a **delta chip** below it
   (`▲ 1`, `▲ 720 kg`) coloured green when positive. Same three metrics as the session stats strip,
   aggregated to the week
4. **Feed** — one post per completed session
5. **Suggested Challenges** — out of scope
6. **FAB** `▶ Start new workout`
7. **WIP bar**, when a session is minimised (CMP-001)

## Feed post anatomy (`ref-S001-home-populated.png`)

Avatar · display name · activity icon + timestamp · 3-dot → then routine name as a heading (`pull B`)
→ **Duration / Volume** stat pair with **`Records 🏅 1`** right-aligned → an achievement banner
(*"Congrats on completing your first workout!"*) → exercise thumbnails with `2 x Barbell Deadlift…`
→ `Be the first to give a Like!` → like / comment / share icons.

**Worth keeping:** the *structure* — name, time, duration, volume, records, exercise thumbnails. It's
a good session-summary card even with the social layer stripped out.
**Worth dropping:** avatar/name (single-user app), like/comment/share, "Be the first to give a Like".

## The empty state (`ref-S006-session-minimised-wip-bar.png`)

Before any workout: all three summary stats read `0`, and a large **onboarding card** with an
illustration, *"Ready to start lifting, Ishan?"*, *"Complete your first workout to start seeing your
progress"*, and an outlined `START WORKOUT` button.

Contrast with S-006, which has no empty-state copy at all: **the app nags on Home and stays silent
during a session.** That's a deliberate split — motivational copy belongs where you're deciding,
never where you're working. Worth copying exactly.

## The WIP bar (CMP-001) — verified

Captured here on the Home tab, confirming it persists outside the Workout tab.

- Title **`Workout in Progress`**, centred — **not** the literal string "WIP"
- **`▶ Resume`** (accent) left · **`✕ Discard`** (red) right — colour alone separates them
- **No elapsed time is shown.** Correcting the earlier note: the bar is label + two actions only
- Sits directly above the bottom nav and **pushes the FAB up**, confirming it occupies layout
- Full-width, dark surface, visually a strip rather than a card

## Bottom navigation — verified

`Home` · `Explore` · `Workout` · `Library` · `You` — five tabs. Note the fifth is labelled **`You`**,
not "Profile", and `Workout` uses a **`+` in a circle**, styling the training tab as a create action.

## Components used

- CMP-001 — minimised-session bar
- CMP-008 — weekly summary header
- CMP-013 — delta chip
- CMP-012 — workout summary card
- CMP-014 — onboarding / first-run card

## Open questions

- [ ] What does the `Home ⌄` dropdown switch between?
- [ ] Does `See more` open a dedicated weekly-stats surface?
- [ ] What counts as a `Record`, and over what window?

## Revision log
- 2026-08-23 — created from `ref-S001-home-populated.png` + `ref-S006-session-minimised-wip-bar.png`;
  verified WIP bar wording/anatomy and the 5-tab bottom nav; scoped out the social layer.
- 2026-08-25 — built as [T-015](../../tickets/T-015-home-tab.md), replacing our Quick-start/Last-workout
  Home (S-007). **Deviations:** no FAB (the Workout tab is the launchpad and the first-run card
  carries the start button); sessions render as rows rather than feed posts, the post framing being
  the social layer this spec already scopes out; the summary shows no `See more`, having nowhere to
  go. Per-session `Records 🏅 N` deferred — it needs the third open question below answered first.
