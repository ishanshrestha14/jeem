Below is an implementation-ready PRD you can paste into Claude Code. I made it opinionated on purpose so coding can start quickly: Android-first Flutter app, offline-first local storage, optional Postgres sync later. UI/UX is treated as the top priority.

---

# PRD: Gym Session Timer / Workout Tracker

**Working name:** `GymFlow`  
**Version:** 0.1  
**Date:** 2026-08-15  
**Platform:** Android via Flutter APK sideloading  
**Primary user:** Single user doing gym, home stretching, ab circuits, etc.  
**Priority:** UI/UX, speed during workout, precise rest timing, offline reliability

---

## 1. Product Overview

GymFlow is a personal workout companion app for Android. The user creates multiple workout templates such as Push, Pull, Legs A/B, Ab Circuit, and Stretching. Each template contains a list of exercises. Each exercise can have its own rest time and number of sets.

When a workout session is started, the app creates a session copy of the template. During the session, the user can manually log each set with weight, reps, and RIR. If an exercise has 3 sets, the session UI shows 3 separate set rows. Each set row has its own values, including a dropdown for RIR.

The app focuses on fast workout execution:

- Start a workout quickly.
- See current exercise and sets clearly.
- Mark sets complete.
- Start precise rest timers automatically.
- Auto-advance to the next set or exercise based on user toggles.
- Reorder exercises mid-session if a machine is occupied.
- View exercise info through an info icon: description, notes, image.
- Finish and save the session.

The first release is local-only and works fully offline. A Postgres-based sync backend may be added later.

---

## 2. Main Goals

1. **Fast workout execution**
   - The user should be able to log a set in a few taps.
   - Rest timer should start automatically after completing a set.
   - The next set/exercise should be obvious.

2. **Precise rest management**
   - Each exercise can have custom rest time.
   - Rest timer should be accurate and visible.
   - User can skip, pause, add, or reduce rest time.

3. **Flexible session ordering**
   - If a machine is occupied, the user can reorder exercises for the current session only.
   - The template should not be changed unless explicitly saved later.

4. **Clear set-level logging**
   - If an exercise has 3 sets, show 3 rows.
   - Each row can have weight, reps, RIR, and completion state.
   - RIR should be selected through a dropdown.

5. **Exercise context**
   - Each exercise can have description, notes, and image.
   - Info is accessible from an `i` icon.

6. **Offline-first reliability**
   - The app must work without internet.
   - No account required for MVP.
   - Data should not be lost if the app is closed during a workout.

7. **Excellent UI/UX**
   - Large touch targets.
   - High contrast.
   - Dark theme by default.
   - One-handed usability.
   - Minimal typing.
   - Clear current set, rest state, and next action.

---

## 3. Non-Goals for MVP

These are not required for the first version:

- iOS app.
- Play Store release.
- Multi-user support.
- Social features.
- Exercise progression algorithms.
- Automatic weight recommendations.
- Wearable support.
- Supersets, circuits, or complex grouping.
- Cloud account sync in the first coding phase.
- Video playback.
- Analytics dashboards.

---

## 4. Target User

Single user who:

- Works out at a gym and at home.
- Does strength workouts, ab circuits, and stretching.
- Wants precise rest timing.
- Wants to manually enter weight, reps, and RIR.
- Needs to adapt exercise order mid-session due to equipment availability.
- Uses an Android phone and installs APK manually.

---

## 5. Core Product Loop

1. User creates a workout template.
2. User adds exercises to the template.
3. User configures sets and rest time per exercise.
4. User starts a session from a template.
5. User logs weight/reps/RIR for each set.
6. User completes a set.
7. Rest timer starts automatically.
8. After rest, app advances or prompts to advance to next set/exercise.
9. User can reorder upcoming exercises if needed.
10. User finishes workout and session is saved.

---

## 6. Core Concepts

### Exercise

An exercise is a reusable library item.

Examples:

- Bench Press
- Lat Pulldown
- Romanian Deadlift
- Plank
- Hamstring Stretch

An exercise can contain:

- Name
- Category
- Description
- Notes
- Image
- Logging type:
  - Strength: weight, reps, RIR
  - Duration: useful for stretching or timed exercises

### Workout Template

A workout template is an ordered list of exercises.

Examples:

- Push
- Pull
- Legs A
- Legs B
- Ab Circuit
- Stretch

A template contains:

- Workout name
- Optional notes
- Ordered exercises
- Per-exercise settings:
  - Number of sets
  - Rest seconds
  - Optional default RIR
  - Optional default duration for stretch/timed exercises

### Session

A session is a one-time execution of a workout template.

When a session starts:

- The template is copied into a session snapshot.
- The user can change order, rest time, and set values for that session only.
- The original template remains unchanged.

### Set Row

Each set is a separate row.

For strength exercises:

- Set number
- Weight input
- Reps input
- RIR dropdown
- Complete action

For stretch/duration exercises:

- Set number
- Duration input
- Complete action

---

## 7. MVP Feature Scope

### 7.1 Workout Templates

User can:

- Create workout template.
- Edit workout template.
- Delete workout template.
- Duplicate workout template.
- Add exercises to template.
- Remove exercises from template.
- Reorder exercises in template.
- Set number of sets per exercise.
- Set rest time per exercise.
- Optional: set default RIR per exercise.
- Optional: set default duration for stretch exercises.
- See exercise info from template editor.

### 7.2 Exercise Library

User can:

- Create exercise.
- Edit exercise.
- Archive/delete exercise.
- Add description.
- Add notes.
- Add image.
- Choose logging type:
  - Strength: weight/reps/RIR
  - Duration: time-based
- Search exercises.
- Select exercises while editing a workout template.

For MVP, deletion should be safe:

