# 2026-09-28 — Onboarding failure prevention (#82: #83, #84, #85)

Onboarding's finish step could silently lose a caregiver's typed cat and task data: a failed
commit (full disk, store I/O) completed onboarding anyway with nothing saved and no error shown,
and a caregiver who skipped or denied notifications got no way back to reminders from Task Setup.
This closes out #82.

## What changed

- **`OnboardingTaskSetupModel`** (new, `@MainActor @Observable`) owns the Task Setup finish step:
  `finish()` saves the cat and starter tasks through the real `OnboardingDataBuilder`/`CareTaskWriter`
  seam, then completes onboarding — unless nothing was saved, in which case onboarding stays open
  with `isShowingSaveFailure` set. `retry()` re-attempts the same answers; a failed commit takes the
  cat and every task back out of the context first, so a retry cannot double-save.
  `continueWithoutSaving()` completes onboarding with nothing saved. A reminder-scheduling failure
  after a good save is not treated as a failure: it logs and asks the notification manager for one
  full resync.
- **`OnboardingTaskSetupStep`** (new) wraps `TaskSetupView` with the save-failure `.alert` (system
  alert — Dynamic Type and VoiceOver included), offering *Try again* and a destructive *Continue
  without saving*. `OnboardingView` builds the model once and routes `.taskSetup` through this step.
- **Reminder row**: `TaskSetupView` shows a row above the footer when at least one starter task is
  selected and the notification manager's authorization status does not allow reminders. Permission
  never asked (or skipped) shows *Allow Notifications*, wired to the same
  `NotificationManager.requestPermission()` the permission step uses, so a grant fires the existing
  resync. Denied shows *Open Settings*, opened through SwiftUI's `openURL` environment value with
  the iOS 16+ `UIApplication.openNotificationSettingsURLString` constant. The prompt
  (`OnboardingTaskSetupModel.reminderPrompt`) is derived from live state on every read, so it clears
  on its own once reminders are allowed — including a return from iOS Settings, since the app already
  re-checks authorization status on activation.
- Four new catalog keys under `onboarding.save_failure.*` and three under
  `onboarding.task_setup.reminder_row.*`, en and tr, no camel-case symbol collisions.
- `OnboardingDataBuilder`/`CareTaskWriter` signatures and error contracts, the unstage-on-failure
  behaviour, and the permission step itself are unchanged.

## Tests

`OnboardingTaskSetupModelTests` drives the model with the real builder, the real writer, and a real
`NotificationManager` on `FakeUserNotificationCenterClient`: a good save schedules every task's
reminder; a scheduling failure still completes and asks for one full resync; a second `finish()`
while one is running is ignored; a failed commit keeps the caregiver in onboarding with the alert
up and nothing saved; a retry after a failed commit saves exactly one cat and one set of starter
tasks; a second failed commit shows the alert again; continuing without saving completes with
nothing saved even after a later context save; the reminder prompt is parameterized over
not-determined/denied/authorized status and an empty selection, and a status change from denied to
authorized clears the prompt with no model rebuild.
