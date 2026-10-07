# Data & Query Performance (Perf Batch 3) — 2026-07-24

Third execution batch from `documentation/performance-improvement-plan.md` (items P1.7, P1.6, P2.13).
Focus: stop faulting whole tables into memory, stop re-deriving in `body`, and index the fields the
new queries use.

## Changes

### P1.7 — Query `CareTaskCompletion` directly
- `Views/SettingsView.swift`: `weeklyCompletionCount` used to `flatMap` every task's completions into
  memory on every render to count this week's. It now uses `ModelContext.fetchCount` with a
  `#Predicate { $0.completedAt >= startOfWeek }` — a store-side COUNT that materializes nothing. The
  now-unused `@Query allCareTasks` was removed (replaced by `@Environment(\.modelContext)`).
- `Views/HistoryView.swift`: replaced the `HistoryViewModel` (which `flatMap`ped all tasks'
  completions and hand-sorted them on a background `Task`, with a loading state) with a direct
  `@Query(sort: \CareTaskCompletion.completedAt, order: .reverse)`. Completions now come from the
  store already sorted, no task faulting, no async loading step. The `.cascade` delete rule on
  `CareTask.completions` guarantees no orphaned completions, so the result set is identical.

### P1.6 — Move derivations out of `body`
- `Views/HistoryView.swift`: `scopedCompletions`, `filteredCompletions`, and `presentationState`
  were separate computed properties, each re-run per render (and `scopedCompletions` re-filtered
  several times). They are now derived once at the top of `body` and reused across the header, state
  switch, and list.
- `Views/HomePageView.swift`: `currentTaskSections` was read twice per render (empty check + list).
  It is now derived once in `currentTasksSection` and passed into
  `currentTasksSectionContent(sections:)`.
- `Views/Tasks/TaskAssistantView.swift`: collapsed two `onChange` handlers (`map(\.id)` and
  `map(\.updatedAt)`, each allocating an array and both firing for one change) into a single
  `onChange` on a `TaskChangeToken` signature. `TaskChangeToken` (from `TaskManagementView`) was
  promoted from `private` to shared for reuse.

### P2.13 — SwiftData index
- `Models/CareTask.swift`: added `#Index<CareTaskCompletion>([\.completedAt], [\.completedForDate])`
  to back the history sort and the weekly-count predicate. The store is local (non-CloudKit), so
  `#Index` is available; adding an index is a lightweight schema change (no data migration).

## Verification
- `xcodebuildmcp` `build_sim` clean, zero warnings.
- Full `CatCareCalendarTests` unit target green (166 tests), incl. `HistoryPresentationTests`,
  `TaskCalendarDerivationTests`, and the assistant suites.
- `build_run_sim` launches clean on iPhone 12 / iOS 26.5.

## Notes
- History and the Settings weekly count no longer degrade as `CareTaskCompletion` grows over the
  app's lifetime — the dominant reason those screens would have slowed down over months of use.
