import 'package:drift/drift.dart';

enum LoggingType { strengthWeightRepsRir, durationOnly }

/// Muscles an exercise can target. Fine-grained on purpose: coarse buckets
/// ("Arms", "Legs") cannot be split later without a second migration, whereas
/// several fine values can always be shown under one heading.
///
/// `adductors`, `neck` and `cardio` are unused by the seed library but are
/// declared now so a user-created exercise never needs a schema change
/// (docs/tickets/T-004-appendix-seed-tags.md).
enum Muscle {
  chest,
  lats,
  upperBack,
  lowerBack,
  deltsFront,
  deltsSide,
  deltsRear,
  biceps,
  triceps,
  forearms,
  abs,
  obliques,
  quadriceps,
  hamstrings,
  glutes,
  hipFlexors,
  adductors,
  calves,
  neck,
  cardio,
}

/// Coarse browse axis, kept deliberately small (~10 buckets). This is what
/// picker cards print as a subtitle and what the exercise grid groups by —
/// a *separate* field from [Muscle], mirroring the reference app's
/// "Body Parts" and "Primary muscles" being distinct (S-027).
enum BodyPart {
  chest,
  back,
  shoulders,
  arms,
  core,
  legs,
  glutes,
  calves,
  neck,
  cardio,
}

/// Which role a muscle plays in an exercise. Both roles are many-valued: an
/// exercise can have several primaries (S-025 shows two).
enum MuscleRole { primary, secondary }

/// Single-valued for now (T-004). An exercise needing two (cable + bench)
/// records the second in its notes; multi-value is a later migration if that
/// proves painful.
enum Equipment { barbell, dumbbell, cable, machine, bodyweight, band, other }

enum SessionStatus { active, paused, completed, cancelled }

enum RestTimerStatus { idle, running, paused, finished }

mixin SyncColumns on Table {
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
}

class Exercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  // Muscles and body parts live in their own tables (both are many-valued);
  // "untagged" — no rows at all — is the normal state while the library is
  // built from user-created exercises (ADR-006).
  TextColumn get equipment => textEnum<Equipment>().nullable()();
  BoolColumn get isFavourite => boolean().withDefault(const Constant(false))();
  TextColumn get loggingType => textEnum<LoggingType>()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Muscles worked by an exercise, with the role each plays. One relation
/// rather than a column plus a table: primary is many-valued too, and the
/// composite key makes "a muscle cannot be both primary and secondary" a
/// database invariant rather than an editor convention.
class ExerciseMuscles extends Table {
  TextColumn get exerciseId =>
      text().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get muscle => textEnum<Muscle>()();
  TextColumn get role => textEnum<MuscleRole>()();

  @override
  Set<Column> get primaryKey => {exerciseId, muscle};
}

/// Coarse grouping, set independently of [ExerciseMuscles] — the reference
/// app's create form exposes both (S-027), so a user can tag "Back" without
/// naming a muscle. Seeded rows derive theirs from their primaries.
class ExerciseBodyParts extends Table {
  TextColumn get exerciseId =>
      text().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get bodyPart => textEnum<BodyPart>()();

  @override
  Set<Column> get primaryKey => {exerciseId, bodyPart};
}

/// The coarse bucket a muscle belongs to. Used to derive body parts for
/// seeded exercises and during the v4 migration, so the two axes start
/// consistent without 55 hand-written lists.
BodyPart bodyPartForMuscle(Muscle m) => switch (m) {
      Muscle.chest => BodyPart.chest,
      Muscle.lats || Muscle.upperBack || Muscle.lowerBack => BodyPart.back,
      Muscle.deltsFront ||
      Muscle.deltsSide ||
      Muscle.deltsRear =>
        BodyPart.shoulders,
      Muscle.biceps || Muscle.triceps || Muscle.forearms => BodyPart.arms,
      Muscle.abs || Muscle.obliques => BodyPart.core,
      Muscle.quadriceps ||
      Muscle.hamstrings ||
      Muscle.hipFlexors ||
      Muscle.adductors =>
        BodyPart.legs,
      Muscle.glutes => BodyPart.glutes,
      Muscle.calves => BodyPart.calves,
      Muscle.neck => BodyPart.neck,
      Muscle.cardio => BodyPart.cardio,
    };

