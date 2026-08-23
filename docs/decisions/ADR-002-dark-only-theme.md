# ADR-002 — Dark-only theme, no light mode

- **Status:** Accepted
- **Date:** 2026-08-23

## Context

Project facts described the app as "Material 3, dark theme default". Reading the code on 2026-08-23
shows something stricter than a default:

- `lib/app/app.dart` — `theme: AppTheme.dark()` with `themeMode: ThemeMode.dark`. No `darkTheme:`
  is supplied and no light theme exists.
- `lib/core/theme/app_theme.dart` — documented in-file as *"Dark only, explicit `ColorScheme.dark`
  (never `.fromSeed` — seeded schemes …)"*.
- `lib/core/theme/semantic_colors.dart` carries a single palette.

"Default" implies a light theme exists and is not selected. It doesn't. The owner confirmed on
2026-08-23: **dark mode only.**

## Decision

The app ships **one theme: dark**. There is no light theme, no `ThemeMode.system`, and no theme
toggle in Settings (S-020).

Consequences for how we write specs and code:

- Specs never document a "light variant" of a surface. A screenshot is a dark screenshot.
- Colours come from the explicit `ColorScheme.dark` and `semantic_colors.dart` — **never**
  `ColorScheme.fromSeed`, which would generate tonal values the design system did not choose.
- Contrast is validated against the dark palette only, but must be validated: dark-only removes a
  variable, it does not remove the accessibility obligation. Session surfaces are read at arm's
  length, mid-effort, often sweaty-handed — legibility is a functional requirement here, not polish.
- Widgets must not branch on `Theme.of(context).brightness`; there is one branch.

## Consequences

- Half the theming surface area disappears: one palette to maintain, one set of screenshots, no
  light-mode QA pass in `MANUAL_TEST_PLAN.md`.
- Adding light mode later is a real project, not a flip: every hard-coded colour and every
  `semantic_colors.dart` token would need a light counterpart, and `.fromSeed` still wouldn't be an
  acceptable shortcut. Accepted knowingly — this is a personal, install-by-APK app for one user who
  trains in a dark gym.
- The design system doc (`docs/design/gymflow-design-system.md`) is the authority on the palette;
  this ADR only fixes the *number of themes*.

## Alternatives considered

- **`ThemeMode.system` with a light theme.** Rejected: doubles palette work and QA for a
  single-user app whose owner wants dark.
- **Dark default + manual toggle.** Rejected for the same reason, plus it adds a Settings row and a
  persisted preference for zero benefit.
