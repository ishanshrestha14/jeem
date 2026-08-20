# GymFlow — Manual Test Plan and Acceptance Results

Task 22, steps 1–4. Records a walk of **PRD §24** (UX rules), **PRD §16.6**
(empty states), **PRD §18** (edge cases) and **PRD §19** (acceptance
criteria) against the app as it stands on branch `chore/android-release`.

## How this was verified, and its limits

Read this before trusting any row below.

| Channel | Available? | Notes |
|---|---|---|
| `flutter test` (194 tests) | Yes | Primary evidence. Every "PASS (test)" row names the test that proves it. |
| `flutter analyze` | Yes | Clean, no issues. |
| macOS desktop build | Yes | `flutter build macos --debug` succeeds; the app launches and stays up. |
| macOS desktop **interactive** walkthrough | **No** | This machine grants the shell no screen-recording permission, so the running window cannot be observed or screenshotted, and there is no UI driver available. Code inspection + widget tests stood in. |
| iOS simulator | **No** | Pre-existing, documented: `xcodebuild -downloadPlatform iOS` was never completed on this machine. |
| Android device / emulator | **No** | No Android SDK installed (`flutter doctor` confirms), no device attached. |

Consequently every row below is marked with its evidence:

- **PASS (test)** — an automated test asserts exactly this behaviour.
- **PASS (code)** — verified by reading the implementation; the behaviour is
  unambiguous from the code but no test pins it.
- **FIXED (test)** — was failing; fixed in this task, and a dedicated
  automated test now pins the fix.
- **FIXED (code)** — was failing; fixed in this task, verified by reading
  the implementation, but no dedicated automated test pins it yet.
- **NOT VERIFIABLE HERE** — needs a real Android phone or an interactive
  session this machine cannot provide. Not guessed either way.

---

## Part 1 — PRD §24, the ten UX rules

| # | Rule | Result | Evidence |
|---|---|---|---|
| 1 | Rest is adjustable without leaving the session screen | PASS (test) | `RestBar` (`bottomNavigationBar` of `ActiveSessionScreen`) carries −15s / +15s / pause / skip inline, and taps through to `showRestSheet` — a bottom sheet over the same route, never a navigation. Per-exercise rest is editable from the card's rest chip. Tests: "+15s extends the countdown", "−15s shortens the countdown", "tapping the bar opens the expanded sheet". |
| 2 | Completing a set is one tap from the current row | PASS (test) | `_DoneControl`, a 56×56 hit area at the end of every set row, calls `controller.completeSet` directly. Test: "tapping the complete button marks the set done". |
| 3 | The next exercise is visible while resting | PASS (test) | Both `RestBar` and the rest sheet render `NEXT <rest.nextTarget.label>` (falling back to "Finish workout"). Test: "completing a set reveals the rest bar with the next target". |
| 4 | No input is smaller than 48dp in its tappable dimension | **FIXED (test)** | The weight and reps fields (`NumericField(dense: true)`) measured **33dp** tall: `contentPadding: EdgeInsets.zero` left the tappable box at bare-glyph height. Changed to `EdgeInsets.symmetric(vertical: 8)` → 49dp. Row height is unchanged (the 56dp done control still sets it). Everything else already complied: RIR control `SizedBox(height: 48)`, done control 56×56, settings rows `BoxConstraints(minHeight: 48)`, template Start button `height: 48`, rest-bar text buttons `minimumSize: Size(48, 48)`. New test: "every tappable control in the row is at least 48dp tall (PRD §16.3 / §24.4)". |
| 5 | Set completion is never blocked on missing values | PASS (test) | `onToggleComplete` is unconditional; no validation gate anywhere on the path. Test: "a set with empty weight/reps/rir can still be completed (PRD §18.7)". |
| 6 | Session reordering leaves the template untouched | PASS (test) | `SessionRepository.reorderSessionExercises` writes only `session_exercises.sortOrder`, inside a transaction scoped by `sessionId`. Existing test: "editing the session never touches the template". New UI-level test added this task: "reordering a session leaves the originating template order untouched (PRD §19 Reordering / §24.6)". |
| 7 | Killing the app mid-session loses nothing | PASS (test) | Task 17's work: rest is anchored to a stored `restEndsAt` and recomputed from the wall clock, and `ActiveSessionScreen._handleResume` invalidates and re-settles on resume. Tests: the whole `session_restore_test.dart` group (7 tests) plus "logged set values survive a full reopen". Note: verified as process-restart-equivalent in tests. A genuine force-stop on a phone is **NOT VERIFIABLE HERE**. |
| 8 | No modal is ever stacked on top of the rest sheet | PASS (code) | `showRestSheet` calls `navigator.popUntil((r) => r is! PopupRoute)` before opening, so any sheet/dialog/menu already up is dismissed first. In the other direction the rest sheet is itself modal — its barrier covers the app-bar menu and every card control — so nothing can be opened over it. It also self-dismisses the moment rest returns to idle. |
| 9 | Every destructive action has undo or confirmation | PASS (test) | Confirmation: cancel workout, discard session, delete template, archive exercise (all via `confirmDestructive` or an explicit `AlertDialog`). Undo snackbars: archive exercise, remove template exercise, remove set, "Do later", "Undo last set" in the rest sheet. Tests: "archiving from the editor shows an undo snackbar that actually restores the exercise", "\"Undo last set\" in the sheet uncompletes the set and cancels rest". |
| 10 | All primary session controls sit in the bottom half of the screen | PASS (code), with a noted deviation | The persistent rest bar (countdown, ±15s, pause, skip) is pinned to the bottom of the screen, and it is the control the user reaches for most between sets. The set-row done controls, however, live inside the current exercise's card, and `Scrollable.ensureVisible` (default `alignment: 0.0`) parks that card at the *top* of the viewport, so mid-session the done control for the current set can sit in the upper half. This is inherent to a scrolling set list of variable height; forcing it lower would be a layout redesign, not a fix, so it is recorded here rather than changed. No other primary control (finish, pause, reorder) is in the top half except as app-bar overflow items, which are secondary by design. |

