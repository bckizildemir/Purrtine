---
paths:
  - "PurrtineTests/**"
  - "PurrtineUITests/**"
---

# Testing

- Swift Testing (not XCTest) for unit/integration suites; XCTest reserved for `PurrtineUITests`.
- `PurrtineTests/TestSupport/` provides `TestModelContainerFactory`, `FakeUserNotificationCenterClient`, `NotificationSchedulerSpy`, `FakeTaskAssistantCloudInterpreter`, and `SchemaBaselineHarness` — use these instead of real persistence, notification, or network state.
- `PurrtineTests/Models/SchemaBaselineTests.swift` pins the V1 store layout with a recorded fingerprint. If a model change makes it fail, add a schema version; do not re-record the fingerprint to make the test pass.
- `DebugDataService` seeds sample data for previews and debug builds.
- Avoid arbitrary sleeps in async tests; prefer confirmations/deterministic mocks.

