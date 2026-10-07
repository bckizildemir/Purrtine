# CatCareCalendar Iterative Functionality And Test Plan

## Handoff Rule For Agents

Every agent must read this file before implementation and update it before ending work. Mark changed rows as `TODO`, `IN PROGRESS`, `DONE`, or `BLOCKED`, and add a short handoff note with the date, what changed, files touched, and tests run. A new agent should be able to continue from the next `TODO` or `BLOCKED` row without re-auditing the whole app.

## Current Audit

- App targets exist for `CatCareCalendar`, `CatCareCalendarTests`, and `CatCareCalendarUITests`.
- Verification simulators: `iPhone 12` with `iOS 18.5` and `iOS 26.5`, run sequentially.
- Existing coverage is meaningful: Swift Testing unit/integration tests cover task derivation, task actions, notification actions, launch seeding, routing, settings presentation, history presentation, search, and home routine presentation.
- Existing UI coverage uses XCTest, which is correct because Swift Testing does not support UI tests.
- Do not rewrite all tests. Preserve tests that follow the rules and add focused coverage for gaps.
- Many unit suites use plain `@Suite`; this is harmless but unnecessary unless naming or tagging. Clean it when touching those files or in a small style pass.

## Swift Testing Rules

- Unit and integration tests must use Swift Testing: `import Testing`, structs for suites, `@Test`, `#expect`, and `#require`.
- UI tests must remain XCTest-based in `CatCareCalendarUITests`.
- Do not use `XCTestCase`, `XCTAssert`, `setUp()`, or `tearDown()` in unit/integration tests.
- Tests must be isolated, repeatable, and safe under Swift Testing's parallel execution model.
- Prefer parameterized tests for repeated input/output cases.
- Use `#require` for preconditions and optional unwrapping. Use `#expect` for behavior under test.
- Avoid `#expect(!condition)` and `#require(!condition)`; write `condition == false` so macro diagnostics stay useful.
- For thrown errors, assert exact errors with `#expect(throws:)` or use `Issue.record()` when branching on enum cases.
- Use `@MainActor` for SwiftData, Observable view models, or app code that is main-actor bound.
- Use dependency injection or fakes for hidden dependencies such as `UserDefaults`, notifications, dates, photo storage, and shared singletons when needed for stable tests.
- Do not test SwiftUI views directly. Test view models, derivation helpers, services, and UI flows.

## Progress Tracker

| Area | Status | Current Coverage | Next Work |
| --- | --- | --- | --- |
| Plan and handoff process | DONE | This file is the canonical handoff tracker. | Keep this file updated after every iteration. |
| Onboarding data creation | DONE | `OnboardingDataBuilderTests` covers first-cat creation, starter tasks, schedule defaults, caregiver assignment, and blank-name no-op behavior. | Add UI coverage only if onboarding screens regress. |
| Onboarding manager persistence | DONE | `OnboardingManagerTests` covers injected defaults loading, completion persistence, and reset behavior. | Extend only if onboarding state grows beyond completion flag, step, temp cat data, and selected tasks. |
| Cat management | DONE | `CatFormDataTests` cover form derivation, UI tests cover add/edit/delete flows, and `CatDeletionServiceTests` cover exclusive-task deletion, shared-task preservation, photo cleanup reporting, and notification reschedule summaries. | Extend only if cat deletion gains more side effects, photo storage changes, or cat profile persistence moves out of SwiftData models. |
| Task list and calendar | DONE | Filtering, search, counts, grouping, calendar derivation, task creation/edit persistence, and list/calendar default preference fallback have unit coverage. UI tests cover task create/complete and edit/delete flows. | Extend only if task form persistence gains new side effects, list/calendar preference storage changes, or calendar view behavior expands beyond current derivation helpers. |
| Task completion and recurrence | DONE | `TaskActionServiceTests` cover one-time, recurring, future occurrence, end date, snooze, errors, and detailed multi-cat completion payloads with selected cats, explicit caregiver, notes, photos, and normalized completion date. | Extend only if completion side effects, recurrence rules, proof photos, or detailed completion fields change. |
| Notifications | DONE | Badge policy, settings presentation, notification coordinator, action services, and scheduling request content/date generation have coverage through fakes. | Extend only if notification payloads, trigger date generation, authorization gating, or notification-center side effects change. |
| Daily home | DONE | Routine status presentation has unit coverage, and UI smoke covers seeded today/overdue dashboard sections and routine rows. | Extend only if home dashboard navigation, grouping, quick actions, or routine status presentation changes. |
| History and analytics | DONE | Presentation state covers no tasks, no completions, task-scoped no completions, search empty, and seeded UI flows cover no tasks, no completions, and completed-history content. | Add summary metric unit tests when metric logic expands beyond current presentation state. |
| Settings | DONE | Settings shortcuts, advanced notification draft UI, default task view fallback, and durable settings preference keys/defaults have coverage. Haptics now treats an unwritten preference as enabled, matching the UI default. | Extend only when new durable settings keys are added or `NotificationManager.settings` becomes launch-persistent. |
| Navigation and deep links | DONE | Route parsing, launch state, task routes, cat detail routes, history task-scoped routes, and direct Assistant-tab routing have focused coverage. | Extend only when new route cases, URL formats, or cross-tab navigation side effects are added. |
| Task assistant | DONE | Interpreter and view-model tests cover commands, confirmation, clarification, open-task outcomes, and resumable conversation state. UI coverage exercises the welcome screen, Start/Continue navigation, Assistant suggestions, hidden focused-chat tab bar, draft preservation, clarification scrolling, and task routing. | Extend when assistant execution, navigation, session lifetime, detailed completion routing, or command types change. |
| Localization | DONE | `LocalizationParityTests` verifies English and Turkish entries in `Localizable.xcstrings` stay aligned. | Extend if more locales or resource types are added. |
| Accessibility | DONE | UI smoke covers critical screen roots and controls across home, tasks, assistant, settings, cats, and history. | Continue manual VoiceOver/Dynamic Type checks for UI-heavy changes; add targeted UI identifiers when new critical flows are introduced. |

