# S-027 — "Create Exercise" form (reference app)

- **Type:** screen (pushed from the picker's `+`)
- **Status:** Draft
- **Source:** reference
- **Counterpart:** S-012 (ours, `exercise_editor_screen.dart`)
- **Screenshots:** `ref-S027-create-exercise-form.png`
- **Last updated:** 2026-08-23

## Purpose

Create a user-defined exercise without leaving the flow that needed it. Reached by the `+` in the
exercise picker (S-026), so a missing exercise never interrupts building a routine or a live session.

**This is the single most useful screenshot for our schema** — it is the reference app's own
declaration of what an exercise *is*.

## Layout

Top bar: back arrow · title `Create Exercise` · **`Save`** (dimmed until valid).

1. **Media drop zone** — dashed border, camera+ icon, `Add photo or video`. Portrait aspect, centred,
   not full-width. Same dashed-border-means-empty idiom as S-023
2. **`Give the exercise a name`** — text field, the **only required field**
3. **`Add instructions (optional)`** — multiline
4. **`Details`** — five rows, each a label on the left and its value right-aligned in accent text,
   tapping to open a picker:

| Row | Value shown | Notes |
|---|---|---|
| **Exercise Type** | `Weight & Reps` | The only row with a **default**. Our `LoggingType`. The naming implies siblings — duration, distance, reps-only |
| **Body Parts** | `Optional` | **Plural.** A *separate* axis from muscles — see below |
| **Equipment** | `Optional` | Single or multi is UNVERIFIED |
| **Primary muscles** | `Optional` | **Plural** — confirms S-025 |
| **Secondary Muscles** | `Optional` | **Plural** |

## The finding: body parts and muscles are different fields

The form carries **`Body Parts` *and* `Primary muscles` as separate rows**. They are not two names
for one idea:

- **Body part** is the coarse bucket — `Back`, `Biceps`, `Shoulders`, `Chest`. It is what the picker
  cards print as their subtitle (`ref-S026-add-exercises-mid-session.png`: *Barbell Deadlift → Back*,
  *Dumbbell Incline Curl → Biceps*), and what Explore's grid groups by.
- **Muscle** is the anatomical detail — `Latissimus dorsi`, `Middle trapezius` (S-025).

Our v3 schema has **one** `Muscle` enum doing both jobs, which is why it currently mixes
granularities: `chest` and `abs` are body parts, `deltsFront` and `hipFlexors` are muscles. That
conflation is the root cause of the awkwardness, not just the single-primary bug.

## Everything is optional except the name

Exactly the shape [ADR-006](../../decisions/ADR-006-exercise-library-phasing.md) assumes: an exercise
can be created with a name alone and enriched later. `Exercise Type` defaults rather than asking,
because it is the one field that changes how logging *works*.

## Components used

- CMP-027 — label/value detail row *(new)* — a settings-style row that opens a picker, which we do
  not currently have; our editor uses inline dropdowns and chips

## Open questions

- [ ] Is `Body Parts` multi-select in practice, or plural in name only?
- [ ] What are the other `Exercise Type` values?
- [ ] Is `Equipment` single or multi?
- [ ] Are body parts derived from the muscles chosen, or independently set?

## Revision log
- 2026-08-23 — created from `ref-S027-create-exercise-form.png`; raised the body-part-vs-muscle
  distinction that reshapes T-005.