class WorkoutTemplates extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  IntColumn get defaultRestSeconds => integer().withDefault(const Constant(90))();
  BoolColumn get autoFocusNextSet => boolean().withDefault(const Constant(true))();
  BoolColumn get autoFocusNextExercise =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class TemplateExercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(WorkoutTemplates, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().references(Exercises, #id)();
  IntColumn get sortOrder => integer()();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
  TextColumn get notes => text().nullable()();

  // `targetSets`, `defaultRir` and `defaultDurationSeconds` lived here until
  // schema v6. They said "every set of this exercise is prescribed the same",
  // which the routine editor disproves — a top set followed by back-offs is
  // 70kg x 8 then 60kg x 6 (S-028). Prescription moved to [TemplateSets], and
  // the set count is now simply how many rows are there.

  @override
  Set<Column> get primaryKey => {id};
}

/// One planned set. The prescription a routine carries — what the live session
/// pre-fills from (S-028, T-002).
///
/// A row per set rather than columns on the exercise, because sets of the same
/// exercise are routinely prescribed differently. Mirrors [SessionSets] one
/// level up, which is the same reason [TemplateExercises] mirrors
/// [SessionExercises].
class TemplateSets extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get templateExerciseId =>
      text().references(TemplateExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get setIndex => integer()();

  /// All nullable: a set can be planned as "just do it" before any numbers are
  /// decided, and bodyweight work never gets a weight at all.
  RealColumn get weight => real().nullable()();
  IntColumn get reps => integer().nullable()();

  /// Upper bound of a rep range. `null` means [reps] is an exact target — the
  /// reps-vs-range mode is *derived* from this rather than stored separately,
  /// so a mode flag can never disagree with the numbers it describes.
  IntColumn get repsMax => integer().nullable()();

  RealColumn get rir => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A named, ordered collection of routines — "create a program with your
/// routines" (S-004). Organisation only: no scheduling, no week/day
/// assignment. A program does not change how you train, only how the library
/// is arranged.
class WorkoutPrograms extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per membership, rather than a program column on the template, so a
/// routine can sit in several programs without being copied — the same reason
/// [TemplateExercises] exists.
///
/// Deliberately **no** unique constraint on (programId, templateId): an
/// A/B/A week is a real thing, so the same routine may appear twice in one
/// program and only [sortOrder] tells the two apart.
class ProgramRoutines extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get programId =>
      text().references(WorkoutPrograms, #id, onDelete: KeyAction.cascade)();
  TextColumn get templateId =>
      text().references(WorkoutTemplates, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class WorkoutSessions extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get templateId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get weightUnit => text().withDefault(const Constant('kg'))();
  TextColumn get status => textEnum<SessionStatus>()();
  BoolColumn get autoFocusNextSet => boolean().withDefault(const Constant(true))();
  BoolColumn get autoFocusNextExercise =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get pausedSeconds => integer().withDefault(const Constant(0))();
  // Wall-clock moment the session was paused, cleared back to null on
  // resume. `resumeSession` uses this (not `updatedAt`) to measure the
  // pause duration, since any unrelated write while paused (e.g. editing a
  // logged weight) restamps `updatedAt` and would otherwise shrink the
  // measured pause.
  DateTimeColumn get pausedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  // Rest-timer persistence. Anchored on restEndsAt so the countdown survives
  // process death (PRD §10.4, §18.3). restRemainingSeconds is authoritative
  // only while paused.
  TextColumn get restStatus =>
      textEnum<RestTimerStatus>().withDefault(const Constant('idle'))();
  DateTimeColumn get restEndsAt => dateTime().nullable()();
  IntColumn get restRemainingSeconds => integer().nullable()();
  IntColumn get restTotalSeconds => integer().nullable()();
  TextColumn get restAfterSetId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SessionExercises extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get exerciseId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get loggingType => textEnum<LoggingType>()();
  IntColumn get sortOrder => integer()();
  IntColumn get restSeconds => integer()();
  IntColumn get targetSets => integer()();
  TextColumn get sessionNotes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class SessionSets extends Table with SyncColumns {
  TextColumn get id => text()();
  TextColumn get sessionExerciseId =>
      text().references(SessionExercises, #id, onDelete: KeyAction.cascade)();
  IntColumn get setIndex => integer()();

  // What the routine asked for, snapshotted at session start. Kept strictly
  // apart from the logged columns below: overwriting the plan with what was
  // actually done would destroy the comparison the set row exists to show.
  RealColumn get plannedWeight => real().nullable()();
  IntColumn get plannedReps => integer().nullable()();
  IntColumn get plannedRepsMax => integer().nullable()();

  // What was actually done.
  RealColumn get weight => real().nullable()();
  IntColumn get reps => integer().nullable()();
  RealColumn get rir => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