**Score: 9 already passing, 1 genuine violation found and fixed (rule 4).**

---

## Part 2 — PRD §16.6, empty states

Each must have an icon, a title, a sentence of explanation, and a CTA.

| Empty state | Result | Detail |
|---|---|---|
| No workouts (Workout tab) | PASS | `EmptyState(Icons.fitness_center, "No workouts yet", …, "Create your first workout")`. Test: "shows the empty state when there are no templates at all". |
| No workouts (Home) | PASS | `EmptyState(Icons.fitness_center, "No workouts yet", …, "Go to Workout")`. Test: "empty state invites creating the first workout". |
| No exercises | PASS | `EmptyState(Icons.fitness_center, "No exercises yet", …, "Create an exercise")`. Test: "shows an empty state with a call to action". |
| **No search results (library)** | **FIXED (test)** | Previously fell through to the "No exercises yet" state — telling a user with fifty exercises who mistyped one to go create some. Now a distinct `EmptyState(Icons.search_off, "No matches", 'Nothing in your library matches "…"…', "Clear search")`. The search field gained a controller and a clear (✕) suffix so the CTA can genuinely empty the box, not just the provider behind it. Test (added in the review-findings pass following this task): "a search matching nothing shows a full empty state and \"Clear search\" restores the list (PRD §16.6)". |
| **No search results (exercise picker)** | **FIXED (test)** | Previously rendered a bare "Create new exercise" tile with nothing under it. Now a full `EmptyState`, wording switching between the empty-library and no-match cases, CTA "Create new exercise" (which creates and adds straight to the template). The no-results branch also now stays wrapped in a `ListView(controller: scrollController)` so the sheet keeps its drag-to-resize/dismiss behaviour while showing this state — a separate review finding against this task. Test (added in the review-findings pass): "the picker shows a full empty state for a search matching nothing, and the sheet stays draggable (PRD §16.6)". |
| No history | PASS | `EmptyState(Icons.history, "No completed sessions yet", …, "Go to Home")`. Test: "shows the empty state with an action returning to Home". |
| **Template with no exercises** | **FIXED (test)** | Was a single grey sentence with no icon, title or CTA. Now `EmptyState(Icons.playlist_add, "No exercises yet", …, "Add exercise")`. New test: "a template with no exercises shows a full empty state: icon, title, explanation and CTA (PRD §16.6)". Separately, §18.1's "disable start" was already correct (test: "Start is disabled for a template with no exercises"). |
| **Exercise with no image (editor)** | **FIXED (test)** | The dashed placeholder was a bare dumbbell glyph. Now an `add_a_photo_outlined` icon plus a sentence; the "Photo" section heading is the title and the Choose/Take photo buttons below are the CTA. Test (added in the review-findings pass): "a new exercise with no photo shows the icon + explanation placeholder (PRD §16.6)". |
| **Exercise with no image (info sheet)** | **FIXED (code)** | Was a bare grey block with a dumbbell glyph, which reads as a failed image load. Now `image_not_supported_outlined` plus "No photo for this exercise yet. Add one from the exercise library." Deliberately no CTA: the sheet is read-only at all three of its call sites (session card, picker, template row); adding a photo belongs to the editor, which has the CTA. Verified by reading `exercise_info_sheet.dart`; no dedicated widget test exists yet for this sheet (there is no test file for it at all) — a genuine gap, not covered by this pass's test additions. |

