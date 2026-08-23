# T-004 Appendix — proposed tags for the 34 seed exercises

- **Status:** Applied 2026-08-23. Extended below with 21 exercises from the owner's real routine.
- **Last updated:** 2026-08-23

These are **my guesses from exercise names and descriptions**, not authoritative data. Review before
the migration is written. Anything you change here changes the migration, not the schema.

## Proposed vocabularies

**Muscle** (18): `chest` · `lats` · `upperBack` · `lowerBack` · `deltsFront` · `deltsSide` ·
`deltsRear` · `biceps` · `triceps` · `forearms` · `abs` · `obliques` · `quadriceps` · `hamstrings` ·
`glutes` · `hipFlexors` · `adductors` · `calves` (+ `neck`, `cardio` reserved for later)

**Equipment** (7): `barbell` · `dumbbell` · `cable` · `machine` · `bodyweight` · `band` · `other`

## The 34

| # | Exercise | Was | **Primary** | Secondaries | Equipment |
|---|---|---|---|---|---|
| 1 | Barbell Bench Press | Chest | `chest` | triceps, deltsFront | barbell |
| 2 | Incline Dumbbell Press | Chest | `chest` | deltsFront, triceps | dumbbell |
| 3 | Cable Fly | Chest | `chest` | deltsFront | cable |
| 4 | Overhead Press | Shoulders | `deltsFront` | triceps, upperBack | barbell |
| 5 | Lateral Raise | Shoulders | `deltsSide` | — | dumbbell |
| 6 | Rear Delt Fly | Shoulders | `deltsRear` | upperBack | dumbbell ⚠️ |
| 7 | Triceps Pushdown | Arms | `triceps` | — | cable |
| 8 | Overhead Triceps Extension | Arms | `triceps` | — | dumbbell ⚠️ |
| 9 | Lat Pulldown | Back | `lats` | biceps, upperBack | machine ⚠️ |
| 10 | Seated Cable Row | Back | `lats` | upperBack, biceps | cable |
| 11 | Barbell Row | Back | `lats` | upperBack, biceps, lowerBack | barbell |
| 12 | Pull-Up | Back | `lats` | biceps, upperBack | bodyweight |
| 13 | Face Pull | Back | **`deltsRear`** ⚠️ | upperBack | cable |
| 14 | Barbell Curl | Arms | `biceps` | forearms | barbell |
| 15 | Hammer Curl | Arms | `biceps` | forearms | dumbbell |
| 16 | Back Squat | Legs | `quadriceps` | glutes, hamstrings, lowerBack | barbell |
| 17 | Front Squat | Legs | `quadriceps` | glutes, upperBack, abs | barbell |
| 18 | Romanian Deadlift | Legs | `hamstrings` | glutes, lowerBack | barbell |
| 19 | Leg Press | Legs | `quadriceps` | glutes, hamstrings | machine |
| 20 | Leg Curl | Legs | `hamstrings` | calves | machine |
| 21 | Leg Extension | Legs | `quadriceps` | — | machine |
| 22 | Walking Lunge | Legs | `quadriceps` | glutes, hamstrings | bodyweight ⚠️ |
| 23 | Standing Calf Raise | Legs | `calves` | — | machine ⚠️ |
| 24 | Plank | Core | `abs` | obliques, glutes | bodyweight |
| 25 | Side Plank | Core | `obliques` | abs, glutes | bodyweight |
| 26 | Hanging Leg Raise | Core | `abs` | obliques, forearms | bodyweight |
| 27 | Cable Crunch | Core | `abs` | obliques | cable |
| 28 | Dead Bug | Core | `abs` | obliques | bodyweight |
| 29 | Hamstring Stretch | Stretching | `hamstrings` | — | bodyweight |
| 30 | Hip Flexor Stretch | Stretching | `hipFlexors` | quadriceps | bodyweight |
| 31 | Pigeon Stretch | Stretching | `glutes` | hipFlexors | bodyweight |
| 32 | Chest Doorway Stretch | Stretching | `chest` | deltsFront | bodyweight |
| 33 | Thoracic Extension | Stretching | `upperBack` | — | bodyweight |
| 34 | Couch Stretch | Stretching | `hipFlexors` | quadriceps | bodyweight |