- Prefer archive/soft delete.
- Existing sessions should keep historical exercise data.
- Templates using archived exercises should show an archived warning.

### 7.3 Active Session

User can:

- Start session from template.
- See session progress.
- See elapsed time.
- See current exercise.
- See upcoming exercises.
- Expand/collapse exercises.
- Manually enter values per set.
- Complete/uncomplete sets.
- Add extra sets.
- Remove pending sets.
- Reorder upcoming exercises.
- Move current exercise later if machine is occupied.
- View exercise info.
- Adjust rest time during session.
- Pause session.
- Resume session.
- Finish session.
- Cancel/discard session.

### 7.4 Rest Timer

The app should:

- Automatically start rest after completing a set.
- Use per-exercise rest time.
- Show a large countdown.
- Show next set/exercise.
- Allow:
  - Pause
  - Resume
  - Skip
  - +15 seconds
  - -15 seconds
  - Cancel rest
- Notify user when rest is finished.
- Optionally auto-focus next set.
- Optionally auto-focus next exercise.
- Restore correctly if app is reopened.

### 7.5 Auto-Advance Options

Session should have toggles:

1. **Auto-focus next set after rest**
   - After rest ends, automatically scroll/highlight the next pending set.

2. **Auto-focus next exercise after rest**
   - After final set of an exercise and rest ends, automatically move to the next exercise.

These do not automatically mark the next set complete. They only move the UI focus to the next item.

If toggles are off:

- Show a clear “Rest complete” state.
- Show a button: “Go to next set” or “Go to next exercise”.

### 7.6 Exercise Info

Every exercise row/card should have an `i` icon.

Info sheet shows:

- Exercise name
- Image
- Description
- Notes
- Category/logging type
- Optional archived badge

### 7.7 Session Summary

After finishing a session:

- Show total duration.
- Show completed sets / planned sets.
- Show completed exercises.
- Show optional volume: sum of weight × reps for completed strength sets.
- Allow adding session notes.
- Save session.
- Discard option if user does not want to keep it.

### 7.8 History

Minimal history is required for MVP:

- List previous sessions.
- Show date, workout name, duration, completed sets.
- Open session in read-only mode.
- Optionally duplicate the template used.

### 7.9 Backup / Export

Because the MVP is offline:

- Export local data to JSON.
- Import JSON with confirmation.
- Import may replace all local data in MVP.

Future versions can sync through Postgres.

---

## 8. Detailed Functional Requirements

### FR-100: Workout Template Management

The app shall allow the user to create, edit, duplicate, and delete workout templates.

Template fields:

- `id`
- `name`
- `notes`
- `defaultRestSeconds`
- `autoFocusNextSet`
- `autoFocusNextExercise`
- `createdAt`
- `updatedAt`

Validation:

- Name is required.
- Name should be unique or visibly distinguishable.
- A template should have at least one exercise before starting a session.

---

### FR-101: Template Exercise Configuration

The app shall allow adding exercises to a template.

Per template exercise:

- Exercise reference
- Sort order
- Target sets
- Rest seconds
- Optional default RIR
- Optional default duration seconds
- Optional per-template notes

Default values:

- Target sets: 3
- Rest seconds: 90
- RIR: empty
- Duration: empty

Constraints:

- Target sets: 1 to 20
- Rest seconds: 0 to 3600

---

### FR-102: Exercise Library Management

The app shall allow creating and editing exercises.

Exercise fields:

- `id`
- `name`
- `category`
- `loggingType`
- `description`
- `notes`
- `imagePath`
- `isArchived`
- `createdAt`
- `updatedAt`

Logging types:

- `strengthWeightRepsRir`
- `durationOnly`

Categories can include:

- Chest
- Back
- Legs
- Shoulders
- Arms
- Core
- Stretching
- Cardio
- Other

For MVP, category is simple and optional.

---

### FR-103: Exercise Image

The app shall allow adding an image to an exercise.

Implementation rules:

- Use image picker.
- Copy selected image into app documents.
- Store local path in DB.
- Compress/downscale image to reasonable size, for example max width 1080px.
- Display image in exercise info sheet.
- If no image is available, show a placeholder icon.

---

### FR-104: Starting a Session

When the user starts a template:

The app shall create a session snapshot.

Session snapshot includes:

- Session ID
- Template ID reference, if any
- Workout name
- Weight unit snapshot, e.g. kg or lb
- Auto-focus settings
- Session status
- Start time
- Exercises copied from template:
  - Exercise ID
  - Exercise name snapshot
  - Description snapshot
  - Notes snapshot
  - Image path snapshot
  - Logging type snapshot
  - Sort order
  - Rest seconds
  - Target sets
- Sets generated from target sets:
  - Set index
  - Empty weight
  - Empty reps
  - Empty RIR or default RIR if provided
  - Empty duration or default duration if provided
  - Not completed

The template must not be modified by session changes.

---

### FR-105: Session Exercise Display

For each exercise in an active session:

If exercise has `n` target sets, display `n` set rows.

Example:

If an exercise has 3 sets, show 3 rows.

Each strength set row should contain:

- Set number
- Weight input
- Reps input
- RIR dropdown
- Complete button/checkbox

Each duration set row should contain:

- Set number
- Duration input
- Complete button/checkbox

The current set row should be visually highlighted.

---

### FR-106: Set Completion

The user can complete a set.

When a set is completed:

- Store completion timestamp.
- If rest time is greater than zero and there is a next set or exercise, start rest timer automatically.
- If rest time is zero, move focus to next pending set/exercise immediately.
- Haptic feedback should be triggered.
- A short undo option should be available.

The user can uncomplete a set.

Rules:

- If the uncompleted set was the latest completed set and rest is active, cancel or adjust the active rest.
- Older completed sets can be edited without affecting active rest.

---

### FR-107: Rest Timer Behavior