## Baseline Test Commands

Run this before and after substantial changes:

```sh
Scripts/xcb.sh test --os 18.5
```

For a narrower iteration, run the relevant test target or single test class first, then run the full command before handoff when practical.

## Coverage Philosophy

- Cover one happy path, one boundary, and one important failure or empty state per feature area.
- Prefer service and presentation tests over direct SwiftUI view tests.
- Use UI tests only for cross-screen behavior, navigation wiring, accessibility identifiers, and critical user journeys.
- Avoid broad snapshot-style tests unless visual regressions become a recurring problem.

## Handoff Notes

- 2026-07-22: Moved Task Assistant into the four-tab shell and replaced its Tasks-sheet entry with a welcome-to-focused-chat flow. The welcome screen shows Assistant suggestions plus localized Start/Continue actions; focused chat preserves the existing assistant implementation, hides the tab bar, reveals the composer with Reduce Motion support, requests cloud consent only after entry, and retains session state across Back/Continue. Added direct Assistant routes, English/Turkish strings, conversation-state unit coverage, focused UI journeys, feature documentation, and domain glossary terms. Files touched include `ContentView`, Task Assistant views/view model, navigation/bootstrap utilities, String Catalog, assistant/router/bootstrap tests, UI tests, and documentation. Verification: iOS 18.5 and iOS 26.5 app builds and `build-for-testing` passed for app, unit, and UI targets; the iOS 26.5 welcome screen was launched and visually inspected. Focused simulator test execution was attempted twice but Xcode's runner stalled/crashed before workers materialized and produced no assertion results. SwiftLint could not start because SourceKitten failed to load `sourcekitdInProc.framework`.

