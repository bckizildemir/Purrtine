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