The app shall maintain one active rest timer at a time.

Rest timer state:

- Idle
- Running
- Paused
- Finished

Rest timer should be based on a target end timestamp, not only incremental ticks.

Example:

```text
restEndsAt = current time + restSeconds
```

This improves accuracy and allows restoration after app restart.

Rest timer UI should show:

- Countdown in `mm:ss`
- Progress ring or bar
- Next exercise/set
- Pause/resume
- Skip
- +15 seconds
- -15 seconds
- Cancel
- Undo latest set completion, if applicable

When rest ends:

- Play sound if enabled.
- Vibrate if enabled.
- Show notification if app is backgrounded.
- Auto-focus next set/exercise depending on settings.

---

### FR-108: Auto-Focus Next Set

If `autoFocusNextSet` is enabled:

When rest ends and the next target is another set in the same exercise:

- Scroll to next set.
- Highlight next set.
- Make it the current set.
- Do not auto-complete it.

If disabled:

- Show rest complete banner.
- Show button: “Next set”.

---

### FR-109: Auto-Focus Next Exercise

If `autoFocusNextExercise` is enabled:

When rest ends after the final set of an exercise and there is another exercise:

- Collapse or minimize completed exercise.
- Expand next exercise.
- Scroll to next exercise.
- Highlight first pending set of next exercise.

If disabled:

- Show rest complete banner.
- Show button: “Next exercise”.

---

### FR-110: Manual Focus

The user may manually tap a pending exercise or set to focus it.

Rules:

- Manual focus changes current UI target.
- Manual focus does not complete anything.
- If rest timer is active, manual focus does not cancel rest by default.
- If user completes a set while rest is active, cancel current rest and start new rest based on the newly completed set.

---

### FR-111: Session Reordering

The user can reorder exercises in an active session.

Rules:

- Reordering affects only the session.
- Reordering does not modify the template.
- Completed exercises are visually locked and should not be reordered in MVP.
- Pending/upcoming exercises can be reordered.
- Drag handle should be visible.
- The current exercise is determined by the first pending exercise in session order unless manually overridden.
- If reordering changes the first pending exercise, the current exercise updates accordingly.
- Active rest timer should not be canceled by reordering alone.

Additional quick action:

- “Do later” button on current exercise.
- Moves current exercise to the end of pending exercises.
- Useful when a machine is occupied.

---

### FR-112: Add and Remove Sets During Session

The user can:

- Add a new set to an exercise.
- Remove a pending set.

Rules:

- Completed sets cannot be removed without first uncompleting them.
- Removing a set should require confirmation or provide undo.
- Adding a set adds it after the last set by default.

---

### FR-113: Rest Time Editing During Session

The user can edit rest time during a session.

Rules:

- Rest time can be edited per exercise for the session.
- Editing rest time affects future rests for that exercise in that session.
- It does not modify the template.
- If rest is currently running, editing can either:
  - apply to current remaining rest if user chooses, or
  - apply to next rest.
- MVP recommendation: edit applies to current rest if rest is active, with a clear UI label.

Quick rest presets:

- 30s
- 60s
- 90s
- 120s
- 180s
- 240s

---

### FR-114: Exercise Info Sheet

Every exercise displayed in template editor, exercise library, or active session should have an info icon.

Tapping info icon opens a bottom sheet with:

- Name
- Image
- Description
- Notes
- Category
- Logging type
- Archived state if applicable

The info sheet should not require internet.

---

### FR-115: Session Pause and Resume

The user can pause the session.

When paused:

- Rest timer pauses.
- Elapsed workout timer may optionally pause.
- UI shows paused state.
- Resume restores remaining rest time.

MVP simplification:

- Store remaining rest seconds when paused.
- On resume, recalculate `restEndsAt`.

---

### FR-116: Session Finish

The user can finish session.

If all sets are completed:

- Show summary directly or ask for confirmation.

If some sets are incomplete:

- Warn user.
- Options:
  - Finish anyway
  - Continue workout
  - Discard session

Saved session should include:

- Workout name
- Start time
- End time
- Duration
- Completed sets
- Logged values
- Session notes
- Exercise order at finish time

---

### FR-117: Session History

The app shall store completed sessions.

History list item shows:

- Date
- Workout name
- Duration
- Completed sets / total sets
- Optional volume

History detail shows:

- Read-only session data.
- Exercise order.
- Set values.
- Completed state.
- Session notes.

---

### FR-118: Offline Persistence

All MVP data must be stored locally.

Recommended local database:

- Drift / SQLite

Data must survive:

- App restart.
- Session interruption.
- Android process death.

Mutations should be saved immediately.

---

### FR-119: Notifications

The app should request notification permission on Android 13+ when needed.

Notifications are used for:

- Rest timer completion when app is not focused.
- Possibly long rest completion.

MVP does not require a foreground service. However, the app should restore rest state from timestamps when reopened.

---

### FR-120: Export / Import

The app shall support JSON export.

Export includes:

- Exercises
- Workout templates
- Template exercises
- Sessions
- Session exercises
- Session sets

MVP import behavior:

- Confirm warning.
- Replace local data with imported data.

Future improvement:

- Merge by IDs.
- Cloud sync through Postgres.

---

## 9. Screen Requirements

### 9.1 Home / Workouts Screen

Purpose:

- Show all workout templates.
- Start a workout quickly.

UI elements:

- App bar with title.
- FAB: Add workout.
- List of workout cards.

Workout card shows:

- Workout name.
- Number of exercises.
- Estimated total sets.
- Last performed date, if available.
- Start button.
- Overflow menu:
  - Edit
  - Duplicate
  - Delete

Empty state:

- Friendly message.
- Button: “Create your first workout”.

UX priority:

- Start button should be prominent.
- Starting a workout should require as few taps as possible.

---

