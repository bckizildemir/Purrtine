# Product Requirements Document
## CatCareCalendar

**Version:** 1.1  
**Date:** March 2026  
**Owner:** Product + Engineering  
**Status:** Living document

---

## 1. Summary

CatCareCalendar is a local-first iOS app for cat owners who need reliable reminders, fast daily task completion, and trustworthy care history. The product should feel native, calm, and highly glanceable while still supporting multi-cat households and shared-care workflows over time.

### Product Vision
Provide a modern, accessible cat-care planner that helps users remember what needs to be done, complete tasks quickly, and review past care with confidence.

### Product Principles
- Reminders must be reliable and understandable.
- Daily use must be faster than writing notes manually.
- The first-run experience should get a user to value in under 90 seconds.
- History should explain what happened without requiring spreadsheet-style effort.

---

## 2. Audience

### Primary
- Cat owners managing daily feeding, medication, litter, grooming, and health-related routines.

### Secondary
- Shared caregivers in the same household.
- Pet sitters who need simple, short-term visibility into care routines.

### Not A Current Baseline
- Veterinary-system integrations.
- Broad multi-user cloud collaboration.
- AI-driven recommendations.

These remain valid future opportunities, but they are not current engineering assumptions.

---

## 3. Success Metrics

- Day-30 retention above 70%.
- At least 60% of active users complete one or more tasks per day.
- Average weekly completed tasks per active user above 10.
- User satisfaction above 4.5/5.
- Onboarding completion to first usable dashboard above 85%.

---

## 4. Product Scope

### Core Scope
- Onboarding with first-cat setup and starter task selection.
- Cat profile management for one or many cats.
- Custom and template-based care tasks with recurring schedules.
- Local notification reminders and actionable notification flows.
- A home dashboard focused on today, overdue work, and quick actions.
- Completion history with lightweight analytics and streak-style feedback.
- Settings for notifications, display preferences, support, and debug tooling.

### Future Scope
- Export as PDF, CSV, or shareable reports.
- iCloud sync and cross-device state reconciliation.
- Expanded caregiver collaboration beyond the current local model.
- Veterinary sharing or external record integrations.
- AI or context-aware suggestions.

Future-scope items should be documented explicitly as roadmap work, not assumed in the base implementation.

---

## 5. User Stories

### Cat Management
- As a cat owner, I want to add my cats so I can manage care for multiple pets.
- As a user, I want to edit profiles and photos so the app stays useful over time.
- As a user, I want cat details to be optional when they are not essential to starting quickly.

### Task Management
- As a cat owner, I want to create recurring tasks so I do not have to recreate routine work.
- As a user, I want to assign tasks to one or more cats.
- As a user, I want task completion to be fast, but still allow notes and richer details when needed.

### Reminders
- As a busy pet owner, I want local reminders for upcoming care tasks.
- As a user, I want to control reminder timing and disable reminders where they are not helpful.
- As a user, I want actionable notifications to route me into the right part of the app.

### History
- As a cat owner, I want to know when a task was last completed.
- As a user, I want to review trends, streaks, and recent completions without reading raw logs.
- As a future user, I may want export and sharing for external care coordination.

---

## 6. Functional Requirements

### Cat Profiles
- **CAT-001:** Users can create cat profiles with at least a required name.
- **CAT-002:** Users can optionally add photos, age, breed, gender, weight, notes, and medical conditions.
- **CAT-003:** Users can edit or delete cat profiles with confirmation.
- **CAT-004:** The system supports multi-cat households.

### Tasks
- **TASK-001:** Users can create custom tasks and start from templates.
- **TASK-002:** Tasks can be assigned to one or more cats.
- **TASK-003:** Tasks support recurring scheduling, including one-time and repeating frequencies.
- **TASK-004:** Tasks can include reminder timing and priority metadata.
- **TASK-005:** Users can edit, delete, and complete tasks.
- **TASK-006:** Completion can capture timestamped notes and related cat or caregiver context where relevant.

