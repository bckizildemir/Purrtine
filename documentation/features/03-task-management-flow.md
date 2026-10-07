# Task Management Flow Documentation
**CatCareCalendar - Task creation, browsing, editing, and completion**

---

## Goal

Task management is the core of the product. Users should be able to create, schedule, review, and complete care work quickly while still supporting richer detail when a task needs it.

---

## Entry Points

- Tasks tab.
- Home dashboard quick actions.
- Cat detail screens.
- History and empty-state prompts that route back to task creation.
- Notification taps and actions routed through the app router.

---

## Core Flow

### Browse Tasks
- Support list and calendar presentations.
- Provide clear filters for common task states such as today, overdue, upcoming, and completed visibility.
- Keep search and filters lightweight and fast.
- Calendar presentation should derive future visibility from active schedules and completed-day visibility from `CareTaskCompletion.completedForDate`, so completed one-time work still appears on the day it was done without duplicating future recurring items.

### Create Task
- Support both template-driven and custom task creation.
- Task creation should be reachable from toolbars or contextual actions, not from a platform-specific floating action button assumption.
- Required inputs should stay minimal:
  - title
  - at least one target cat or an explicit all-cats intention
  - scheduling information

### Configure Schedule
- Support one-time and recurring schedules.
- The current domain model supports:
  - `once`
  - `daily`
  - `weekly`
  - `biweekly`
  - `monthly`
  - `custom`
- Reminder timing should be optional and tied to the schedule, not stored as unrelated UI state.

### Edit Task
- Let users adjust the task, schedule, assigned cats, and reminder settings.
- Keep destructive actions explicit and confirmed.
- For recurring tasks, editing rules must be consistent and understandable.

### Complete Task
- Single-cat tasks should support very fast completion.
- Multi-cat or shared-care tasks may require a richer completion flow that captures selected cats, caregiver, notes, photos, or the completed-for date.
- Completion must update both persistence and reminder state predictably.
- Recurring completion should advance from the effective completed occurrence date rather than from a stale prior schedule date.

### Bulk Editing
- If bulk task editing remains part of the product, keep it constrained to high-value actions such as delete, reassignment, or schedule changes.
- Avoid speculative bulk-export or enterprise-style tooling unless the product explicitly needs it.

---

## Domain Model

- `CareTask`
- `CareTaskSchedule`
- `CareTaskCompletion`
- `Caregiver`

These models define the technical baseline for task documentation. New task features should extend them intentionally rather than inventing parallel state models.

---

## Technical Notes

- Task state is persisted in SwiftData.
- Local reminders are scheduled through `UserNotifications`.
- Notification actions must route through the app’s navigation and task-action layers, not ad-hoc per-screen logic.
- `@Query` belongs in SwiftUI views; services and helpers should work through `ModelContext`.
- Task presentation mode should respect user settings where a default list vs. calendar mode is offered.

---

## UX And Accessibility

- Today and overdue work should be obvious without overwhelming the rest of the list.
- Swipe actions should complement the main UI, not be the only way to complete critical tasks.
- Task rows and completion controls must be readable with VoiceOver and large text.
- Color can support priority and status, but status must also be clear in text or iconography.

---

## Future-State Notes

- Data export and printable summaries.
- Cross-device sync.
- More advanced scheduling intelligence or recommendations.
- Broader caregiver collaboration and external sharing.