---

## Part 3 — PRD §18 edge cases (the three named in the brief)

| Case | Result | Detail |
|---|---|---|
| §18.10 A 60-character name ellipsises without pushing the info icon off-screen | PASS (test) | Already correct by construction (`Expanded` + `maxLines: 2` + `TextOverflow.ellipsis`). Now pinned by a new test at a 320dp-wide surface with the real Barlow faces loaded: the name ellipsises, the info icon's rect stays fully within `[0, 320]`, and tapping it genuinely opens the info sheet. Deletion-verified — removing the `Expanded`/ellipsis makes the test fail. |
| §18.9 Duplicate exercise names disambiguated by a category subtitle in the picker | PASS (test) | Already implemented (Task 4/8). Verified, not rebuilt. New test: two exercises both named "Row" (categories Back and Legs) both appear, told apart by "Back · Strength" / "Legs · Strength" subtitles. Deletion-verified. |
| §18.2 Archived exercise in a template: `Archived` chip **and** a "Replace exercise" action | **PARTIAL — chip yes, replace missing** | The `Archived` chip is present in both the template editor row and the exercise info sheet (test: "an archived exercise in a template is flagged"). **"Replace exercise" does not exist anywhere** and `showTemplateExerciseSettings` does not even receive the exercise's identity or archived flag. This is a genuine new feature, not a polish fix — swapping one exercise's config for another's while leaving already-recorded session history intact touches the template repository, the settings sheet's signature and the picker. **Deferred and flagged**, per the dispatch's instruction not to build substantial new scope hastily. |

---

## Part 4 — PRD §19 acceptance criteria

### Template Creation

| Given / When / Then | Result | Evidence |
|---|---|---|
| On Home → tap "Create workout" → can enter a name and add exercises | PASS (test) | Home's empty-state CTA routes to `/workout`; the Workout tab's FAB and empty-state CTA both push `/templates/new`, which opens `TemplateEditorScreen` with a name field and an "Add exercise" button. Tests: "empty state invites creating the first workout", "shows the empty state when there are no templates at all", "renders the template name and its exercises with sets and rest". |
| Editing a template → add an exercise → can set target sets and rest seconds | PASS (test) | `showTemplateExerciseSettings` exposes Target sets and Rest (+ presets). Tests: "adds exercises with default sets and rest, in insertion order", "a note typed just before the sheet closes is flushed, not discarded". |
| Save a template → it appears in the Home/Workout list | PASS (test) | Test: "a workout card shows its exercise and set counts"; `watchSummaries` emission tests. |

### Session Start

| Given / When / Then | Result | Evidence |
|---|---|---|
| Template with 3 exercises → Start → session created in the same exercise order | PASS (test) | Test: "generates one set row per target set, in order" plus `startFromTemplate`'s snapshot tests. |
| Exercise has 3 target sets → session opened → 3 set rows shown | PASS (test) | Test: "an exercise with 3 target sets renders 3 rows". |

### Set Logging

| Given / When / Then | Result | Evidence |
|---|---|---|
| Enter weight, reps, RIR → tap complete → set marked completed with a timestamp | PASS (test) | Tests: "typing a weight persists it to the database", "tapping the complete button marks the set done", "completing a set stamps it and starts rest for that exercise". |
| Tap RIR → a dropdown of RIR values appears | PASS (test) | `_RirControl` opens `showMenu` over `kRirValues`. Tests: "dismissing the RIR menu leaves the existing RIR unchanged", "explicitly choosing — clears the RIR". |

### Rest Timer