### 9.2 Workout Template Editor

Purpose:

- Create or edit workout template.

Sections:

1. Template metadata
   - Name
   - Notes
   - Default rest seconds
   - Auto-focus toggles

2. Exercise list
   - Reorderable
   - Add exercise button
   - Each exercise card shows:
     - Exercise name
     - Sets
     - Rest
     - Info icon
     - Edit/settings icon
     - Remove icon
     - Drag handle

Exercise settings inside template:

- Target sets
- Rest seconds
- Optional default RIR
- Optional default duration
- Optional note

Add exercise flow:

- Bottom sheet or full screen.
- Search existing exercises.
- Create new exercise inline.
- Select exercise.

Validation:

- Template name required.
- At least one exercise required to start session.

---

### 9.3 Exercise Editor

Purpose:

- Create or edit exercise details.

Fields:

- Name
- Category
- Logging type:
  - Strength
  - Duration
- Description
- Notes
- Image

Actions:

- Save
- Cancel
- Archive/delete

Validation:

- Exercise name required.

UX:

- Large text fields.
- Image preview.
- Simple and clean.

---

### 9.4 Active Session Screen

This is the most important screen.

Purpose:

- Run the workout efficiently.

Layout recommendation:

#### Top App Bar

- Workout name
- Elapsed time
- Overflow menu:
  - Session settings
  - Reorder exercises
  - Pause/resume
  - Finish
  - Cancel

#### Progress Header

- Completed sets / total sets
- Completed exercises / total exercises
- Current time or elapsed time
- Optional estimated remaining sets

#### Current Exercise Card

Shows:

- Exercise name
- Info icon
- Rest chip
- Set rows
- Add set button
- “Do later” button
- Optional collapse/expand

Set table columns for strength:

```text
Set | Weight | Reps | RIR | Done
```

Example for 3 sets:

```text
Set 1   [80.0]   [8]   [RIR 2 ▾]   [✓]
Set 2   [80.0]   [8]   [RIR 2 ▾]   [ ]
Set 3   [77.5]   [7]   [RIR 1 ▾]   [ ]
```

For duration exercises:

```text
Set | Duration | Done
```

Example:

```text
Set 1   [45s]   [✓]
Set 2   [45s]   [ ]
```

Current set row:

- Highlighted border or background.
- Larger visual focus.
- Easy to tap.

Completed set row:

- Slightly dimmed.
- Checkmark filled.
- Values still editable.

#### Upcoming Exercises Section

Shows collapsed upcoming exercises.

Each upcoming exercise card shows:

- Exercise name
- Sets remaining
- Rest time
- Info icon
- Drag handle
- Quick “Do next” action

Behavior:

- Tap to expand/focus.
- Drag to reorder.
- Completed exercises may be shown in a separate collapsed section above current/upcoming.

#### Rest Timer

Rest timer can be shown as:

- Bottom sheet.
- Persistent bottom bar.
- Expandable overlay.

It should not hide the ability to see upcoming exercises completely.

Recommended behavior:

- Compact rest bar remains visible.
- Tap expands to full rest controls.

---

### 9.5 Rest Timer UI

Rest timer UI should be extremely clear.

Elements:

- Large countdown text.
- Circular progress indicator.
- Next target label:
  - “Next: Bench Press — Set 2”
  - “Next: Lat Pulldown — Set 1”
- Buttons:
  - Pause
  - Resume
  - Skip
  - +15s
  - -15s
  - Cancel rest
- Optional:
  - Undo last completed set
- Auto-focus toggles accessible from session settings.

Visual states:

- Running: primary/rest color.
- Paused: muted/warning color.
- Finished: success color.

---

### 9.6 Session Settings Sheet

Accessible from active session.

Options:

- Auto-focus next set after rest
- Auto-focus next exercise after rest
- Keep screen on during session
- Sound on rest complete
- Vibration/haptics
- Edit session notes
- Weight unit display, read-only for current session

---

### 9.7 Session Summary Screen

Shown after finishing session.

Elements:

- Workout name
- Date
- Total duration
- Completed sets / total sets
- Completed exercises / total exercises
- Optional volume
- Session notes input
- Save button
- Discard button

Read-only summary can also be used for history detail.

---

### 9.8 History Screen

List of saved sessions.

Each item:

- Date
- Workout name
- Duration
- Completed sets

Tap:

- Opens read-only session detail.

---

### 9.9 Settings Screen

Settings:

- Default weight unit: kg/lb
- Default rest seconds for new template exercises
- Sound enabled
- Haptics enabled
- Keep screen on during active session
- Notification permission status
- Export data
- Import data
- About

---

## 10. Timer and Auto-Advance Specification

### 10.1 Rest Start Trigger

When a set is completed:

1. Save set completion.
2. Determine next pending target:
   - Next pending set in same exercise.
   - If none, first pending set in next exercise.
   - If none, session finish flow.
3. If next target exists:
   - If rest seconds > 0:
     - Start rest timer.
   - If rest seconds = 0:
     - Immediately focus next target.

### 10.2 Rest Source

Rest time comes from the session exercise’s rest seconds.

For MVP:

- Use current exercise’s rest setting after each completed set.
- If it is the last set of an exercise and another exercise exists, still use current exercise rest before moving to next exercise.
- If it is the last set of the entire workout, no rest is started.

Future enhancement:

- Optional “rest before first set” per exercise.
- Optional different rest after last set.

### 10.3 Rest Completion

When rest reaches zero:

If next target is same exercise:

- If `autoFocusNextSet` is enabled:
  - Focus next set.
- Else:
  - Show “Rest complete” and “Next set” button.

If next target is next exercise:

- If `autoFocusNextExercise` is enabled:
  - Focus next exercise.
- Else:
  - Show “Rest complete” and “Next exercise” button.

