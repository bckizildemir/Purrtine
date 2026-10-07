# CatCareCalendar Feature Documentation
**Living flow specifications for product and engineering**

---

## Purpose

These documents describe the intended user flows for CatCareCalendar. They are written as living product and technical guidance, not as a changelog and not as a promise that every future-facing idea already exists in the current repo.

### Reading Rule
- Treat each flow’s main sections as the current target product standard.
- Treat each flow’s `Future-State Notes` section as roadmap or expansion guidance.

---

## Technical Baseline

- SwiftUI application with a 4-tab shell.
- SwiftData persistence.
- Observation-based state management with `@Observable`.
- Local reminders using `UserNotifications`.
- iPhone-first experience with iPad support.
- Accessibility baseline: VoiceOver, Dynamic Type, Reduce Motion, and color-independent status communication.

### Current Workspace Notes
- The checked-in project currently targets `iOS 18.4`.
- The checked-in project currently reports `SWIFT_VERSION = 5.0`.
- App, unit-test, and UI-test targets are present in the project.

---

## Feature Index

### 1. [Onboarding Flow](01-onboarding-flow.md)
- First-run value proposition.
- Notification permission timing.
- First cat creation.
- Starter task setup.

### 2. [Cat Management Flow](02-cat-management-flow.md)
- Cat gallery and detail navigation.
- Add and edit flows.
- Multi-cat support.
- Photo and profile management.

### 3. [Task Management Flow](03-task-management-flow.md)
- List and calendar task browsing.
- Template and custom task creation.
- Editing, completion, and scheduling.
- Notification-aware task routing.

### 4. [Daily Usage Flow](04-daily-usage-flow.md)
- Home dashboard behavior.
- Today and overdue prioritization.
- Quick actions.
- Task completion from daily surfaces.

### 5. [History & Analytics Flow](05-history-analytics-flow.md)
- Completion history.
- Summary metrics.
- Lightweight analytics.
- Roadmap path for richer reporting.

### 6. [Settings Flow](06-settings-flow.md)
- Shortcuts to cats and history.
- Notification and display settings.
- Support, legal, and debug surfaces.
- Preference storage boundaries.

### 7. [Task Assistant Flow](07-task-assistant-flow.md)
- Welcome-to-chat navigation.
- Assistant suggestions and confirmation.
- Session-scoped conversation resume behavior.
- Focused composer and tab-bar visibility.

---

## Documentation Standards

- Keep product intent intact, but do not present speculative features as current implementation.
- Keep technical notes aligned with the actual app stack.
- Prefer adaptive, accessible design guidance over hard-coded visual systems.
- If charts are added later, prefer Swift Charts before external libraries.
- If exports, sync, or external integrations are discussed, label them as future-facing unless already backed by code and product approval.