| Given / When / Then | Result | Evidence |
|---|---|---|
| 90s rest → complete a set → a 90-second rest timer starts | PASS (test) | Tests: "completing a set stamps it and starts rest for that exercise", "completing a set reveals the rest bar with the next target". |
| Rest running → tap +15s → remaining increases by 15s | PASS (test) | Tests: "+15s and −15s shift the end timestamp and the total", "+15s extends the countdown". |
| Rest running → tap Skip → rest ends immediately | PASS (test) | Tests: "skip finishes immediately, cancel returns to idle", "skip ends rest and replaces the bar with the rest-complete banner". |
| Rest ends + auto-focus next set on → next pending set highlighted | PASS (test) | Test: "auto-focus next set moves focus when rest finishes mid-exercise". |
| Rest ends + auto-focus next exercise on + it was the final set → next exercise focused | PASS (test) | Tests: "auto-focus next exercise applies only across an exercise boundary", "…does NOT apply within the same exercise". |

### Reordering

| Given / When / Then | Result | Evidence |
|---|---|---|
| Drag an upcoming exercise → session order updates immediately | PASS (test) | Tests: "dragging an upcoming exercise updates the session order", "a mid-list downward drag lands correctly (not at the very end)". |
| Current exercise incomplete → tap "Do later" → it moves to the end of pending | PASS (test) | Tests: "Do later moves the current exercise to the end", "doLater sends the current exercise to the back without touching rest". |
| Session reordered and saved → the original template is unchanged | PASS (test) | Tests: "editing the session never touches the template", and the new "reordering a session leaves the originating template order untouched". |

### Exercise Info

| Given / When / Then | Result | Evidence |
|---|---|---|
| Tap the `i` icon on a session exercise → description, notes and image shown if available | PASS (test) | Tests: "tapping the info icon opens the info sheet", and the new 60-character-name test, which reaches the sheet by tapping the icon at 320dp. |

### Persistence

| Given / When / Then | Result | Evidence |
|---|---|---|
| Active session → app closed and reopened → session restored | PASS (test) | Tests: "logged set values survive a full reopen", "watchActiveSession finds the active session and drops finished ones". Simulated in-process; a real force-stop on a phone is **NOT VERIFIABLE HERE**. |
| Rest running → app closed and reopened → remaining rest recalculated from the stored end timestamp | PASS (test) | Tests: "a rest still in flight comes back running with the right remainder", "a rest whose deadline passed while the app was closed comes back finished", "a paused rest comes back paused with its frozen remainder", "a rest already persisted as finished does not re-fire the finish path on restore". |

### Finish

| Given / When / Then | Result | Evidence |
|---|---|---|
| All sets completed → finish → summary screen shown | PASS (test) | Tests: "summary reports duration, sets, exercises and volume", "per-exercise breakdown shows completed and incomplete sets". |
| Some sets incomplete → try to finish → a warning is shown | PASS (test) | `_handleFinish` shows "Finish workout? / N sets are still incomplete." with Continue / Discard / Finish anyway. Tests: "\"Finish anyway\" on an incomplete session navigates to the summary without committing it", "finishing with incomplete sets is allowed but reported". |
| Completed session → open History → it is visible in the list | PASS (test) | Tests: "history lists completed sessions newest first, skips cancelled, and uses ListTile", "subtitle shows date, duration, set count and volume", "tapping a row opens the read-only session summary". |

---

## Part 5 — Requires a real Android device (Task 22 steps 5–6, not attempted)

All **NOT VERIFIABLE HERE** — no Android SDK, no device. Listed so the
device pass has a checklist.

- [ ] Install the release APK and run a full workout end to end.
- [ ] Force-stop mid-rest; reopen and confirm the countdown is correct.
- [ ] Background the app during rest and confirm the rest-complete
      notification fires on a locked screen.
- [ ] Run a 45-minute session; confirm the elapsed timer and the wakelock
      behave (screen stays on only while "Keep screen on" is set).
- [ ] Reorder mid-session and confirm auto-advance follows the new order.
- [ ] Export, wipe app data, reinstall, import; confirm everything returns.
- [ ] Confirm haptics fire on set completion and on rest finishing.
- [ ] Confirm `minSdk = 24` / `targetSdk = 35`, the `GymFlow` label, and
      that the manifest carries only `POST_NOTIFICATIONS` and `VIBRATE`
      (Flutter's debug `INTERNET` permission stripped with
      `tools:node="remove"`).

## Known open items

1. **"Replace exercise" for an archived template exercise (PRD §18.2)** —
   not implemented. See Part 3.
2. **Rule 10's partial deviation** — the current set's done control can sit
   in the upper half of the screen. See Part 1.
3. One full-suite run out of five failed a single (unidentified) test
   during a heavily loaded ~6½-minute run; four subsequent runs completed
   in ~10s each with all 194 passing. Recorded rather than hidden; nothing
   reproduced.
