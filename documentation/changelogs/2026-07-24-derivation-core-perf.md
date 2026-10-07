# Derivation Core Performance (Perf Batch 2) — 2026-07-24

Second execution batch from `documentation/performance-improvement-plan.md` (items P0.3, P0.4, P0.5).
Where Batch 1 fixed image memory, this batch removes redundant CPU work: expensive derived data
(SwiftData relationship faults + `Calendar` math) that was recomputed many times per render.

## Changes

### P0.3 — Memoize `CareTask` derivations + Schwartzian sort
- `Models/TaskListPresentation.swift`: introduced `DayBoundaries` (day thresholds computed once per
  call instead of inside `sectionKey`/`matches` per task and twice per sort comparison) and a
  `DecoratedTask` snapshot (`activeDueDate`, `lastCompletionDate`, `isOverdue`, `status`,
  `prioritySortOrder`, `title` captured once). Filtering, grouping, sorting, and counting now run
  over the snapshots. `taskCounts` decorates once and counts all five filters in a single pass
  (was five full `filteredTasks` passes, each recomputing every task's `activeDueDate`).
- `Models/HomeRoutineStatusPresentation.swift`: `rows` decorates each task once
  (`activeDueDate`/`sortPriority`/`lastCompletionDate`) and sorts + builds rows from the snapshot,
  instead of recomputing `sortPriority` twice per comparison and `activeDueDate` again per row.
- `activeDueDate` is the hot value — it scans active schedules and does Calendar math on each access.
  Public APIs and behavior are unchanged (verified by the presentation test suites).

### P0.4 — Calendar `tasksByDate` computed once per render
- `Views/Tasks/TaskCalendarView.swift`: the month→tasks map was a computed property re-evaluated
  once per calendar cell (42×) plus several times in the header/panel — a full task × schedule ×
  ~42-day expansion each time. It is now computed once at the top of `body` and threaded into
  `monthView(tasksByDate:)` / `weekView(tasksByDate:)` / `selectedDateTasks(tasksByDate:)`; cells call
  `TaskCalendarDerivation.tasksForDate(_:in:)` against that single map.

### P0.5 — Tasks tab: single change signal + counts not recomputed on keystroke
- `Models/TaskManagementViewModel.swift`: split `updateTasks()` into `updateGroupedTasks()`
  (filter/search dependent) and `updateTaskCounts()` (task-set dependent). `searchText`/`selectedFilter`
  changes now recompute only the grouped list, not the per-filter badge counts.
- `Views/Tasks/TaskManagementView.swift`: replaced the two overlapping `onChange` handlers
  (`allCareTasks` and `allCareTasks.map(\.updatedAt)`) — which could both fire for one change and run
  the full derivation twice — with a single `onChange` on a lightweight `TaskChangeToken` signature
  (id + updatedAt per task) covering both membership and in-place edits.

### Incidental
- `Resources/Localizable.xcstrings`: removed a stray empty `""` key (an Xcode artifact) that was
  failing `LocalizationParityTests`. Unrelated to the perf work; removed so the suite is green.

## Verification
- `xcodebuildmcp` `build_sim` clean, zero warnings.
- Full `CatCareCalendarTests` unit target green (166 tests), including `TaskListPresentationTests`,
  `HomeRoutineStatusPresentationTests`, and `LocalizationParityTests`.
- `build_run_sim` launches clean on iPhone 12 / iOS 26.5.

## Notes
- These are CPU / scroll-smoothness wins (fewer redundant passes and Calendar computations), best
  observed in Instruments (Time Profiler / SwiftUI) on the Tasks and Calendar screens rather than via
  memory footprint.