### 10.4 Rest Accuracy

Implementation rule:

- Store `restEndsAt` timestamp.
- UI calculates remaining time from current time and `restEndsAt`.
- Do not rely only on `Timer.periodic` decrementing an integer.
- When app resumes, recalculate remaining time.
- If rest ended while app was backgrounded, show rest complete state.

### 10.5 Background Behavior

MVP:

- Use local notification for rest completion.
- Restore timer state when app resumes.
- Recommend keeping app open or screen on during active rest.

Future:

- Foreground service for more reliable background timing.

---

## 11. Reordering Specification

### 11.1 Template Reordering

- Allowed in template editor.
- Changes template order.
- Uses drag handle.
- Saves sort order.

### 11.2 Session Reordering

- Allowed in active session.
- Affects session only.
- Does not affect template.
- Completed exercises are locked.
- Pending exercises can be reordered.
- Current exercise is first pending exercise by order unless manually focused.

### 11.3 Machine Occupied Flow

Primary flow:

1. User is on current exercise.
2. Machine is occupied.
3. User taps “Do later” on current exercise.
4. Current exercise moves to end of pending list.
5. Next pending exercise becomes current.
6. User continues workout.

Alternative flow:

1. User opens reorder mode.
2. Drags another exercise above current exercise.
3. Current exercise updates.
4. Continues workout.

---

## 12. Data Model

Use UUID strings for IDs. Store timestamps as ISO strings or Unix milliseconds.

### 12.1 Exercise

```dart
Exercise {
  id: String,
  name: String,
  category: String?,
  loggingType: LoggingType,
  description: String?,
  notes: String?,
  imagePath: String?,
  isArchived: bool,
  createdAt: DateTime,
  updatedAt: DateTime,
}
```

`LoggingType`:

```dart
enum LoggingType {
  strengthWeightRepsRir,
  durationOnly,
}
```

---

### 12.2 WorkoutTemplate

```dart
WorkoutTemplate {
  id: String,
  name: String,
  notes: String?,
  defaultRestSeconds: int,
  autoFocusNextSet: bool,
  autoFocusNextExercise: bool,
  createdAt: DateTime,
  updatedAt: DateTime,
}
```

---

### 12.3 TemplateExercise

```dart
TemplateExercise {
  id: String,
  templateId: String,
  exerciseId: String,
  sortOrder: int,
  targetSets: int,
  restSeconds: int,
  defaultRir: double?,
  defaultDurationSeconds: int?,
  notes: String?,
  createdAt: DateTime,
  updatedAt: DateTime,
}
```

---

### 12.4 WorkoutSession

```dart
WorkoutSession {
  id: String,
  templateId: String?,
  name: String,
  weightUnit: String,
  status: SessionStatus,
  autoFocusNextSet: bool,
  autoFocusNextExercise: bool,
  startedAt: DateTime,
  endedAt: DateTime?,
  pausedSeconds: int,
  notes: String?,
  createdAt: DateTime,
  updatedAt: DateTime,
}
```

`SessionStatus`:

```dart
enum SessionStatus {
  active,
  paused,
  completed,
  cancelled,
}
```

---

### 12.5 SessionExercise

```dart
SessionExercise {
  id: String,
  sessionId: String,
  exerciseId: String?,
  name: String,
  description: String?,
  notes: String?,
  imagePath: String?,
  loggingType: LoggingType,
  sortOrder: int,
  restSeconds: int,
  targetSets: int,
  sessionNotes: String?,
  createdAt: DateTime,
  updatedAt: DateTime,
}
```

This snapshot ensures session history remains valid even if the exercise library changes.

---

### 12.6 SessionSet

```dart
SessionSet {
  id: String,
  sessionExerciseId: String,
  setIndex: int,
  weight: double?,
  reps: int?,
  rir: double?,
  durationSeconds: int?,
  completedAt: DateTime?,
  createdAt: DateTime,
  updatedAt: DateTime,
}
```

---

### 12.7 RIR Values

For MVP, RIR dropdown values can be:

```text
—
0
0.5
1
1.5
2
2.5
3
3.5
4
4.5
5
```

Stored as nullable double.

If simpler is preferred, start with:

```text
0, 1, 2, 3, 4, 5
```

The data model should allow decimal RIR values.

---

## 13. Recommended Technical Stack

For MVP:

### Framework

- Flutter stable
- Android-first

### State Management

- Riverpod

Recommended because:

- Simple reactive state.
- Good for session/timer state.
- Works well with local DB streams.

### Navigation

- GoRouter

### Local Database

- Drift / SQLite

Recommended because:

- Strong local persistence.
- Good Flutter support.
- SQL-like structure helps later Postgres sync.

### Suggested Packages

- `flutter_riverpod`
- `go_router`
- `drift`
- `sqlite3_flutter_libs`
- `path_provider`
- `uuid`
- `image_picker`
- `flutter_local_notifications`
- `wakelock_plus`
- `shared_preferences`
- `intl`
- `share_plus` or `file_saver` for export

Avoid adding unnecessary packages.

---

## 14. Architecture Guidance

Use feature-based structure.

Example:

```text
lib/
  main.dart
  app/
  core/
    theme/
    utils/
    widgets/
  features/
    exercises/
    templates/
    sessions/
    history/
    settings/
    sync/
```

Suggested layers:

```text
UI -> Providers/Controllers -> Repositories -> Local Database
```

Important services:

- `TimerService`
- `NotificationService`
- `HapticsService`
- `BackupService`
- `SessionService`

### Session Controller

A dedicated controller should manage active session state:

- Current session
- Current exercise
- Current set
- Rest timer state
- Auto-focus settings
- Reordering
- Set completion/uncompletion
- Session finish/cancel

### Timer Service

`TimerService` should expose:

