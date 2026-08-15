import 'package:drift/drift.dart';

enum LoggingType { strengthWeightRepsRir, durationOnly }

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
  TextColumn get category => text().nullable()();
  TextColumn get loggingType => textEnum<LoggingType>()();
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

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
  IntColumn get targetSets => integer().withDefault(const Constant(3))();
  IntColumn get restSeconds => integer().withDefault(const Constant(90))();
  RealColumn get defaultRir => real().nullable()();
  IntColumn get defaultDurationSeconds => integer().nullable()();
  TextColumn get notes => text().nullable()();

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
  RealColumn get weight => real().nullable()();
  IntColumn get reps => integer().nullable()();
  RealColumn get rir => real().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
