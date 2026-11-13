---
paths:
  - "Purrtine/**/*.swift"
  - "PurrtineTests/**/*.swift"
  - "PurrtineUITests/**/*.swift"
---

# Coding conventions

These conventions are binding for this repo.

- 4-space indentation, lines <120 chars where practical, one modifier per line for non-trivial view chains.
- `PascalCase` types, `camelCase` members; boolean properties read as questions (`isLoading`, `hasPhoto`, `shouldNavigateToHistory`).
- One major type per file; file name matches its primary type. `// MARK:` only when it materially aids scanability.
- Order view properties: environment, local state, bindings, stored inputs, then computed; keep helpers below `body`.
- Prefer `foregroundStyle()` over `foregroundColor()`; prefer semantic/theme colors over raw `UIColor`.
- Avoid force unwraps in UI/state-management code unless a crash is genuinely the intended behavior.
- State: `@Observable` for shared/non-trivial state, `@State` for view-owned models, `@Binding` for simple parent/child value mutation, `@Environment`/custom environment entries for app-wide dependencies. `@StateObject`/`@ObservedObject`/`@EnvironmentObject` are legacy-interop only — don't introduce them in new code.
- Don't build `Binding(get:set:)` in `body` for business-logic side effects when a model property or `onChange` is clearer; don't store the same domain state in multiple views.
- Navigation: `NavigationStack` only (never `NavigationView`), enum-based typed destinations with `navigationDestination(for:)`, route through `NavigationRouter`. `sheet(item:)` for data-dependent presentation, `sheet(isPresented:)` only for simple booleans.
- No new singletons without a clear app-wide ownership reason; prefer initializer/environment injection.
- Avoid `AnyView` and `GeometryReader` unless genuinely necessary; avoid fixed frames that break Dynamic Type.
- Mark an `@Observable` class `@MainActor` when it mutates state the UI observes. `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is now set on the app target (both Debug and Release), so the compiler grants main-actor isolation by default and the explicit `@MainActor` annotation on each of the six `@Observable` classes here (verified 2026-10-02) — `NavigationRouter`, `NotificationManager`, `OnboardingManager`, `OnboardingTaskSetupModel`, `TaskAssistantViewModel`, `TaskManagementViewModel` — restates what the compiler already enforces. Keep writing the explicit annotation on new `@Observable` classes; it documents intent and survives a future change to the project default. Do not assume isolation you did not read in the source or the project settings.
- Concurrency: `.task` for view-scoped async work over `onAppear` + manual `Task {}`; no `[weak self]` in view `.task` closures (views are value types); keep expensive work off the main actor unless it touches UI state.
- Don't swallow user-impacting failures with `print()` alone; surface actionable errors in the UI and keep debug logging secondary.