```dart
startRest({
  required Duration duration,
  required String sessionId,
  required String nextTargetId,
})

pauseRest()
resumeRest()
skipRest()
cancelRest()
addTime(Duration duration)
subtractTime(Duration duration)
```

Timer state:

```dart
RestTimerState {
  status: RestTimerStatus,
  restEndsAt: DateTime?,
  remaining: Duration,
  nextTargetType: set/exercise,
  nextTargetLabel: String,
}
```

---

## 15. Android / APK Requirements

The MVP will be installed via APK.

Requirements:

- No mandatory internet connection.
- No mandatory account/login.
- Must work on common Android phone sizes.
- Must support dark theme.
- Must handle app lifecycle changes.

Permissions:

- Notification permission for Android 13+.
- Storage/camera permission only when user chooses exercise image.

Build:

```bash
flutter build apk --release
```

Future:

```bash
flutter build apk --split-per-abi
```

---

## 16. UI/UX Design Principles

This is a top priority.

### 16.1 Gym Environment

The app will be used during workouts.

Therefore:

- Buttons must be large.
- Text must be readable quickly.
- Contrast must be high.
- Important actions must be thumb-reachable.
- Avoid tiny icons.
- Avoid clutter.
- Avoid accidental destructive actions.

### 16.2 Theme

Default:

- Dark theme.

Optional:

- Light theme later.

Suggested semantic colors:

- Primary/action color
- Success/completed color
- Rest/timer color
- Warning/paused color
- Danger/delete color
- Muted text color

### 16.3 Touch Targets

Minimum:

- 48dp touch targets for major actions.

Set completion should be easy to tap with one thumb.

### 16.4 Typography

Recommended:

- Large timer text.
- Clear labels.
- Avoid all caps for long text.
- Use tabular numbers for timer and inputs if possible.

### 16.5 Microinteractions

Use subtle feedback:

- Haptic on set completed.
- Haptic on rest finished.
- Snackbar with undo after completion or deletion.
- Smooth expansion of current exercise.
- Clear visual highlight for current set.

### 16.6 Empty States

Every empty state should have a clear call to action.

Examples:

- No workouts: “Create your first workout”.
- No exercises: “Create an exercise”.
- No history: “No completed sessions yet”.

### 16.7 Error Prevention

Use:

- Confirmation dialogs for destructive actions.
- Undo snackbars where possible.
- Inline validation.
- Disabled buttons only when necessary.

---

## 17. UI Details for Set Rows

### Strength Set Row

Recommended row layout:

```text
[Set 1] [Weight input] [Reps input] [RIR dropdown] [Complete]
```

For narrow screens, use responsive wrapping or compact inputs.

Example compact version:

```text
1  |  80.0 kg  |  8  |  RIR 2 ▾  |  ✓
```

Input behavior:

- Weight uses numeric keyboard with decimal.
- Reps uses integer keyboard.
- RIR uses dropdown.
- Complete button is a checkbox or circular button.

Completed state:

- Row dimmed.
- Check filled.
- Values remain editable.

Current pending set:

- Highlighted.
- Possibly auto-focused.

### Duration Set Row

```text
[Set 1] [Duration input] [Complete]
```

Example:

```text
1  |  45s  |  ✓
```

Duration input can be:

- Text field in seconds.
- Stepper.
- Quick chips: 15s, 30s, 45s, 60s.

MVP should keep it simple.

---

## 18. Edge Cases

### 18.1 Empty Template

If a template has no exercises:

- Disable start button.
- Show helpful message.

### 18.2 Exercise Deleted from Library

Sessions should preserve historical exercise snapshot.

Templates using archived/deleted exercises should show:

- Archived badge.
- Option to replace exercise.

### 18.3 App Killed During Rest

When app restarts:

- Restore active session.
- Recalculate rest from `restEndsAt`.
- If rest already finished:
  - Show rest complete state.

### 18.4 User Completes Next Set During Rest

If user completes another set while rest is running:

- Cancel current rest.
- Save newly completed set.
- Start new rest based on newly completed set.

### 18.5 Rest Time Is Zero

If rest time is zero:

- Do not show rest overlay.
- Immediately focus next pending set/exercise.

### 18.6 Last Set of Workout

When completing the last set:

- Do not start rest.
- Show finish/summary flow.

### 18.7 Missing Values

User may complete a set without entering weight, reps, or RIR.

MVP rule:

- Allow completion.
- Do not block the workout.
- Optionally show subtle incomplete indicator.

### 18.8 Reordering During Active Rest

Reordering should not cancel rest.

At rest completion:

- Recompute next target based on current session order and last completed set.

### 18.9 Duplicate Exercise Names

Allow duplicate names in library but show enough context.

Prefer unique names, but do not hard-block unless necessary.

### 18.10 Very Long Exercise Names

Use ellipsis or wrapping. Ensure info icon remains accessible.

---

## 19. Acceptance Criteria

### Template Creation

Given the user is on Home  
When they tap “Create workout”  
Then they can enter a workout name and add exercises.

Given the user is editing a template  
When they add an exercise  
Then they can set target sets and rest seconds.

Given the user saves a template  
When returning to Home  
Then the template appears in the list.

---

### Session Start

Given a template with 3 exercises  
When the user taps Start  
Then a session is created with the same exercise order.

Given an exercise has 3 target sets  
When the session is opened  
Then 3 set rows are shown for that exercise.

---

### Set Logging

Given a strength exercise set row  
When the user enters weight, reps, and RIR  
And taps complete  
Then the set is marked completed with a timestamp.

Given a set row  
When RIR is tapped  
Then a dropdown of RIR values appears.

---

### Rest Timer

Given an exercise has 90 seconds rest  
When the user completes a set  
Then a 90-second rest timer starts.

Given rest timer is running  
When the user taps +15s  
Then remaining time increases by 15 seconds.

