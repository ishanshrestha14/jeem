# T-006 — Programs: a container above routines (schema v5)

- **Status:** Mini-plan submitted — awaiting go
- **Priority:** Should
- **Effort:** L
- **Specs:** S-004
- **Last updated:** 2026-08-23

## Goal

Give the library an object above the routine. The reference app's create sheet states it plainly:
*"Create a program with your routines"* — a program is a named, ordered collection of routines
(`Pull B — 1 routine`), and it is the **first and default chip** in Library.

We have no such object, which is why our Library currently shows two chips where the reference shows
three, and why the `+` sheet has an entry that only apologises.

## Scope (in)

**Schema v5** — two tables, mirroring how templates already hold exercises:

```
WorkoutPrograms(id, name, notes?, + SyncColumns)
ProgramRoutines(id, programId -> WorkoutPrograms cascade,
                templateId -> WorkoutTemplates, sortOrder)
```

`ProgramRoutines` is a row-per-membership rather than a column on the template, so a routine can sit
in more than one program (Pull B in both "Upper/Lower" and "Deload") without being duplicated —
the same reason `TemplateExercises` exists.

- Repository + providers: watch programs with a routine count; create, rename, delete; add, remove
  and reorder routines within a program.
- **Library**: a `Programs` chip, first and selected by default; program rows showing
  `n routines`; a `Create new program` row at the top of that list.
- **Program editor** (`/programs/new`, `/programs/:id`): name, notes, an ordered routine list with
  add/remove/reorder — the same shape as the template editor, which already does exactly this one
  level down.
- The `+` sheet's Program entry stops apologising and creates one.
- Backup export/import round-trips both tables.

## Scope (out)

- **Scheduling.** No week/day assignment, no "day 3 of 6", no calendar. The reference may well have
  it, but nothing seen so far shows it, and inventing a scheduling model is a much larger decision
  than adding a container. An ordered list of routines is the whole object for now.
- Program-level favourites, images, sharing, or duplication.
- Starting a session "from a program" — you still start a routine. What a program adds today is
  organisation, not a new way to train.

## Files to touch

- `lib/db/tables.dart`, `app_database.dart` (migration v4 -> v5)
- `lib/features/programs/` — new: `data/program_models.dart`, `data/program_repository.dart`,
  `providers/program_providers.dart`, `ui/program_editor_screen.dart`
- `lib/features/library/ui/library_screen.dart` — third chip, program rows, create row
- `lib/app/router.dart` — `/programs/new`, `/programs/:id`
- `lib/core/services/backup_service.dart`
- tests: migration, repository, library, program editor

## Edge cases

- **Deleting a routine that is in a program.** The membership row must go, the program must not.
  A cascade on `templateId` would do that; without one, the program lists a routine that no longer
  exists. Templates are soft-deleted (`deletedAt`), so the query has to exclude those too.
- **An empty program** is valid — you name it before you fill it. It needs an empty state, not a
  validation error.
- **The same routine added twice** to one program: allowed (an A/B/A week is a real thing), so no
  unique constraint on `(programId, templateId)` — only `sortOrder` distinguishes them.
- Reordering must persist immediately, like every other mutation in this app.
- Pre-v5 backups import with no programs, which is simply "none yet".

## Acceptance criteria

- [ ] Schema migrates 4 -> 5 with no data loss; a v2 install still reaches v5 in one open.
- [ ] A program can be created, renamed, filled with routines, reordered and deleted.
- [ ] Deleting a routine removes it from every program without deleting the program.
- [ ] Library shows Programs first and selected, with correct routine counts.
- [ ] The `+` sheet creates a program.
- [ ] Export -> wipe -> import round-trips programs and their routines, in order.
- [ ] Pre-v5 backups still import.
- [ ] `flutter analyze` clean; full suite passes.

## Open questions

- [ ] Does a program need **scheduling** (days/weeks), or is an ordered list enough for now?
- [ ] Should `Programs` be the default chip even while you have none — an empty first tab — or
      should Library open on `Routines` until a program exists?
- [ ] Should starting a workout from a program be a thing later, or do programs stay organisational?

## Revision log
- 2026-08-23 — created from `ref-S004-library.png` and the create sheet.