### Notifications
- **REM-001:** The app schedules local notifications for eligible tasks.
- **REM-002:** Users can review and control notification permissions and reminder behavior.
- **REM-003:** Notification actions can deep-link into task completion or task review flows.
- **REM-004:** Overdue work is visible in-app even when notifications are disabled.

### Daily Experience
- **DAY-001:** The home surface highlights today’s work, overdue tasks, and quick task creation.
- **DAY-002:** Task creation must be reachable from core task surfaces and contextual shortcuts.
- **DAY-003:** The UI must support quick completion while still allowing more detailed completion flows for shared or multi-cat tasks.

### History
- **HIST-001:** Users can review recent completions and historical completion lists.
- **HIST-002:** The app surfaces basic statistics such as total completions and on-time rate.
- **HIST-003:** Export and external sharing remain roadmap requirements rather than current delivery assumptions.

---

## 7. UX And Accessibility Requirements

- Navigation follows modern SwiftUI patterns centered on `NavigationStack`.
- Core flows must be usable with VoiceOver, Dynamic Type, and Reduce Motion.
- Information cannot rely on color alone.
- Interactive targets must remain comfortably tappable.
- The app should feel native on iPhone first while remaining functional on iPad and in landscape.

---

## 8. Technical Baseline

### Target-State Architecture
- Native iOS app built with SwiftUI.
- SwiftData for local persistence.
- Observation-based state management using `@Observable`.
- `NavigationStack`-based routing with a shared navigation router.
- `UserNotifications` for local reminder scheduling and actions.
- Swift concurrency for asynchronous work.

### Current Workspace Notes
- The checked-in project currently reports `IPHONEOS_DEPLOYMENT_TARGET = 18.4`.
- The checked-in project currently reports `SWIFT_VERSION = 5.0`.
- Only the main app target is visible in the current project file; test targets should be added or confirmed if automated coverage becomes mandatory.

These docs should pull the project toward the target state, but implementation work must still respect actual workspace constraints until the project settings are updated.

### Persistence Model
- `Cat`
- `CareTask`
- `CareTaskSchedule`
- `CareTaskCompletion`
- `Caregiver`

### Non-Baseline Technical Assumptions
- Cloud sync is not a current dependency.
- Third-party charting is not required; if charts are added, prefer Swift Charts first.
- External services or integrations should not be introduced without an explicit product decision.

---

## 9. Quality Requirements

- App launch should feel immediate on supported devices.
- Task completion should provide near-instant feedback.
- Task and history views should remain responsive with realistic household-scale data.
- New business logic should be testable with Swift Testing.
- UI automation, when added, should use XCTest.

### Simulator Baseline
- Verification device: `iPhone 12`
- Verification OS versions: `iOS 18.5` and `iOS 26.5`, run sequentially

---

## 10. Risks And Mitigations

### Reminder Reliability
- Risk: notification state drifts from scheduled task state.
- Mitigation: keep notification scheduling centralized and re-sync on task mutations.

### Data Correctness
- Risk: orphaned or inconsistent records in SwiftData relationships.
- Mitigation: use explicit relationship rules, predictable saves, and feature-level regression coverage.

### Over-Specification In Docs
- Risk: living docs promise future features as if they are already implemented.
- Mitigation: mark roadmap work explicitly and keep the baseline tied to current product commitments.

---

## 11. Delivery Phases

### Current Modernization Track
- Align app behavior and docs with SwiftUI, SwiftData, Observation, accessibility, and local-notification best practices.
- Stabilize onboarding, tasks, cats, history, and settings as the core experience.

### Next Phase Candidates
- Stronger analytics views.
- Export and printable summaries.
- Broader caregiver collaboration.
- iCloud sync.

### Longer-Term Opportunities
- External sharing and veterinary workflows.
- Smart assistance or automation features.

---

## 12. References

- [Feature Documentation Index](./features/README.md)
- [Localization Guidelines](./LOCALIZATION_GUIDELINES.md)
- Apple Human Interface Guidelines
- SwiftUI documentation
- SwiftData documentation
- UserNotifications documentation
