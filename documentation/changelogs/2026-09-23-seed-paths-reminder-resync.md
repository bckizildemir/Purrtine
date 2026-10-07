# 2026-09-23 — Onboarding and seed paths resync reminders (#16 follow-up)

Follow-up to the care-task mutation seam (`2026-09-23-care-task-writer.md`, PR #75). That change
left the seeding paths committing tasks without scheduling anything, so the starter tasks created
by onboarding had no reminders until something else rescheduled them.

## What changed

- **`OnboardingDataBuilder`** takes a `CareTaskWriting` in its initializer. It inserts the cat and
  every starter task, then saves each task through the writer: the first `save` commits them all in
  one go, so a failed commit leaves no cat without its tasks, and each task's reminders are scheduled
  as part of its write. `createCatAndTasks` is now `async`. If some reminders could not be scheduled
  it keeps going, then throws one `CareTaskRemindersOutOfSyncError` naming every stale task; a
  failure in a later write, after the one commit, counts as stale too. If the commit itself fails,
  the cat and every task are taken back out of the context, so a later save cannot commit them.
- **`OnboardingView`** reads the writer from `@Environment(\.careTaskWriter)`. "Saved, reminders
  stale" is logged and onboarding completes — it is not an onboarding failure and does not block
  the user.
- **`NotificationPermissionView`** asks for permission through `NotificationManager.requestPermission()`
  instead of calling `UNUserNotificationCenter` directly. A grant during onboarding now fires
  `onSettingsChanged` and the store-wide resync, like a grant from Settings. The screen looks and
  behaves the same, and so does the system permission prompt. The request now also includes
  `.providesAppNotificationSettings`, the same options the Settings screen already asks for; that
  option only adds an in-app settings link to the app's page in the system Settings app.
- **`OnboardingView`** ignores a second tap on the final button while the save runs. The finish step
  became `async`, which opened a window where a second tap could create a second cat.
- **`DebugDataService`** (DEBUG only) calls `refreshReminders` after each commit: sample data and
  overdue tasks get reminders, and clearing sample data cancels the reminders of deleted tasks. Its
  methods are `async` and return only after the resync; the developer-tools buttons in
  `SettingsDebugViews.swift` pass the injected `careTaskWriter` and await them in a `Task`. A failed
  save is now logged instead of silently dropped, and skips the resync.

## Left as is, on purpose

- **`PreviewData`** — previews must not schedule.
- **`AppLaunchBootstrapper.seedInitialDataIfNeeded`** — runs only under `-ui-testing`, where
  `disablesRealNotifications` turns every scheduler call into a no-op, and runs from the
  synchronous `App.init`. A resync would change nothing a user can see but would move launch timing
  and interact with `-fail-notification-schedule`.

## Tests

`OnboardingDataBuilderTests` drives the real `CareTaskWriter` over `NotificationSchedulerSpy`:
every starter task's active schedule is handed to the scheduler, an empty selection schedules
nothing, a failed schedule keeps the cat and tasks and names every stale task, and the cat and all
tasks are pending in the context when the first write runs, so one commit covers them all.
