# 2026-09-23 — The care-task mutation seam (#16)

Every care-task write from a view, view model, or service now goes through one interface,
`CareTaskWriting`, implemented by `CareTaskWriter` in `Utilities/`.

## The guarantee

When a verb returns without throwing, the reminders for every task it touched match the store.
The order inside each verb is fixed: change the models → `save()` → build the
`NotificationScheduleInfo`s → one scheduler call.

| Verb | Covers |
| --- | --- |
| `save(_:in:)` | create, edit, duplicate |
| `delete(_:in:)` | one task |
| `complete(_:with:in:)` | a completion, including recurrence advance |
| `snooze(_:minutes:)` | a one-off reminder; writes nothing to the store |
| `refreshReminders(for:in:)` | a change outside the task: cat rename, cat delete |

A failure after the commit throws `CareTaskRemindersOutOfSyncError`: the data stands, the reminders
are stale. Every other error means nothing was saved. `CancellationError` passes through unwrapped.

## What moved

- `TaskAddView`, `TaskEditView` no longer reach `NotificationManager.shared`. They read the writer
  from `@Environment(\.careTaskWriter)`, which `CatCareCalendarApp` injects.
- `TaskManagementViewModel`, `TaskAssistantViewModel`, `NotificationActionCoordinator` take the
  writer in `init`.
- `CatDeletionService`, `CatReminderRefreshService` became instance types that take the writer.
- `TaskActionService` keeps only the completion rules and no longer saves or schedules.
  `TaskFormPersistence` no longer saves.
- `TaskNotificationScheduling.scheduleSnoozedNotification` takes a `NotificationScheduleInfo`
  instead of a `CareTask`, so no model crosses that async boundary.

## Behaviour changes a tester can see

- A completion whose reminders fail to update still reports success in the task assistant, and now
  also shows "The task was saved, but its reminders could not be set up." Before, the failure was
  only printed.
- Adding a task with its reminder switched off now also runs the resync. It has no pending
  reminder to cancel, so nothing changes for the user. Under the `-fail-notification-schedule`
  UI-test argument that save now raises the reminder alert.
- A cat rename or delete now cancels the reminders of an assigned task with no active schedule,
  instead of skipping it.
- A task delete from the task list now commits first and cancels the reminders second. Before, a
  failed cancel kept the task.

## Not changed

`OnboardingDataBuilder`, `AppLaunchBootstrapper`, `DebugDataService` and `PreviewData` still commit
seeded tasks directly and schedule nothing. `NotificationResyncCoordinator` keeps its settings-change
job.