## Added 2026-08-23 — the owner's routine (21)

Requested mid-implementation: movements actually trained but absent from the starter library.
`Pigeon Pose` was **not** added — it is the existing `Pigeon Stretch` under another name.

| Exercise | Primary | Secondaries | Equipment | Logging |
|---|---|---|---|---|
| Incline Barbell Press | chest | deltsFront, triceps | barbell | strength |
| Flat Dumbbell Bench Press | chest | triceps, deltsFront | dumbbell | strength |
| Cable Lateral Raise | deltsSide | — | cable | strength |
| Cable Fly Low to High | chest | deltsFront | cable | strength |
| Dips | chest | triceps, deltsFront | bodyweight | strength |
| Single Arm DB Row | lats | upperBack, biceps | dumbbell | strength |
| Chest Supported DB Row | lats | upperBack, biceps, deltsRear | dumbbell | strength |
| Deadlift | hamstrings | glutes, lowerBack, upperBack, forearms | barbell | strength |
| Incline DB Curl | biceps | forearms | dumbbell | strength |
| Single Arm Cable Curl | biceps | forearms | cable | strength |
| Bulgarian Split Squat | quadriceps | glutes, hamstrings | dumbbell | strength |
| Leg Raise | abs | hipFlexors, obliques | bodyweight | strength |
| Bicycle Crunch | abs | obliques | bodyweight | strength |
| Reverse Crunch | abs | obliques, hipFlexors | bodyweight | strength |
| Mountain Climbers | abs | obliques, hipFlexors | bodyweight | **duration** |
| Hollow Body Hold | abs | obliques, hipFlexors | bodyweight | **duration** |
| Chin Tucks | neck | — | bodyweight | **duration** |
| Wall Slides | upperBack | deltsRear, deltsFront | bodyweight | **duration** |
| Cat-Cow | upperBack | lowerBack, abs | bodyweight | **duration** |
| Deep Squat Hold | hipFlexors | glutes, adductors, quadriceps | bodyweight | **duration** |
| Hip 90/90 | glutes | hipFlexors, adductors | bodyweight | **duration** |

**Judgement calls to check:**
- **Logging type on the ab-circuit four.** Mountain Climbers and Hollow Body Hold are timed;
  Bicycle Crunch and Reverse Crunch are reps. Any of the four could reasonably be the other.
- **Bulgarian Split Squat → dumbbell**, assuming loaded rather than bodyweight.
- **Dips → bodyweight**, assuming unweighted.
- `neck` and `adductors` are now in use (Chin Tucks, Deep Squat Hold, Hip 90/90) — good thing they
  were kept in the enum.

## Three things to look at

### 1. Face Pull changes group (#13)
Currently `Back`; tagged `deltsRear`. That is what it trains, but it means Face Pull leaves the Back
bucket. If you think of it as back work, say so and it becomes `upperBack` primary with `deltsRear`
secondary.

### 2. Stretches are tagged, not left null — **this reverses what I proposed earlier**
I previously suggested leaving `Stretching` exercises with a null primary muscle. Reviewing the
actual six, tagging them is better: `LoggingType.durationOnly` already distinguishes a stretch from a
lift, so the muscle field is free to mean "which muscle this involves" — and a muscle filter that
returns *"Hamstring Stretch"* alongside *"Leg Curl"* is more useful than one that hides it. Nothing
is conflated, because logging type carries the modality. Say the word and they go back to null.

### 3. Six equipment guesses (⚠️) that depend on your gym
- **#6 Rear Delt Fly** — dumbbell or cable?
- **#8 Overhead Triceps Extension** — dumbbell, cable, or EZ bar?
- **#9 Lat Pulldown** — `machine` or `cable`? (Same rig, different mental model.)
- **#22 Walking Lunge** — bodyweight or dumbbell?
- **#23 Standing Calf Raise** — machine or bodyweight?

Also note **`adductors`, `neck` and `cardio` end up unused** by these 34. Keeping them in the enum
costs nothing and avoids a second migration when a custom exercise needs them.

## Revision log
- 2026-08-23 — created for owner review (option C).
