# S-023 — "Finish Workout" form (reference app)

- **Type:** screen (pushed, post-session)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-018 (ours, `session_summary_screen.dart`) — *partial*
- **Screenshots:** `ref-S023-finish-workout-form.png`
- **Last updated:** 2026-08-23

## Purpose

Sits between finishing and saving. The session is **not yet committed** — this is an editable record
of what just happened, not a read-only summary. That is the key difference from our S-018.

## Entry points

- S-006 → `Finish` (→ validation modal if fields are unfilled → here)

## Layout & sections

Top bar: back arrow + title **`Finish Workout`**. Then a single scrolling column of fields:

| Field | Control | Value seen | Our equivalent |
|---|---|---|---|
| Workout name | Text input, pre-filled from the routine | `pull B` | UNVERIFIED |
| Description | Multiline, placeholder *"How'd it go? Share more about your workout."* | empty | none |
| Media | **Dashed-border drop zone**, camera+ icon, `Add photos/videos` | empty | none |
| Date & time | Row with calendar icon + chevron | `Today at 01:27 AM` | none (implicit) |
| Duration | Row with clock icon + chevron | `0m` | none (implicit) |
| Activity type | Row with dumbbell icon + chevron | `Weight Training` | none |
| Difficulty | Row with gauge icon + chevron | placeholder `How hard was this workout?` | RIR is per-set for us, not per-session |

**`Save`** — a pinned, full-width, high-emphasis button in a bottom bar that floats above the scroll.

A white coach-mark tooltip (*"Here you can add a photo from your workout."*) points at the media
zone — first-run onboarding, not permanent chrome.

## Notable

- **Every derived value is editable.** Date, duration, and even the workout name can be corrected
  after the fact. Our session data is whatever the timer recorded.
- The dashed-border media drop zone is the only dashed element seen anywhere in the app — dashes are
  reserved for "empty, drop something here".
- `Duration 0m` — the field displays what was recorded without rounding up.
- Saving is a **deliberate, separate act**. There is no autosave here, unlike the session itself.

## States

- **Default:** pre-filled name, everything else empty
- **First run:** coach-mark tooltip visible
- **Saving / saved:** UNVERIFIED → leads to S-024
- **Back:** UNVERIFIED whether the session is kept, discarded, or returned to

## Open questions

- [ ] What does the back arrow do — discard, keep as live, or return to the session?
- [ ] Is `Save` ever disabled?
- [ ] Is difficulty a 1–10 scale, RPE, or named levels?

## Revision log
- 2026-08-23 — created from `ref-S023-finish-workout-form.png`.
