# App-Wide Performance Improvement Plan

_Created 2026-07-24. Grounded in a five-dimension audit (image pipeline, SwiftData,
SwiftUI rendering, concurrency/launch, notifications/hotspots). Each item cites `file:line`._

## The lens

The Complete Task memory fix wasn't really about images — it was about **doing expensive
work repeatedly where it should be done once, at the right size and time.** Full-resolution
bitmaps were decoded on every render to fill a 40×40 circle; we made the decode happen once,
downsampled, and cached.

The audit found the *same shape* all over the app. Two systemic root causes account for almost
every High-severity finding:

- **Root cause A — produced/stored at the wrong size.** Photos are saved at their original
  pixel dimensions (no downscale-on-save), so every downstream read is expensive by construction.
- **Root cause B — recompute-in-`body`.** Expensive derived data (SwiftData relationship faults +
  `Calendar` date math) lives in computed properties read directly by SwiftUI `body`, so it re-runs
  dozens of times per render — amplified because three tabs (Home, Tasks, Assistant) stay mounted and
  all observe the same `@Query`, so one task edit re-derives all three at once.

Fixing A shrinks the cost of everything image-related; fixing B removes the bulk of redundant CPU
work across the app.

---

## Priority roadmap

Legend — Impact: ⭐⭐⭐ high / ⭐⭐ medium / ⭐ low. Effort: S/M/L.

### P0 — Do first (highest impact ÷ effort)

| # | Item | Impact | Effort |
|---|------|--------|--------|
| 1 | Downscale photos on save (image root cause) | ⭐⭐⭐ | M |
| 2 | Finish the `DownsampledImage` migration (3 missed sites) | ⭐⭐⭐ | S |
| 3 | Memoize `CareTask` derived date props + Schwartzian sort | ⭐⭐⭐ | M |
| 4 | Calendar `tasksByDate`: compute once, not ~45×/render | ⭐⭐⭐ | M |
| 5 | Tasks tab: collapse double `onChange` + single-pass counts | ⭐⭐⭐ | M |

### P1 — High value

| # | Item | Impact | Effort |
|---|------|--------|--------|
| 6 | Move Home / History / Assistant derivations out of `body` | ⭐⭐ | M |
| 7 | Query `CareTaskCompletion` directly (predicate + `fetchLimit` + `fetchCount`) | ⭐⭐ | M |
| 8 | Run photo save (decode/compress/write) off the main actor | ⭐⭐ | M |
| 9 | Notification resync: kill N+1 storm, batch, cap expansion + 64 budget | ⭐⭐ | M |

### P2 — Correctness & hygiene

| # | Item | Impact | Effort |
|---|------|--------|--------|
| 10 | Defer/measure Firebase configuration off the launch critical path | ⭐⭐ | M |
| 11 | `@MainActor` on 2 `@Observable` singletons; drop redundant `MainActor.run`; drop per-render `fileExists` | ⭐ | S |
| 12 | Gate notification `print()` behind `#if DEBUG`; delete dead code | ⭐ | S |
| 13 | Add `#Index` to models (after predicates land) | ⭐ | S |

### P3 — Minor cleanups

| # | Item | Impact | Effort |
|---|------|--------|--------|
| 14 | `UIScreen.main.bounds` → size class in `CatsTabView` | ⭐ | S |
| 15 | `GeometryReader` → `containerRelativeFrame` in `PageIndicatorView` | ⭐ | S |
| 16 | `localizedStandardContains` in History search; shared `Calendar` per cell | ⭐ | S |

---

## Details

### P0.1 — Downscale photos on save (root cause A)
**Where:** `Utilities/PhotoManager.swift:106` (`compressImage`), duplicated in
`Models/TaskManagementViewModel.swift:344`, `Models/TaskAssistantViewModel.swift:725`,
`Views/AddCaregiverView.swift:201`.
**Cost:** `compressImage` only lowers JPEG *quality*, never pixel dimensions — a 3024×4032 camera
photo stays 3024×4032 (~1MB file, ~48MB decoded). It then re-encodes the full-res bitmap in a linear
`while` loop up to ~9 times. Four copy-pasted implementations. `saveUIImage` (`:48`) also encodes at
0.8 then hands to `savePhoto` which `UIImage(data:)`-decodes it back and re-compresses (encode → decode → re-encode).
**Fix:** Add one `PhotoManager.downsampledData(from:maxPixelSize:quality:)` that downsamples via
ImageIO (reuse `DownsampledImageLoader.downsample`) then encodes **once**. Cap longest edge:
cats/task photos ~1536–2048px, avatars ~512px. Route all four save paths through it and delete the
duplicates. This makes every downstream decode cheap too.

