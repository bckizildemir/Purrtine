# SwiftUI Refactor Plan

Last updated: 2026-03-29
Status: In Progress
Owner: Codex

## Intent
- Refactor incrementally, not as a redesign.
- Preserve current screen entry points and user-facing flows during the first pass.
- Prioritize task composition, shared state isolation, and navigation cleanup before broad style cleanup.

## Working Rules
- Keep `TaskAddView(template:titlePlaceholder:)` and `TaskEditView(task:)` stable while shared task-composer logic moves underneath them.
- Avoid touching files with unrelated in-flight edits unless the change is required for correctness.
- Prefer self-contained slices that can be built and smoke-tested independently.

## Progress Snapshot
| Area | Status | Notes |
| --- | --- | --- |
| Shared task-composer layer | Planned | Introduce `TaskComposerDraft`, `TaskComposerMode`, and `TaskComposerViewModel`, then migrate add/edit flows behind stable wrappers. |
| Task configuration components cleanup | In Progress | Task list/search derivation has been extracted, and the repo no longer contains task-row `onTapGesture()` handlers or `Binding(get:set:)` patterns; component splitting and legacy type removal are still pending. |
| Shared state + concurrency cleanup | In Progress | `TaskManagementViewModel` is now `@MainActor`; task completion delegates through `TaskActionService`; router, haptics, and notification manager environment access now uses `@Entry`; touched shared services no longer use `DispatchQueue.main`. |
| Navigation + presentation cleanup | In Progress | Task management create/edit/complete presentation now uses item-driven sheet state, including dated completion requests from the calendar; remaining screens still need the same treatment. |
| API/accessibility/performance sweep | Planned | Apply only after composition and navigation debt are reduced. |
| Test target + regression coverage | Planned | Add `CatCareCalendarTests` Swift Testing target before broader logic moves. |

## Phase Breakdown
### Phase 1: Shared Task Composer
- [ ] Add `TaskComposerDraft`.
- [ ] Add `TaskComposerMode`.
- [ ] Add `@MainActor TaskComposerViewModel`.
- [ ] Move validation out of `TaskAddView` and `TaskEditView`.
- [ ] Move repeat/reminder/date summary logic out of `TaskAddView` and `TaskEditView`.
- [ ] Move create/update persistence and notification scheduling behind a shared action layer.
- [ ] Keep `TaskAddView` and `TaskEditView` as thin wrappers.

### Phase 2: Task Configuration Cleanup
- [ ] Split active task configuration UI into focused component files.
- [ ] Confirm dead references and remove unused legacy picker/sheet types.
- [x] Replace row `onTapGesture()` handlers with `Button`s.
- [x] Replace `Binding(get:set:)` patterns where direct bindings plus `onChange` are sufficient.

### Phase 3: Shared State and Environment
- [ ] Mark shared UI state owners `@MainActor` where the isolation boundary is safe.
- [x] Remove `DispatchQueue.main*` usage from the shared UI infrastructure touched in this refactor.
- [x] Migrate router, haptics, and notification manager environment access to `@Entry`.

### Phase 4: Navigation and Presentation
- [ ] Move list-driven navigation to `NavigationLink(value:)` plus `navigationDestination`.
- [ ] Replace multi-boolean sheet state with enum/item-driven presentation on high-traffic screens.
- [ ] Update deprecated toolbar placements to `.topBarLeading` and `.topBarTrailing`.

### Phase 5: API, Accessibility, and Performance Sweep
- [ ] Extract large subviews into dedicated files where it improves reuse or readability.
- [ ] Replace `foregroundColor()` with `foregroundStyle()` where appropriate.
- [ ] Replace `cornerRadius()` with shape-based clipping/background APIs where appropriate.
- [ ] Use localized search helpers and `Text(..., format:)` where it improves correctness.
- [ ] Remove production-path debug `print`s from touched code.
- [ ] Replace tappable images with labeled buttons.

### Phase 6: Tests and Verification
- [ ] Create `CatCareCalendarTests` with Swift Testing.
- [ ] Add task-composer validation coverage.
- [ ] Add repeat-summary and date-label coverage.
- [ ] Add task filtering and localized search coverage.
- [ ] Add router deep-link coverage.
- [ ] Add notification scheduling delegation coverage.
- [x] Build on `iPhone 16e` with iOS `18.5`.
- [ ] Run manual smoke checks for home quick actions, task add/edit, cat detail edit, settings navigation, and history navigation.

## Open Questions
- Can `TaskComposerViewModel` own all add/edit state in the first pass, or should feeding-template custom fields remain local until the second pass?
- Should task creation/update live in `TaskActionService`, or should a dedicated composer action service own create/update while `TaskActionService` stays focused on completion/postpone flows?
- Should onboarding-related task setup move onto the same composer primitives in this refactor, or after the first add/edit migration lands?

## Acceptance Criteria
- Preserve existing UX, copy, and dark-theme styling unless a change is required for correctness or accessibility.
- Keep routing behavior intact while internal registration and presentation models change.
- Ensure each landed slice builds independently on `iPhone 16e` iOS `18.5`.

## Change Log
### 2026-03-29
- Created the plan document and converted it into an updateable working tracker.
- Landed the first contained slice on shared UI state, environment plumbing, and concurrency cleanup.
- Reworked task management add/edit/complete presentation to item-driven sheet state and removed dead sheet booleans.
- Extracted task list/search derivation into shared task list presentation types and routed task completion through `TaskActionService`.
- Confirmed the task views no longer use `onTapGesture()` rows or `Binding(get:set:)` patterns.
- Verified the project builds on `iPhone 16e` with iOS `18.5` and launches on the simulator without an immediate runtime failure.

## Update Template
When this plan changes, update:
1. `Last updated`
2. `Status`
3. `Progress Snapshot`
4. Relevant phase checklist items
5. `Change Log`
