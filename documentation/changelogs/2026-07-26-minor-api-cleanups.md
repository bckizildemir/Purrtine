# Minor API Cleanups (Perf Batch 5) — 2026-07-26

Fifth and final execution batch from `documentation/performance-improvement-plan.md` (P3 items).
Small modern-API cleanups; low individual impact, done to close out the plan.

## Changes

### History search uses `localizedStandardContains`
- `Models/HistoryPresentation.swift`: `filteredCompletions` matched by lowercasing every field and the
  query, then `.contains`. It now uses `localizedStandardContains` (case/diacritic-insensitive, the
  repo standard for user-input filtering) directly, dropping the per-completion `.lowercased()`
  allocations.

### `UIScreen.main.bounds` removed
- `Views/Cat/CatsTabView.swift`: `isNarrowPhone` read `UIScreen.main.bounds.width` (discouraged —
  ignores the actual container and multi-window). It now reads the view's own width via
  `onGeometryChange` into `@State`. Grid columns were already `.adaptive`, so this only affects the
  minor narrow-phone spacing/padding tweaks.

### `GeometryReader` removed from the onboarding progress bar
- `Views/Onboarding/PageIndicatorView.swift`: replaced the `GeometryReader` (used only to size the
  fill capsule proportionally) with `onGeometryChange` measuring the track width into `@State`.
  `containerRelativeFrame` was not used here because it measures the scroll/window container, not the
  indicator's own (possibly constrained) width.

## Verification
- `xcodebuildmcp` `build_sim` clean, zero warnings.
- Full `CatCareCalendarTests` unit target green (166 tests).

## Plan status
All P0, P1, P2, and P3 items from the performance plan are now shipped, except two intentional
deferrals documented in earlier changelogs:
- `@MainActor` on the `@Observable` singletons (needs a dedicated strict-concurrency pass).
- `CareTask.photoURLs` proof-photo storage (written but never displayed — needs a product decision).