### P0.2 — Finish the `DownsampledImage` migration
Three thumbnail sites were missed by the Complete Task change and still full-res decode:
- **`Views/Cat/EnhancedCatCardView.swift:77` & `:85`** — the My Cats grid card (⭐⭐⭐, scrolling collection, multiple on screen). Highest priority of the three. Flagged independently by the image, rendering, and concurrency audits.
- **`Views/Tasks/TaskConfigurationComponents.swift:376`** — `CaregiverSelectionRow` 40×40 avatar (siblings at `:69`/`:195` already migrated).
- **`Views/Cat/PhotoPickerSection.swift:34-36` & `:41`** — the just-picked / captured branch decodes full-res `Data` in `body` for a 140-pt circle (existing-cat branch at `:48` is fine).

**Fix:** Swap to `DownsampledImage(url:targetPointSize:)`, mirroring `CatDetailView.swift:150`. For
picked/captured images, downsample the retained representation once at pick/capture time.
_(Leave `PhotoSheetView` full-screen viewer `CatDetailView.swift:542/550` on `AsyncImage` for now — it
legitimately wants detail and uses `.fit`; optionally cap it at screen-pixel size in P2.)_

### P0.3 — Memoize `CareTask` derived date props + Schwartzian sort (root cause B amplifier)
**Where:** `Models/CareTask.swift:313-362` (`activeSchedules`, `activeSchedule`, `activeDueDate`,
`isOverdue`, `lastCompletion`, `completionCount`, `assignedCatNames`) and `effectiveDueDate:428-444`;
comparators in `Models/TaskListPresentation.swift:186-206` and `Models/HomeRoutineStatusPresentation.swift:69-94`.
**Cost:** None are stored. `activeDueDate` allocates a filtered array, `.min` over `effectiveDueDate`
(which does `Calendar` component math), recomputed for **both operands on every comparison** during
sort — O(n log n × schedules) redundant Calendar math per pass, and every P0.4/P0.5/P1.6 derivation
calls them repeatedly.
**Fix:** Build a lightweight per-task value snapshot once per data change
(`id, activeDueDate, sectionKey, lastCompletionDate, isOverdue, priority, title, catNames`) and
filter/sort/group/count over the plain structs (Schwartzian transform: compute each sort key once).
Consider a denormalized stored `nextDueDate` updated on write to enable DB-side sorting + indexing.

### P0.4 — Calendar `tasksByDate`: compute once
**Where:** `Views/Tasks/TaskCalendarView.swift:16-19` (computed, uncached) →
`Models/TaskCalendarPresentation.swift:6-38`.
**Cost:** `tasksByDate` iterates every task × active schedule × ~42-day occurrence expansion × every
completion. It is read once per `tasksForDate(date)` — called per cell (42 cells) — plus a separate
full derivation in `tasksForCurrentMonth` (`:376`) for the header and 2–3 more in the selected-date
panel. **≈45 full-month rebuilds per body render**, re-triggered on every day tap and month change.
**Fix:** Compute the `[Date: (pending, completed)]` map **once** per (`currentMonth`/`showingWeekView`,
`tasks`) into `@State` (refreshed via 2-param `.onChange`), and index into it in the `ForEach`. Derive
the header count from the same map. Partition pending/completed in one pass instead of two
`hasCompletion` scans per cell.

### P0.5 — Tasks tab: collapse double `onChange` + single-pass counts
**Where:** `Views/Tasks/TaskManagementView.swift:71-76`, `Models/TaskManagementViewModel.swift:63-72`,
`Models/TaskListPresentation.swift:95-109`.
**Cost:** `updateTasks()` runs `groupedSections` (full filter+sort+group) **and** `taskCounts`, which
calls `filteredTasks` once per `CareTaskFilter` = **5 more passes**. The view registers *both*
`.onChange(of: allCareTasks)` and `.onChange(of: allCareTasks.map(\.updatedAt))`, so a task change
fires the whole thing **twice (~10–12 passes)**; `searchText` `didSet` re-runs the 5 search-independent
counts on every keystroke; `.map(\.updatedAt)` allocates a `[Date]` every render.
**Fix:** Collapse to one `onChange` keyed on a lightweight signature; compute all 5 counts in a single
classification pass; recompute counts only when tasks change, not on `searchText`.

