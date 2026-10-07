# Dead-Code Deletion and Task-Row Extraction (#15) — 2026-08-06

Closes the dead-code candidates the architecture review surfaced in issue #15, then extracts the
three surviving task-configuration rows into one file per type. Net: 371 insertions against 1165
deletions across 13 files.

## Deletions

### Unreferenced task-configuration view types
- `Views/Tasks/TaskConfigurationComponents.swift`: 12 of its 15 types had no reader anywhere in the
  app, unit-test, or UI-test targets — `SectionHeader`, `CustomTextField`, `CatChip`,
  `CustomFieldView`, `CatSelectionRow`, `CatSelectionSheet`, `CaregiverSelectionSheet`,
  `DatePickerSheet`, `FrequencyPickerSheet`, `CategoryPickerSheet`, `PriorityPickerSheet`, and
  `ReminderPickerSheet`. `CatSelectionSheet` was the superseded cat picker; the forms present
  `TaskCatsSelectionView`. The picker sheets became inline menus earlier — see
  `SHEETS_TO_MENUS_CONVERSION.md`. The file's `#Preview` (which only exercised `CustomTextField`)
  went with them, and the file itself is now gone.
- `Resources/Localizable.xcstrings`: the 8 keys those types were the last reader of —
  `caregiver.selection.other_caregivers`, `caregiver.selection.title`,
  `cats.selection.breed_not_specified`, `cats.selection.no_cats_added`, `picker.category`,
  `picker.notification`, `picker.priority`, and `picker.repeat`. The catalog now holds 992 keys, each
  translated in both `en` and `tr`.

### Empty overdue-notification entry point
- `Utilities/NotificationManager.swift`: `scheduleOverdueNotification(for:)` had an empty body and no
  callers. Overdue alerts are scheduled with the next due occurrence during a resync, so the method
  had nothing to do and was never meant to gain a body.

### Uncalled task-list derivation wrappers
- `Models/TaskManagementViewModel.swift`: `filteredCareTasks(from:selectedFilter:searchText:)`,
  `getCareTaskCount(for:from:)`, and `groupCareTasksByTime(from:)` each forwarded to
  `TaskListDerivation` and had no callers. Views call `TaskListDerivation` directly.

### Unread derived values on presentation types
- `Models/HomeRoutineStatusPresentation.swift`: `Row.sortPriority` re-exported a value that only the
  sort read. The private `DecoratedTask.sortPriority` stays, because the sort still reads it.
- `Models/TaskListPresentation.swift`: `TaskListSection.totalCount` had no reader.

### Stale MARK
- `Views/Tasks/TaskConfigurationComponents.swift`: a `MARK` named `TaskDetailsConfigurationView`, a
  view no longer in the tree.

## Extraction and modernization

The three surviving types moved into one file per type, per the repo's file-naming convention:
`CaregiverSelectionRow.swift` (one caller, `TaskCompletionView`), `SimpleOptionRow.swift` (10 call
sites), and `RemindersOptionRow.swift` (4 call sites). Two new types came out of the move:

- `Views/Tasks/OptionRowLabel.swift`: the interior shared by all three rows — a tinted icon tile, a
  title, an optional subtitle, and an optional trailing value with a chevron. It carries no
  interaction, so callers wrap it in a `Button` or pass it as a `Menu` label.
- `Views/Tasks/ReminderMenuRow.swift`: the notification row of the add and edit forms, previously
  duplicated inline in both `TaskAddView` and `TaskEditView`.

The moved code was brought up to the repo standard in the process. These are visible changes, not
pure moves:

- **Theme colors replace literal colors.** `foregroundColor(.primary)` → `Theme.label`, the `.blue`
  subtitle → `Theme.link`, `.secondary` → `Theme.labelSecondary`, `Color(.systemFill)` →
  `Theme.fill`.
- **The icon tile respects Dynamic Type.** A fixed 24pt frame with `.font(.system(size: 16))` became
  `@ScaledMetric(relativeTo: .body)` with `.font(.callout)`.
- **`Button` replaces `onTapGesture`.** Every row is now reachable by VoiceOver and Voice Control.
  `SimpleOptionRow` lost its `action` closure as a result: it is presentation only, and its call
  sites either wrap it in a `Button` or pass it as a `Menu` label. Four call sites that passed an
  empty `{}` action (category, priority, caregiver, repeat) simply dropped it.
- **`clipShape(.rect(cornerRadius:))` and `.circle` replace `cornerRadius()` and `Circle()`.**
- **A force unwrap is gone.** The caregiver avatar path built its URL from
  `FileManager.default.urls(for:in:).first!`. It now uses `URL.documentsDirectory` and
  `appending(path:)`.

## Bug fixed on the way

`TaskEditView`'s reminder section put `.disabled(!enableReminder)` on the outer `Menu`, and that
modifier also disabled the `Toggle` inside the menu label. A user who turned the reminder off could
not turn it back on. `ReminderMenuRow` disables only the menu part, so the toggle stays live.

This is the same failure mode `REMINDER_TOGGLE_FIX.md` recorded for
`TaskDetailsConfigurationView` — a `Menu` wrapper swallowing its own label's toggle. That view has
since left the tree, and `TaskEditView` had inherited the pattern.

## Verification

- Every deleted symbol was verified unreferenced across the app, unit-test, and UI-test targets,
  including `#Preview` blocks, generated catalog symbols, and non-Swift files.
- Both simulator passes green per cluster and again after the extraction: **iPhone 12 / iOS 18.5**
  and **iPhone 12 / iOS 26.5**, 311 tests passed, 0 failed. One runtime at a time.
- `LocalizationParityTests` passes. No key lost its last reader, and no reader lost its key.

## Follow-ups, deliberately not here

- `cats.selection.done` is orphaned, but it was already orphaned on `main` and belongs to no cluster
  here. PR #31 removes it.
- `HomeRoutineStatusPresentation.Row.secondaryTimestampText` has one reader, in a branch
  `rows(from:)` cannot reach. Removing it needs a view change.
- The reminder-toggle fix has no regression test. The repo has no unit seam for these views, so a UI
  test is the only option.
- `RemindersOptionRow` and `ReminderMenuRow` give their `Toggle` the same accessible name as the row
  button beside it. An unlabeled toggle was worse, but VoiceOver now announces two controls with one
  name.
