# ADR-006 — Custom exercises first, seeded library later

- **Status:** Accepted
- **Date:** 2026-08-23
- **Relates to:** T-004, S-002, S-025, S-026, S-012

## Context

The reference app's exercise library is its most asset-heavy feature: looping demonstration
animations, front/back anatomical figures with primary muscles in red and secondaries in blue,
equipment photography, and a large curated catalogue. All of it is **licensed artwork we will not
reproduce, trace, or approximate**.

We also have a real taxonomy gap: `Exercises` carries a single nullable `category` column, with no
muscle group, no equipment, and no favourite flag ([T-004](../tickets/T-004-exercise-taxonomy.md)).

The risk is obvious — treating "build the exercise library" as one job makes it enormous, blocks the
session work behind it, and ends with placeholder art nobody wants.

## Decision

**Split the library into two phases, and let the app be useful after phase one.**

### Phase A — custom exercises (now)

Routines are built from **user-created exercises carrying just a name and a description/notes**.
This is what our MVP already does, and it stays the supported path. Concretely:

- Exercise creation (`+`) is available **from inside the picker**, so a missing exercise never
  interrupts the flow of building a routine (pattern from S-026).
- Taxonomy fields land in the schema now (T-004) but are **nullable and optional** in the editor.
- Browse surfaces must handle **untagged** exercises as a first-class case, not an edge case.
- Cards and cells are **text + icon** — no illustrations (owner decision 2026-08-23).

### Phase B — seeded library (later)

Once properly licensed or commissioned resources exist, seed a catalogue with images, muscle tagging,
and equipment, and build routines from that library instead. Phase A data must survive this: seeding
**adds** exercises, it never rewrites or replaces user-created ones.

## Consequences

- **The visual gap is accepted, deliberately.** A text-and-icon exercise grid is much plainer than
  the reference app's. That is the correct trade against shipping unlicensed art or stalling on
  assets.
- **T-004 stays worth doing now.** The schema change is cheap while the dataset is small and
  user-created; retrofitting a taxonomy over a large seeded catalogue is not.
- **Untagged is the normal state in Phase A**, so `Explore`'s muscle grid may be nearly empty at
  first. The pinned **search** field carries browsing until tagging exists — which is why search sits
  at the top of S-002 rather than behind an icon.
- Phase B needs an **idempotent seeding strategy** (stable ids, no duplicate-on-reseed) and must not
  collide with `seed_exercises.dart`'s existing behaviour.
- Favourites (T-004) are useful immediately in Phase A — with no tagging, a favourites filter is the
  main way to shorten a long flat list.

## Related decisions folded in (owner, 2026-08-23)

- **`category` merges into `primaryMuscle`.** One field, one meaning; `category` is not kept
  alongside it.
- **Exercises carry primary *and* secondary muscles.** Confirmed visually by S-025's red/blue
  encoding. Primary is a single value; secondaries are a set — so this is a column **plus** a
  join table, not one column.

## MVP scope line (owner, 2026-08-23)

**In MVP:** session logging · rest timer · reordering · exercise CRUD with **favourites** and basic
muscle tagging (primary + secondaries).

**Later:** per-exercise progress charts · pre-built exercise catalogue · muscle-based filtering ·
multi-valued equipment.

Note the deliberate asymmetry: **tagging data lands in MVP, but browsing by tags does not.** That is
the right way round — the schema is cheap to change now and expensive later, while the browse UI is
worthless until enough exercises are tagged to browse. Favourites and search carry finding until then.

## Alternatives considered

- **Seed a catalogue immediately using free/scraped assets.** Rejected: licensing risk, and scraping
  the reference app is explicitly off-limits.
- **Ship no taxonomy until Phase B.** Rejected: the migration is cheapest now, and favourites plus
  search deliver value before any tagging exists.