### P1.6 — Move derivations out of `body`
Same recompute-in-`body` pattern, medium frequency:
- **`Views/HomePageView.swift:20-26`** — `currentTaskSections` (read twice, `:142` & `:156`) and
  `routineStatusRows` re-derive on every sheet toggle (7 `@State` bools) and cross-tab data change.
- **`Views/HistoryView.swift:42-63`** — `scopedCompletions`/`filteredCompletions`/`presentationState`
  re-filter per render; `presentationState` filters a second time internally (`HistoryPresentation.swift:44`).
- **`Views/Tasks/TaskAssistantView.swift:15,41-46`** — `quickActionChips` built in `body`; two
  `onChange` observers each allocate an array.
**Fix:** Cache into `@State`/`@Observable` view-model state updated via a single change-driven
`onChange`; reuse the P0.3 snapshot.

### P1.7 — Query `CareTaskCompletion` directly
**Where:** `Views/HistoryView.swift:20-31,60-63`, `Views/SettingsView.swift:31-38`.
**Cost:** History does `allTasks.flatMap(\.completions)` (faults every task's completions), scoped view
loads all and filters in Swift (faults `completion.task` per element), and `SettingsView.weeklyCompletionCount`
flatMaps **all** completions on **every body render** for one number. `CareTaskCompletion` grows
unbounded over the app's life, so this degrades monotonically.
**Fix:** `@Query`/`FetchDescriptor` on `CareTaskCompletion` with
`SortDescriptor(\.completedAt, .reverse)`, a `#Predicate` (scoped task id; `completedAt >= startOfWeek`),
`fetchLimit`, and `relationshipKeyPathsForPrefetching = [\.task, \.cats]`. Use
`ModelContext.fetchCount(...)` for the Settings number.

### P1.8 — Photo save off the main actor
**Where:** `Views/Cat/CatFormView.swift:475/477` & `:534/536` (save runs synchronously from the Save
button), `Utilities/OnboardingDataBuilder.swift:7`.
**Cost:** Decode 12MP + up-to-9× recompress + disk write on the main actor → hundreds of ms hang on Save.
**Fix:** `await Task.detached { PhotoManager.shared.savePhoto(...) }.value`; keep only the SwiftData
mutation on main; show the existing `isLoading` state. (Compounds with P0.1, which cuts the work itself.)

### P1.9 — Notification resync: storm, expansion, budget
**Where:** `Utilities/NotificationManager.swift:289-302` (resync), `:406-415` (weekly customDays),
`:503-530` (cancels), `Utilities/NotificationResyncCoordinator.swift:24-49`.
**Cost:** Resync calls `cancelAllCareTaskNotifications` then loops per task calling
`scheduleCareTaskNotifications` → each calls `cancelCareTaskNotifications(forTaskId:)` = **another full
`pendingNotificationRequests()` round-trip per task** (pure waste, everything was already cleared).
Fires on every notification-settings toggle. Weekly-with-custom-days has **no count cap** (up to 12×7=84
triggers), and there's **no global 64-pending budget** (iOS silently drops the rest → missed reminders).
**Fix:** Add a schedule-without-recancel path for resync; fetch pending once, batch removals/adds; add
the missing `dates.count` guard to the customDays branch; enforce a global soonest-first budget (~60).
Do the fetch/build on a background `ModelContext`.

### P2.10 — Firebase off the launch critical path
**Where:** `CatCareCalendarApp.swift:15` → `Utilities/FirebaseBootstrapper.swift:15-25`.
**Cost:** `FirebaseApp.configure()` + AppCheck read `GoogleService-Info.plist` and start components
synchronously in `App.init`, before the first frame — a fixed cold-launch tax. _(Note: Firebase is now a
dependency, powering the task-assistant cloud tier; this reconciles against CLAUDE.md's "no third-party
dependencies" line, which is now stale.)_
**Fix:** Add an `os_signpost` to measure its launch contribution first; if material, defer configuration
(and the anonymous sign-in it gates) until just before the assistant cloud tier is first used.

### P2.11 — Actor hygiene
- Add `@MainActor` to `Utilities/NavigationRouter.swift:5` and `Utilities/OnboardingManager.swift:4`
  (`@Observable` classes; no project-wide default isolation is set).
- Drop redundant `await MainActor.run { }` wrappers inside view-spawned `Task {}` (already on main):
  `TaskCompletionView.swift:386/400`, `CatFormView.swift:416`, `NotificationSettingsView.swift:164`,
  `AddCaregiverView.swift:140/145`, `SettingsDebugViews.swift:189/198/210` — and move the `UIImage(data:)`
  decode at `TaskCompletionView.swift:380` into `Task.detached`.
- Drop the per-render `FileManager.fileExists` stat in `PhotoManager.getPhotoURL`/`loadPhoto`
  (`:64`,`:77`) for the `DownsampledImage` path — the loader already handles missing files.

### P2.12 — Logging & dead code
- Gate `print()` in `Utilities/NotificationManager.swift:230,299,499,514,529,669` behind `#if DEBUG`
  (this is the "Cancelled N notifications" spam visible in the memory screenshots).
- Delete unused: `PhotoManager.generateThumbnail`/`loadPhoto` (`:120`,`:57`),
  `CareTask.timeAgoText` (legacy `RelativeDateTimeFormatter`, `:546`).
- **Needs a product decision:** `CareTask.photoURLs` (task-completion proof photos) is *written* by both
  view models' `savePhotosToDocuments` but appears to be **never read/displayed** — dead storage produced
  at full-encode cost. Verify, then either wire up display (with `DownsampledImage`) or remove the save.

### P2.13 — Indexes
Once predicates land (P0.5/P1.7), add `#Index<CareTaskCompletion>([\.completedAt],[\.completedForDate])`,
`#Index<CareTaskSchedule>([\.scheduledDate],[\.isActive])`, `#Index<CareTask>([\.status])`
(store is local/non-CloudKit, so `#Index` is available).

### P3 — Minor
- `Views/Cat/CatsTabView.swift:12` — `UIScreen.main.bounds` → size class / `containerRelativeFrame`.
- `Views/Onboarding/PageIndicatorView.swift:16` — `GeometryReader` → `containerRelativeFrame`/`visualEffect`.
- History search `.lowercased().contains` → `localizedStandardContains`; pass a shared `Calendar` into
  `CalendarDayCell`/`CalendarWeekCell` instead of `Calendar.current` per cell.

---

## How we'll measure (per phase)

Follow the same verify-it-for-real approach we used on the Complete Task fix:

- **Memory:** `vmmap --summary <pid> | grep "Physical footprint"` (pid via
  `pgrep -f "CatCareCalendar.app/CatCareCalendar"`) before/after — for the My Cats grid (P0.2) and
  photo-heavy flows.
- **CPU / render:** Instruments **Time Profiler** + **SwiftUI** template on the Tasks and Calendar
  screens; wrap the big derivations and the launch path in `os_signpost` to get hard numbers, and watch
  for view-body hitches (target 0 dropped frames scrolling Tasks/Calendar).
- **Launch:** Instruments **App Launch** template (P2.10) — cold-start time before/after.
- **Main-thread hangs:** confirm the Save-button hang disappears after P1.8 (Hangs instrument).
- **UI state:** `xcodebuildmcp` `screenshot` / `snapshot_ui` to confirm each change is visually intact
  (this is now the project default per CLAUDE.md).

Regression guard: run the unit suite + `LocalizationParityTests`, and the sequential UI tests on iOS
18.5 and 26.5, after each phase.

---

## Suggested sequencing

1. **Batch 1 (image):** P0.1 + P0.2 + P1.8 — one coherent PR; ship the root-cause image fix and finish
   the migration. Measurable memory + Save-hang win.
2. **Batch 2 (derivation core):** P0.3 → then P0.4 + P0.5 build on the snapshot. Biggest CPU win.
3. **Batch 3 (data/derivation spread):** P1.6 + P1.7 (+ P2.13 indexes).
4. **Batch 4 (notifications + launch + hygiene):** P1.9 + P2.10 + P2.11 + P2.12.
5. **Batch 5:** P3 cleanups, opportunistically.