- 2026-07-10: Created plan file. Extracted onboarding record creation into `OnboardingDataBuilder`, updated `OnboardingView` to call it, and added Swift Testing coverage in `OnboardingDataBuilderTests`. Tests run: focused `OnboardingDataBuilderTests` passed with 3 tests; full `xcodebuild -scheme CatCareCalendar -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test` passed with 73 Swift Testing tests and 16 UI tests, with 2 expected iOS 26 search-tab skips on iOS 18.5.
- 2026-07-10: Added `UserDefaults` injection to `OnboardingManager` and Swift Testing coverage in `OnboardingManagerTests` for persisted completion state and reset behavior. Tests run: focused `OnboardingManagerTests` passed with 3 tests; full `xcodebuild -scheme CatCareCalendar -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test` passed with 76 Swift Testing tests and 16 UI tests, with 2 expected iOS 26 search-tab skips on iOS 18.5.
- 2026-07-10: Added `CatDeletionServiceTests`, defaulted side-effect injection plus `DeletionSummary` to `CatDeletionService`, and fixed edit-form deletion navigation so `CatDetailView` dismisses before the deleted SwiftData model is invalidated. Tests run: focused `CatDeletionServiceTests` passed with 2 tests; focused `CriticalFlowsUITests/testDeletingCatPreservesSharedTaskButRemovesSoloTask` passed; full `xcodebuild -scheme CatCareCalendar -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test` passed with 78 Swift Testing tests and 16 UI tests, with 2 expected iOS 26 search-tab skips on iOS 18.5.
- 2026-07-10: Completed `Task list and calendar` plan row. Extracted task add/edit SwiftData writes into `TaskFormPersistence`, routed `TaskAddView` and `TaskEditView` through it, added `TaskFormPersistenceTests` for create/update persistence, and added `TaskViewPreference` coverage for list/calendar default fallback. Also removed unnecessary `@Suite` from the touched task view-model tests. Tests run: focused `TaskFormPersistenceTests` plus `TaskManagementViewModelTests` passed with 6 Swift Testing tests; full `xcodebuild -scheme CatCareCalendar -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test` passed with 82 Swift Testing tests and 16 UI tests, with 2 expected iOS 26 search-tab skips on iOS 18.5.
- 2026-07-10: Completed `Task completion and recurrence` plan row. Added `TaskActionServiceTests.detailedMultiCatCompletionPersistsSelectedCatsCaregiverNotesPhotosAndNormalizedDate` to cover detailed multi-cat completion payload persistence and normalized completion dates, and removed unnecessary `@Suite` from the touched service test suite. Tests run: focused `TaskActionServiceTests` passed with 8 Swift Testing tests; full `xcodebuild -scheme CatCareCalendar -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test` passed with 83 Swift Testing tests and 16 UI tests, with 2 expected iOS 26 search-tab skips on iOS 18.5.
- 2026-07-10: Completed `Notifications` plan row. Added `NotificationManagerSchedulingTests` to verify one-time urgent medication reminder content, userInfo, category, badge behavior, cancellation lookup, and daily recurring trigger dates through `FakeUserNotificationCenterClient` without real notification-center calls. Tests run: focused `NotificationManagerSchedulingTests` passed with 2 Swift Testing tests; full `xcodebuild -scheme CatCareCalendar -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test` passed with 85 Swift Testing tests and 16 UI tests, with 2 expected iOS 26 search-tab skips on iOS 18.5.
- 2026-07-10: Completed `Daily home` plan row. Added stable home dashboard accessibility identifiers and `CriticalFlowsUITests.testHomeDashboardShowsSeededTodayAndOverdueTasks` to smoke-test seeded overdue/today current tasks plus routine status rows on the home tab. Tests run: focused home UI smoke passed; full `xcodebuild -scheme CatCareCalendar -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test` ran 85 passing Swift Testing tests and 17 UI tests with 2 expected iOS 26 search-tab skips, but exited failed because `testDeletingCatPreservesSharedTaskButRemovesSoloTask` did not find `cats.view` in the full run; focused rerun of that failed UI test passed.
- 2026-07-10: Completed `History and analytics` plan row. Added `CriticalFlowsUITests.testHistoryShowsNoCompletionsStateWhenTasksExistWithoutCompletions` to cover the history empty state where seeded tasks exist but no completions have been recorded, while preserving existing no-tasks and completed-history UI coverage. Tests run: focused history no-completions UI test passed on iPhone 16 iOS 18.5. Full suite was not rerun in this iteration after the previous full run exposed a non-reproducible `testDeletingCatPreservesSharedTaskButRemovesSoloTask` UI failure that passed in focused rerun.
- 2026-07-11: Completed remaining `Settings`, `Navigation and deep links`, `Task assistant`, `Localization`, and `Accessibility` plan rows. Added `SettingsPreferences` to centralize durable settings keys/defaults and fixed haptics so an unwritten preference matches the UI default of enabled. Added Swift Testing coverage in `SettingsPreferencesTests`, `TaskAssistantViewModelTests`, `LocalizationParityTests`, and a history route case in `NavigationRouterTests`. Added assistant UI identifiers and `CriticalFlowsUITests.testCriticalAccessibilityIdentifiersArePresentAcrossMainFlows`. Tests run: focused Swift Testing set passed with 11 tests across settings preferences, task assistant view model, localization parity, and navigation router; focused accessibility UI smoke passed; full `xcodebuild -scheme CatCareCalendar -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.5' test` ran 93 passing Swift Testing tests and 19 UI tests with 2 expected iOS 26 skips, but exited failed because `testCatAddAndEditFlow` hit a keyboard-focus UI timing issue and `testDeletingCatPreservesSharedTaskButRemovesSoloTask` did not find `cats.view` in the full run. Focused rerun of both failed UI tests passed.
