# CMP-011 — Initials tile

- **Status:** Draft
- **Used by:** S-004 (Library — programs, routines, exercises), S-030 (routine detail)
- **Our implementation:** `lib/core/widgets/initials_tile.dart`
- **Last updated:** 2026-08-26

## Purpose

A thumbnail for something that has no image: a flat generated colour with the item's initials. It
exists so lists never have to render an empty picture frame, and so no image pipeline is needed to
make a list look finished.

## Anatomy

A 64x64 rounded square (8px radius), a background colour derived from the name, and one or two
uppercase initials centred in it.

## Props / inputs

| Name | Type | Required | Notes |
|---|---|---|---|
| `name` | `String` | yes | Both the initials and the colour derive from it — nothing is stored |

## Variants

None. Callers that have a real image render that instead and fall back to this — see S-030's
exercise rows, where `Image.file`'s `errorBuilder` returns an `InitialsTile`.

## States

Stateless and non-interactive. Whatever wraps it owns the tap.

## Interaction & gestures

None of its own.

## Accessibility & touch targets

Decorative: it repeats the name shown beside it, so it needs no semantics of its own, and it is never
the only carrier of meaning. Not independently tappable, so the 48dp rule does not apply — its host
row supplies the target.

## Do / Don't

- **Do** treat it as the default, not a fallback. Most exercises have no image, and a column of tiles
  reads better than a ragged column of blanks (S-030).
- **Do** keep the colour derived from the name, so the same routine always looks the same without
  storing anything.
- **Don't** put it somewhere it must convey information the adjacent text does not.

## Why it lives in `core/widgets`

It was written inside `library_screen.dart`, and when S-030 needed it the routine detail screen
imported it *from another feature's screen file* (`show InitialsTile`). Moved to `core/widgets` while
writing this spec: a component used across features has no business living in one feature's screen.

## Revision log
- 2026-08-26 — written from the implementation; moved out of `library_screen.dart` at the same time.