Given rest timer is running  
When the user taps Skip  
Then rest ends immediately.

Given rest timer ends  
And auto-focus next set is enabled  
Then the next pending set is highlighted.

Given rest timer ends  
And auto-focus next exercise is enabled  
And the completed set was the final set of the exercise  
Then the next exercise is focused.

---

### Reordering

Given an active session with upcoming exercises  
When the user drags an upcoming exercise to a new position  
Then the session order updates immediately.

Given the current exercise is incomplete  
When the user taps “Do later”  
Then that exercise moves to the end of pending exercises.

Given session reordering  
When the session is saved  
Then the original template remains unchanged.

---

### Exercise Info

Given an exercise appears in a session  
When the user taps the `i` icon  
Then description, notes, and image are shown if available.

---

### Persistence

Given an active session  
When the app is closed and reopened  
Then the active session is restored.

Given rest is running  
When the app is closed and reopened  
Then remaining rest is recalculated from the stored end timestamp.

---

### Finish

Given all sets are completed  
When the user finishes the workout  
Then a summary screen is shown.

Given some sets are incomplete  
When the user tries to finish  
Then a warning is shown.

Given a completed session  
When the user opens History  
Then the session is visible in the list.

---

## 20. Postgres Backend / Sync Plan — Later Phase

Do not implement sync in the first MVP unless explicitly requested.

However, design the app so sync can be added later.

### 20.1 Recommended Backend Option

Preferred for faster development:

- Supabase Postgres
- Supabase Auth
- Supabase Storage for images, later

Alternative:

- Self-hosted Postgres
- FastAPI or PostgREST
- JWT auth

### 20.2 Sync Principles

- Client-generated UUIDs.
- Offline-first.
- Every row has `updated_at`.
- Use soft delete with `deleted_at`.
- Sync only after login.
- Local changes are queued in an outbox.
- Pull changes using `updated_at` cursor.
- Sessions are mostly append-only.
- Templates and exercises are mutable.

### 20.3 Suggested Postgres Tables

```sql
create table app_user (
  id uuid primary key,
  email text unique not null,
  created_at timestamptz not null default now()
);

create table exercise (
  id uuid primary key,
  user_id uuid not null references app_user(id),
  name text not null,
  category text,
  logging_type text not null,
  description text,
  notes text,
  image_path text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table workout_template (
  id uuid primary key,
  user_id uuid not null references app_user(id),
  name text not null,
  notes text,
  default_rest_seconds integer not null default 90,
  auto_focus_next_set boolean not null default true,
  auto_focus_next_exercise boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table template_exercise (
  id uuid primary key,
  user_id uuid not null references app_user(id),
  template_id uuid not null references workout_template(id),
  exercise_id uuid references exercise(id),
  sort_order integer not null,
  target_sets integer not null default 3,
  rest_seconds integer not null default 90,
  default_rir numeric,
  default_duration_seconds integer,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table workout_session (
  id uuid primary key,
  user_id uuid not null references app_user(id),
  template_id uuid,
  name text not null,
  weight_unit text not null default 'kg',
  status text not null,
  auto_focus_next_set boolean not null default true,
  auto_focus_next_exercise boolean not null default true,
  started_at timestamptz not null,
  ended_at timestamptz,
  paused_seconds integer not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table session_exercise (
  id uuid primary key,
  user_id uuid not null references app_user(id),
  session_id uuid not null references workout_session(id),
  exercise_id uuid,
  name text not null,
  description text,
  notes text,
  image_path text,
  logging_type text not null,
  sort_order integer not null,
  rest_seconds integer not null,
  target_sets integer not null,
  session_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table session_set (
  id uuid primary key,
  user_id uuid not null references app_user(id),
  session_exercise_id uuid not null references session_exercise(id),
  set_index integer not null,
  weight numeric,
  reps integer,
  rir numeric,
  duration_seconds integer,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
```

### 20.4 Sync API Shape

If using custom backend:

```text
POST /v1/auth/register
POST /v1/auth/login
POST /v1/sync/push
GET  /v1/sync/pull?since=timestamp
POST /v1/images/upload
```

Push payload example:

```json
{
  "changes": [
    {
      "entityType": "exercise",
      "operation": "upsert",
      "data": {}
    },
    {
      "entityType": "workoutSession",
      "operation": "upsert",
      "data": {}
    }
  ]
}
```

### 20.5 Conflict Resolution

MVP sync rule:

- Last write wins based on `updated_at`.
- For session sets, prefer preserving completed data.
- For deleted rows, use soft delete.

Future:

- More advanced merge rules.
- Device conflict screen.

---

## 21. Implementation Phases

### Phase 1: App Foundation

Tasks:

- Create Flutter project.
- Add dependencies.
- Set up Material 3 theme.
- Set up GoRouter.
- Set up Drift database.
- Create base models and DAOs.
- Create empty Home screen.

Definition of done:

- App builds.
- Navigation works.
- Local DB initializes.

---

### Phase 2: Exercise Library

Tasks:

- Exercise model/table.
- Exercise list screen.
- Exercise editor screen.
- Add image support.
- Archive/delete.
- Search.

Definition of done:

- User can create exercises with info and image.
- Exercises persist after restart.

---

### Phase 3: Workout Templates

Tasks:

- Template model/table.
- Template list on Home.
- Template editor.
- Add exercises to template.
- Reorder template exercises.
- Configure sets/rest.
- Duplicate/delete template.

Definition of done:

- User can create Push/Pull/Legs/Stretch templates.
- Template data persists.

---

### Phase 4: Session Snapshot

Tasks:

- Start session from template.
- Create session snapshot.
- Generate session exercises and sets.
- Active session screen skeleton.
- Display set rows.

Definition of done:

