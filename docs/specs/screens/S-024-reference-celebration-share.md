# S-024 — Post-save celebration / share card (reference app)

- **Type:** screen (full-screen modal, post-save)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** none (gap — and mostly out of scope)
- **Screenshots:** `ref-S024-celebration-share.png`
- **Last updated:** 2026-08-23

## Purpose

Rewards the save and produces a **shareable image**. Appears immediately after S-023 → `Save`.

> **Largely out of scope.** It exists to drive social sharing, which this app has no use for. The
> screenshot is retained for the *pattern* — a swipeable set of achievement cards — not the feature.
> The reference app's branding appears in the captured card and is **never** to be reproduced.

## Layout & sections

1. **`✕`** (top left, circular) · **`+`** (top right, circular — UNVERIFIED, likely add-to-story)
2. Accent heading **`Nice work!`** + subline `That's your workout number 1`
3. **Card carousel** — a large bordered card with a flame graphic, `1 week streak!`, encouraging
   copy, and a branding wordmark at the bottom. The neighbouring card peeks in from the right edge
4. **Six page dots** — six achievement cards generated per save
5. **`Share`** — pinned filled button with a share icon

## Notable

- The card is deliberately **image-shaped** — bordered, square-ish, self-contained, wordmark at the
  bottom — because it is going to be exported as a picture. That's why the branding is baked in.
- Six cards from a single first workout suggests they are generated from whatever facts exist
  (streak, workout count, volume, records…), padded to a fixed set.
- Dismissal is `✕` only — no "done" or "continue" affordance.

## What we would take, if anything

Only the **timing**: a brief, dismissible acknowledgement after saving, rather than dumping the user
straight back to a list. A single non-blocking confirmation would achieve the same with none of the
social machinery. Candidate for `Later` on the roadmap.

## Open questions

- [ ] What are the other five cards?
- [ ] What does the top-right `+` do?

## Revision log
- 2026-08-23 — created from `ref-S024-celebration-share.png`; scoped out as social/sharing.
