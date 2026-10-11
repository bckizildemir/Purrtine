---
paths:
  - "CatCareCalendarTests/**"
  - "CatCareCalendarUITests/**"
---

# Testing

- Swift Testing (not XCTest) for unit/integration suites; XCTest reserved for `CatCareCalendarUITests`.
- `CatCareCalendarTests/TestSupport/` provides `TestModelContainerFactory`, `FakeUserNotificationCenterClient`, `NotificationSchedulerSpy`, `FakeTaskAssistantCloudInterpreter`, and `SchemaBaselineHarness` — use these instead of real persistence, notification, or network state.
- `CatCareCalendarTests/Models/SchemaBaselineTests.swift` pins the V1 store layout with a recorded fingerprint. If a model change makes it fail, add a schema version; do not re-record the fingerprint to make the test pass.
- Avoid arbitrary sleeps in async tests; prefer confirmations/deterministic mocks.
- `DebugDataService` seeds sample data for previews/manual QA when needed.
- UI tests: prefer stable accessibility identifiers/labels over brittle view-hierarchy queries.

## Animations-off blind spot

Verified 2026-10-11 on `main` after #51.

- `-ui-testing` turns UIKit animations off (`AppLaunchBootstrapper.prepareProcessState`, `UIView.setAnimationsEnabled(false)`), and the failure flags (`-fail-notification-schedule`, `-fail-cat-delete-commit`) work only under `-ui-testing`. So a UI test or a manual check under `-ui-testing` never sees a race between a closing alert, sheet or view and the next presentation.
- Two real bugs hid there: #27 (PR #42: the next alert was presented in the same write that closed the previous one, and was dropped) and #31 (PR #51: the card-menu note raced the closing confirmation).
- A change that hands off between alerts, sheets, or a disappearing view gets one check with animations on: launch with `-ui-testing -keep-animations`. The flag is DEBUG-only and counts only with `-ui-testing` (`AppLaunchConfiguration.keepsAnimations`, added in #51); `CriticalFlowsUITests.launchCatDeletionFailureScenario(failureFlag:keepsAnimations:)` shows how a UI test passes it. Name that check in the PR body.