- Starting a template creates an active session.
- Exercise with 3 sets shows 3 rows.

---

### Phase 5: Set Logging UI

Tasks:

- Weight input.
- Reps input.
- RIR dropdown.
- Duration input for stretch exercises.
- Complete/uncomplete set.
- Add/remove sets.
- Save all changes locally.

Definition of done:

- User can manually log all set values.
- Values persist after restart.

---

### Phase 6: Rest Timer

Tasks:

- Timer service.
- Rest bottom sheet.
- Start rest on set complete.
- Pause/resume.
- Skip.
- +/- 15 seconds.
- Restore after app restart.
- Local notification on rest end.

Definition of done:

- Rest timer works accurately and is visually clear.

---

### Phase 7: Auto-Focus and Session Flow

Tasks:

- Current set computation.
- Next set computation.
- Auto-focus next set.
- Auto-focus next exercise.
- Rest complete state.
- Finish session flow.

Definition of done:

- Workout flows smoothly from set to set and exercise to exercise.

---

### Phase 8: Reordering During Session

Tasks:

- Reorderable upcoming exercise list.
- Drag handle.
- Session-only order persistence.
- “Do later” action.
- Current exercise recomputation.

Definition of done:

- User can adapt session order mid-workout.

---

### Phase 9: Exercise Info and Polish

Tasks:

- Info icon everywhere.
- Info bottom sheet.
- Image display.
- Dark theme polish.
- Haptics.
- Empty states.
- Undo snackbars.

Definition of done:

- App feels polished and usable during workout.

---

### Phase 10: History, Summary, Export

Tasks:

- Session summary.
- Save session.
- History list.
- Read-only session detail.
- JSON export.
- JSON import.

Definition of done:

- Completed workouts are stored and recoverable.

---

### Phase 11: APK Build and Manual Testing

Tasks:

- Build release APK.
- Test on real Android device.
- Test app kill during rest.
- Test notification permission.
- Test long workout.
- Test reorder and auto-advance.

Definition of done:

- APK can be installed and used reliably.

---

### Phase 12: Postgres Sync

Only after MVP is stable.

Tasks:

- Auth.
- Sync outbox.
- Push/pull API.
- Supabase or self-hosted Postgres.
- Image upload.
- Conflict resolution.

---

## 22. Definition of Done for MVP

The MVP is done when:

1. User can create workouts and exercises.
2. User can add image, description, and notes to exercises.
3. User can start a session from a template.
4. Exercises with multiple sets show multiple rows.
5. Each strength set has weight, reps, and RIR dropdown.
6. Completing a set starts rest timer.
7. Rest timer can be paused, skipped, adjusted, and restored.
8. Auto-focus next set/exercise works according to toggles.
9. User can reorder upcoming exercises during session.
10. Session changes do not modify template.
11. Session can be finished and viewed in history.
12. App works offline.
13. App can build a release APK.
14. UI is dark, clean, and easy to use during workout.

---

## 23. Suggested Project Structure

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
  core/
    theme/
    utils/
    widgets/
    services/
      timer_service.dart
      notification_service.dart
      haptics_service.dart
      backup_service.dart
  db/
    app_database.dart
    tables.dart
    daos/
  features/
    exercises/
      data/
      ui/
      providers/
    templates/
      data/
      ui/
      providers/
    sessions/
      data/
      ui/
      providers/
      widgets/
    history/
      data/
      ui/
      providers/
    settings/
      ui/
      providers/
```

---

## 24. Important UX Rules for Claude Code

When implementing UI:

1. Do not make the user navigate away from the active session just to adjust rest.
2. Do not require many taps to complete a set.
3. Do not hide the next exercise.
4. Do not make inputs tiny.
5. Do not block set completion if RIR or weight is missing.
6. Do not modify template when changing session order.
7. Do not lose active session state on app restart.
8. Do not use confusing modal stacks during rest.
9. Always provide visible undo for destructive or accidental actions.
10. Keep the active session screen optimized for one-handed use.

---

## 25. Copy-Paste Starter Prompt for Claude Code

You can paste this after the PRD:

```text
You are building an Android-first Flutter app based on the PRD above.

Important constraints:
- MVP is offline-first. Do not implement Postgres sync yet.
- Use Flutter, Riverpod, GoRouter, and Drift/SQLite.
- Use Material 3 with dark theme as default.
- Prioritize UI/UX, simplicity, and reliability during active workouts.
- Keep architecture clean but practical.
- Do not add unnecessary packages.
- Do not implement features outside the MVP unless required to support the MVP.

Implementation order:
1. Project setup, theme, router, database skeleton.
2. Exercise library with description, notes, image, logging type.
3. Workout templates with ordered exercises, sets, and rest seconds.
4. Session creation from template as a snapshot.
5. Active session UI with set rows.
6. Manual logging for weight, reps, RIR dropdown, and duration.
7. Rest timer service and rest UI.
8. Auto-focus next set/exercise behavior.
9. Session-only exercise reordering.
10. Session summary, history, export/import.
11. APK build readiness.

For each step:
- Explain the files you will create or modify.
- Provide complete code where practical.
- Keep code compatible with the existing project.
- Use immutable models where reasonable.
- Persist changes immediately.
- Handle Android app lifecycle for active session and rest timer.

Start with the project structure and database schema.
```

---

## 26. Open Questions for Future Refinement

These are not blockers for MVP, but useful to decide later:

1. Should weight also use dropdowns based on recent values?
2. Should RIR support only integers or also halves?
3. Should rest after the final set of an exercise be optional?
4. Should exercises support supersets/circuits later?
5. Should history include charts or volume progression?
6. Should images sync to Postgres storage or remain local-only?
7. Should templates support per-set target values?
8. Should the app support “rest before first set”?
9. Should completed sessions be editable?
10. Should session reordering optionally update the template?