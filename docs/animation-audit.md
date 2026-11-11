# Purrtine animation audit

- Source: `origin/main` @ `f1a8020` (read via `git grep` / `git show`; no repo file touched). Source folder is still `CatCareCalendar/`; all paths below are relative to `CatCareCalendar/`.
- Skill: improve-animations (Emil Kowalski, web-first). Timing/easing/restraint rules are translated to SwiftUI. Swift skills win on API choice. Min target iOS 18.4 (so `.smooth/.snappy/.bouncy`, `Animation.timingCurve`, `PhaseAnimator`, `KeyframeAnimator`, `sensoryFeedback`, `symbolEffect`, `contentTransition(.numericText())`, `Transition` protocol are all available; Liquid Glass `.interactive()` is iOS 26 only and already has a legacy branch).
- Brief: "sweet, minimal". Everything below is judged against that: short, quiet, spring-based with near-zero bounce, bounce/delight only in rare moments.
- Caveat: this is a code-only audit. Feel (spring bounce, crossfade double-exposure) cannot be judged from source; each plan has a feel-check step. Line numbers are for `f1a8020`; executors must STOP on drift.

## 1. Recon

**Motion surface**: pure SwiftUI, no motion library, no Lottie/Rive. About 60 `withAnimation` / `.animation(_, value:)` / `.transition` sites, all hand-typed. There is no motion token file (`Style/Theme.swift` has no animation values).

**Curves in use (all hand-typed)**:
- `.easeInOut(duration: 0.3)`: ~16 sites (onboarding, TaskAdd/Edit, calendar, view-mode toggle, page indicator, time picker).
- `.easeInOut(duration: 0.2)`: calendar day select, custom-repeat picker.
- `.spring(response: 0.3, dampingFraction: 0.7)`: 8 sites (error states, calendar Month/Week). dampingFraction 0.7 is visibly bouncy, spent on colour changes.
- `.spring(response: 0.35, dampingFraction: 0.6)`: onboarding tick (very bouncy).
- `.bouncy(duration: 0.2)`: "More details" disclosure.
- `.easeOut(0.2 / 0.25 / 0.3)`: errors, chat scroll.
- `.default`: 8 stacked on the chat scroll view.

**Reduce Motion**: read in only 2 files (`Views/Onboarding/TaskSetupView.swift:11`, `Views/Tasks/TaskAssistantChatView.swift:15`). Every other animation and the two infinite loops ignore it.

**Press feedback**: none. 20+ `.buttonStyle(.plain)` sites; custom CTAs have no pressed state.

**Haptics**: a good `Haptics` protocol with a user on/off setting (`Utilities/HapticsService.swift`). Generators are created per call without `prepare()`. `sensoryFeedback` would bypass the user's toggle (see plan 007).

**Frequency map**:
- Many times/day: tab switching, Home cards, task rows and swipe complete, calendar day taps, chat bubbles.
- Occasional: add/edit task sheets, error states, view-mode toggle.
- Rare: onboarding (4 steps), notification permission, first cat, empty states.

**Personality**: a calm care app. Target: smooth, no-bounce springs for UI; one gentle bounce reserved for rare moments.

## 2. Findings (prioritized)

Severity maps: P1 = HIGH (feel-breaking / systemic), P2 = MEDIUM, P3 = LOW or additive.

| # | Pri | Category | Location | Finding | Fix summary | Plan |
|---|-----|----------|----------|---------|-------------|------|
| 1 | P1 | Cohesion | whole app (see §1) | No motion tokens; 6 different curves for the same kinds of change; bounce (0.6–0.7 damping) on colour changes | New `Style/Motion.swift` + reduce-motion helper, migrate call sites | 001, 002 |
| 2 | P1 | Physicality | `Views/Tasks/TaskAssistantChatView.swift:209` | `.transition(.opacity.combined(with: .scale))`: `.scale` is scale(0), the "appears from nothing" case | `.scale(0.8)` + opacity, anchored at bottom trailing, token animation | 003 |
| 3 | P1 | Interruptibility / A11y | `TaskAssistantChatView.swift:163-170` | 8 stacked `.animation(.default, value:)` on the ScrollView. One typed character (`draftText.isEmpty`) animates the whole scroll content; no Reduce Motion gate; curve is system-default | One token animation, gated; bubble transition made subtle | 003 |
| 4 | P1 | Easing / A11y | `Views/Onboarding/OnboardingView.swift:26-57,73-76,94` | Full-width slide (`move(.trailing)`/`move(.leading)`) + `easeInOut 0.3` on every step, ×6 copies, ignores Reduce Motion | One `Motion.screen` spring, reduce-motion = opacity only, one `advance(to:)` helper | 005 |
| 5 | P1 | Missed press feedback | `Views/Onboarding/WelcomeView.swift:42`, `Views/Cat/CatsTabView.swift:218-230`, `Views/HomePageView.swift:142,351,412`, calendar pills `Views/Tasks/TaskCalendarView.swift:97-125` | Custom-styled buttons have no pressed state; `.plain` removes it | `PressScaleButtonStyle` (scale 0.97, asymmetric) on standalone CTAs/cards only | 004 |
| 6 | P2 | Accessibility / Purpose | `Views/Tasks/TaskAssistantTypingIndicatorView.swift:16-22`; `TaskAssistantChatView.swift:324` | Infinite loops (dots `repeatForever`; mic `variableColor.iterative.reversing`) never check Reduce Motion; dots driven by `onAppear` flag + delayed `.animation` | `PhaseAnimator` dots, opacity-only pulse under Reduce Motion; `symbolEffect(..., isActive: !reduceMotion)` | 006 |
| 7 | P2 | Purpose / frequency | `ContentView.swift:99,147`; `Views/HomePageView.swift:281,286` | Haptic `.light` on every tab change (iOS never does this) and `.medium` on Home navigation taps; generators not prepared | Remove tab-change haptic, Home taps to `selection()`, `prepare()` in service | 007 |
| 8 | P2 | Cohesion / Physicality | `Views/Tasks/TaskCalendarView.swift:97-125` | Month/Week pill: two buttons, each fills own capsule with a bouncy spring; selection teleports between pills with no shared shape | `matchedGeometryEffect` capsule + `Motion.standard`; month label `contentTransition(.numericText())` is wrong for text, use `.interpolate` or a directional transition (see plan) | 008 |
| 9 | P2 | Easing & duration | `Views/Cat/AdvancedFieldsSection.swift:14` | `.bouncy(duration: 0.2)` on a form disclosure: overshoot on layout expand | `Motion.standard` (`.smooth(duration: 0.3)`) | 002 |
| 10 | P2 | Accessibility | `Views/Onboarding/TaskSetupView.swift:66,111-120` | Spring `response 0.35 / damping 0.6` (bounce ~0.4) ungated; row removal still slides under Reduce Motion | `Motion.delight` (bounce 0.2), drop move transition when reduced | 002 |
| 11 | P2 | Missed opportunity | `ContentView.swift:22-26` | Onboarding to main app is a hard cut: the single highest-emotion moment | `.animation(Motion.screen, value:)` + `.transition(.opacity)` crossfade | 005 |
| 12 | P2 | Easing & duration | `Views/Tasks/TaskAddTimeSection.swift:44-50`, `Views/Tasks/TaskEditView.swift:338-342` | Duplicated expand/collapse recipe (height 0 + clipped + opacity) with `easeInOut 0.3` (at the budget limit; ease-in-out start is slow) | `Motion.standard` (0.3 spring, no bounce, retargets mid-flight) | 002 |
| 13 | P3 | Missed opportunity | `Views/Onboarding/NotificationPermissionView.swift:26-27` | Bell does `scaleEffect(1.2)` with easeInOut when granted | `symbolEffect(.bounce, value: permissionGranted)` + success haptic already exists in service | 009 |
| 14 | P3 | Missed opportunity | `Views/Onboarding/WelcomeView.swift:11-34` | Static hero on the app's first screen | Staggered entrance (icon, title, subtitle, 60ms apart) with `Motion.delight` | 009 |
| 15 | P3 | Missed opportunity | `Views/Tasks/TaskAssistantMascotView.swift:20-39` | Mascot is perfectly still | Idle blink via `KeyframeAnimator` (eye scaleY 1 to 0.1 to 1, 140ms every 4-6 s), off under Reduce Motion | 009 |
| 16 | P3 | Missed opportunity | `Views/Tasks/TaskRowComponents.swift:153-162`, `TaskCompletionView` | Swipe-complete and the completion confirm have no visual acknowledgement beyond list removal/refresh | Checkmark `symbolEffect(.bounce)` + `Haptics.notify(.success)` on completion row | 009 |
| 17 | P3 | Cohesion | `Views/Tasks/CustomRepeatSheet.swift:114`, `TaskAddTitleSection.swift:34-37` | `move(edge: .bottom/.top)` on a 216 pt wheel and a one-line error label: travel is the element's full size, heavier than needed | `.opacity` + `.scale(0.97, anchor: .top)` for the wheel; `offset(y: -4)`+opacity for the label | 002 |
| 18 | P3 | Cohesion | `Views/Tasks/TaskAddCatsSection.swift:50,62,74`, `TaskAddView.swift:537,609` | Error state springs (damping 0.7) animate colour only; three separate `.animation` modifiers for one boolean | One `Motion.quick` (ease-out 0.2) on the container; optional 4 pt shake (keyframes) is allowed because a haptic error already fires | 002 |

Rejected / left alone (do not report again):
- `TaskAssistantChatView.swift:88,222` scroll-to-bottom `easeOut 0.25` and the composer fade-in: correct curve and short; just token-ised in 002. They already honour Reduce Motion.
- Calendar day selection `easeInOut 0.2` (L181, L203): short, colour-only; token only.
- `TaskCalendarView.swift:340` `withAnimation {}` on delete: system default on a list removal is fine.
- Liquid Glass `.interactive()` on cards (`TaskCardSurfaceModifier.swift:10`) already provides press behaviour on iOS 26. Plan 004 must NOT wrap those rows.
- Modals / sheets use system presentation; no custom origin needed.

## 3. Lottie / Rive (note only, not a decision)

Illustrated motion (a kitten playing with a ball of yarn on loading screens, first-cat success, empty states) cannot be done well with SwiftUI shapes. Lottie or Rive could serve later. Owner decides which, separately. Hooks that would host it:
- `Views/Tasks/TaskAssistantTypingIndicatorView.swift` (replace the three dots next to the mascot).
- `Views/Cat/CatsTabView.swift` empty state (around L218) and `Views/Tasks/TaskAssistantEmptyStateView.swift`.
- `Views/Onboarding/WelcomeView.swift` hero (L11-18) and the onboarding finish moment (plan 005).
Rules for whichever is chosen: honour `accessibilityReduceMotion` (show a still frame), pause when off-screen, no autoplay loops on high-frequency screens. Plans here deliberately keep slots simple so a future player can drop into them.

## 4. Plans

Execution order: 001 then 002 (needs 001), then 003/004/005/006/007/008 in any order (all need 001; 005 also uses the helper in 001), 009 last. Each plan is meant for an executor with zero context. Swift edits should go through `swift-writer` with the Swift skills loaded. Local tests: only suites of changed files (`Scripts/xcb.sh test --only ...`), per repo rules; CI runs the full suite. Do not run the full scheme locally.

Shared target values (from the skill's AUDIT.md, translated):

| Token | SwiftUI value | Use |
|-------|---------------|-----|
| ease-out strong | `Animation.timingCurve(0.23, 1, 0.32, 1, duration: d)` | fades, error labels, selection, tap feedback |
| ease-in-out strong | `Animation.timingCurve(0.77, 0, 0.175, 1, duration: d)` | on-screen moves that must not spring (rare) |
| spring, UI | `.smooth(duration: 0.3)` (= `spring(duration: 0.3, bounce: 0)`) | expand/collapse, toggles, reorders, view swaps |
| spring, screen | `.smooth(duration: 0.4)` | onboarding steps, root swap |
| spring, delight | `.spring(duration: 0.45, bounce: 0.2)` | rare/first-run only |
| press down | `timingCurve(0.23,1,0.32,1, duration: 0.12)` | button pressed, scale 0.97 |
| press release | `.spring(duration: 0.25, bounce: 0.15)` | asymmetric: slower, soft return |
| duration budget | UI under 0.3 s; screen-level up to 0.4 s; never `ease-in` | |

### Plan 001: Add motion tokens and the Reduce Motion helper

- Status: TODO | Commit: f1a8020 | Severity: HIGH | Category: Cohesion | Scope: 1 new file, 0 edits
- Problem: no shared motion values, no central Reduce Motion handling (see §1).
- Target: new file `Style/Motion.swift` (same folder as `Theme.swift`; look at it first and imitate its style and `enum` namespacing). Check whether the app target uses a file-system-synchronized group; if not, add the file to the target in `project.pbxproj`.

```swift
import SwiftUI

/// Shared motion values. Springs have no bounce except `delight`, which is
/// reserved for rare, first-run moments. Never use ease-in for UI.
enum Motion {
    /// Fades, error labels, selection colour. Strong ease-out.
    static let quick = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.2)
    /// Expand/collapse, toggles, view swaps. Interruptible spring, no bounce.
    static let standard = Animation.smooth(duration: 0.3)
    /// Onboarding steps and the root swap.
    static let screen = Animation.smooth(duration: 0.4)
    /// Rare moments only (first run, success).
    static let delight = Animation.spring(duration: 0.45, bounce: 0.2)
    /// Button press-in and release.
    static let pressDown = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.12)
    static let pressUp = Animation.spring(duration: 0.25, bounce: 0.15)
    /// Gentle opacity-only replacement used when Reduce Motion is on.
    static let reduced = Animation.easeOut(duration: 0.15)

    /// Use inside `withAnimation(Motion.resolve(.standard, reduceMotion: reduceMotion))`.
    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? reduced : animation
    }
}
```

- Steps: (1) create the file; (2) add a small unit test only if the repo already tests `Theme` (otherwise none); (3) build.
- Boundaries: do not change any call site in this plan; no new dependencies.
- Verification: `Scripts/xcb.sh build` succeeds (errors only; check newest log in `~/Library/Caches/xcb/<Project>/logs/` for new warnings). Done when `Motion` compiles and nothing else changed (`git diff --stat` shows one new file, plus pbxproj if needed).

### Plan 002: Migrate hand-typed animations to tokens

- Status: TODO (needs 001) | Commit: f1a8020 | Severity: HIGH | Category: Cohesion / Easing | Scope: ~12 files, one-line edits
- Rule: replace the curve only. Keep `withAnimation`/`.animation(value:)` structure. Do not touch sites owned by plans 003, 005, 006, 008 (chat, onboarding view-swap, loops, calendar pills).
- Mapping (current to target):

| File:line | Current | Target |
|-----------|---------|--------|
| `Views/Cat/AdvancedFieldsSection.swift:14` | `.bouncy(duration: 0.2)` | `Motion.standard` |
| `Views/Tasks/CustomRepeatSheet.swift:91` | `.easeInOut(duration: 0.2)` | `Motion.standard` |
| `Views/Tasks/CustomRepeatSheet.swift:114` | `.opacity.combined(with: .move(edge: .bottom))` | `.opacity.combined(with: .scale(scale: 0.97, anchor: .top))` |
| `Views/Tasks/TaskAddTimeSection.swift:50` | `.easeInOut(duration: 0.3)` | `Motion.standard` |
| `Views/Tasks/TaskEditView.swift:204,213,342,451,467` | `.easeInOut(duration: 0.3)` | `Motion.standard` |
| `Views/Tasks/TaskAddView.swift:275,318,330` | `.easeInOut(duration: 0.3)` | `Motion.standard` |
| `Views/Tasks/TaskAddView.swift:342,386,620` | `.easeOut(duration: 0.2/0.3)` | `Motion.quick` |
| `Views/Tasks/TaskAddView.swift:537,609` | `.spring(response: 0.3, dampingFraction: 0.7)` | `Motion.quick` |
| `Views/Tasks/TaskAddCatsSection.swift:50,62,74` | same spring ×3 | `Motion.quick` (optionally one `.animation(Motion.quick, value: showCatError)` on the outer container, deleting the three) |
| `Views/Tasks/TaskAddTitleSection.swift:34-37` | `.move(edge: .top)` + opacity insertion | `.opacity.combined(with: .offset(y: -4))` insertion, `.opacity` removal. Note: `.offset` is not a `Transition`; use `.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), ...)` only if an offset transition type is awkward; simplest is to keep `.move(edge: .top)` and accept it (label is one line). Skip if unsure |
| `Views/Tasks/TaskManagementView.swift:219` | `.easeInOut(duration: 0.3)` | `Motion.standard` |
| `Views/Tasks/TaskCalendarView.swift:57,85,134` | `.easeInOut(duration: 0.3)` | `Motion.standard` |
| `Views/Tasks/TaskCalendarView.swift:181,203` | `.easeInOut(duration: 0.2)` | `Motion.quick` |
| `Views/Onboarding/PageIndicatorView.swift:29` | `.easeInOut(duration: 0.3)` | `Motion.standard` |
| `Views/Onboarding/NotificationPermissionView.swift:27` | `.easeInOut(duration: 0.3)` | leave for plan 009 |
| `Views/Onboarding/TaskSetupView.swift:111` | `.spring(response: 0.35, dampingFraction: 0.6)` | `Motion.delight` |
| `Views/Onboarding/TaskSetupView.swift:66,117` | slide removal, `easeInOut(reduceMotion ? 0.15 : 0.35)` | `.transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))`; `withAnimation(Motion.resolve(.standard, reduceMotion: reduceMotion))` |
| `Views/Tasks/TaskAssistantChatView.swift:88,222` | `.easeOut(duration: 0.25)` | `Motion.quick` (keep their existing `reduceMotion` branches) |

- Reduce Motion: for every animation in a file that does not read `@Environment(\.accessibilityReduceMotion)`, add it only where the animation moves position (the expand/collapse sites in `TaskAddTimeSection`, `TaskEditView`, `AdvancedFieldsSection`, `CustomRepeatSheet`) and pass `Motion.resolve(...)`. Colour-only changes need no gate.
- Boundaries: no markup or logic change; no change to accessibility identifiers (UI tests depend on them); do not edit tests.
- Verification: build; run only the unit suites of changed files if any exist. Feel check: open Add Task, toggle Time repeatedly and fast (must retarget, never restart); expand "More details" (no overshoot); trigger the title error twice quickly. Simulator Debug > Slow Animations to confirm no ease-in start. Settings > Accessibility > Reduce Motion on: expand/collapse becomes a short fade.
- Done when: `git grep -n -E 'easeInOut\(duration|dampingFraction|\.bouncy' -- '*.swift'` returns only plan 003/005/006/008/009 sites.

### Plan 003: Chat animations (scale(0), stacked `.default`, bubble entrance)

- Status: TODO (needs 001) | Commit: f1a8020 | Severity: HIGH | Category: Physicality / Interruptibility / A11y | Scope: 1 file
- Problem, `Views/Tasks/TaskAssistantChatView.swift`:
  - L209: `.transition(.opacity.combined(with: .scale))` (scale from 0).
  - L163-170: eight `.animation(.default, value: ...)` on the ScrollView. Includes `viewModel.draftText.isEmpty` (L170), so the first/last typed character animates all content; none honour Reduce Motion.
  - L113-116: bubbles insert with `.move(edge: .bottom)` (travel equals the bubble height) + opacity.
- Target:
  1. L209: `.transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .bottomTrailing)))`.
  2. Replace the eight modifiers with the same eight triggers but one animation value, gated: at the top of the file's `messageList` extension add `private var listAnimation: Animation? { reduceMotion ? Motion.reduced : Motion.standard }` and write each as `.animation(listAnimation, value: ...)`. Keep all eight triggers (each state change must still animate) but do NOT remove or reorder them. Reasoning: behaviour change is limited to the curve; restructuring triggers belongs to a separate task.
  3. Bubble insertion (L113-116): `.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: message.role == .user ? .bottomTrailing : .bottomLeading)), removal: .opacity)`. Verify the real property name for the sender in `Models/TaskAssistantMessage.swift` before writing; if the model has no user/assistant flag, use `.bottom` anchor for both. `.scale(0.96)` is subtle, which fits "sweet, minimal".
  4. Under Reduce Motion the transitions should collapse to opacity: wrap with `reduceMotion ? .opacity : <above>` (a ternary over `AnyTransition` is fine).
- Boundaries: do not touch scrolling logic (`defaultScrollAnchor`, `scrollToBottom`, `onScrollGeometryChange`), haptics, view-model code, or accessibility ids.
- Verification: build; run the chat view's suite only (find with `git grep -l TaskAssistantChatView -- '*Tests*'`). Feel check: send 3 messages rapidly (bubbles must not stutter or restart), type and delete the first character (content must not jump), stay scrolled up and tap jump-to-latest (chevron fades/scales from 0.8, not from a point), Reduce Motion on (opacity only). Use "Slow Animations" in the simulator.
- Done when: `git grep -n 'animation(.default' -- '*.swift'` and `git grep -n 'with: .scale)'` return nothing.

### Plan 004: Press-scale button style for standalone CTAs

- Status: TODO (needs 001) | Commit: f1a8020 | Severity: HIGH | Category: Physicality | Scope: 1 new style + ~7 call sites
- Problem: the app's custom CTAs and cards have no pressed state (`.plain` removes the system dim). Sites: `Views/Onboarding/WelcomeView.swift:42` (button with default style and a custom blue capsule; check what it looks like pressed), `Views/Cat/CatsTabView.swift:218-230`, `Views/HomePageView.swift:142,351,412`, calendar pills `Views/Tasks/TaskCalendarView.swift:97-125`, `Views/Components/SheetToolbarButtons.swift:35,76`.
- Target (put in `Style/Motion.swift` or a sibling `Style/PressScaleButtonStyle.swift`):

```swift
struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(configuration.isPressed ? Motion.pressDown : Motion.pressUp,
                       value: configuration.isPressed)
    }
}
extension ButtonStyle where Self == PressScaleButtonStyle {
    static var pressScale: PressScaleButtonStyle { .init() }
}
```
  Under Reduce Motion the scale is dropped and the opacity dip stays, so feedback remains.
- Steps: apply `.buttonStyle(.pressScale)` ONLY to: Welcome continue, Cats empty-state add button, the three Home cards (L142, L351, L412; confirm each is a card/CTA, not a row inside a `List`), the Month/Week pills. Do not apply to `TaskRowComponents` rows (they sit in a glass `.interactive()` surface and swipe actions), toolbar buttons, or anything inside `Form`/`List` rows.
- Boundaries: no layout change; keep accessibility ids; `.plain` stays everywhere else.
- Verification: build; feel check on device or simulator: press and hold (scales to 0.97 in ~0.12 s), release (soft return, no wobble), drag off the button (must return). The scale should be barely noticeable; if it reads as "bouncy", reduce `pressUp` bounce to 0.
- Done when: the listed sites use `.pressScale`; the rest unchanged.

### Plan 005: Onboarding step transition and onboarding-to-app handoff

- Status: TODO (needs 001) | Commit: f1a8020 | Severity: HIGH (steps) / MEDIUM (handoff) | Category: Easing / A11y / Missed opportunity | Scope: 2 files
- Problem:
  - `Views/Onboarding/OnboardingView.swift:26,35,41,51,57,94` repeat `withAnimation(.easeInOut(duration: 0.3)) { currentStep = …; onboardingManager.currentStep = … }` six times; L73-76 slide the whole page across the full width. No Reduce Motion handling.
  - `ContentView.swift:22-26` swaps `OnboardingView` for the tab view with no animation.
- Target:
  1. In `OnboardingView` add `@Environment(\.accessibilityReduceMotion) private var reduceMotion` and one helper:
```swift
private func advance(to step: OnboardingStep) {   // use the real enum type name
    withAnimation(Motion.resolve(Motion.screen, reduceMotion: reduceMotion)) {
        currentStep = step
        onboardingManager.currentStep = step
    }
}
```
     Replace the six blocks with `advance(to: …)`; `goBack()` (L94) keeps its own target logic but uses `Motion.resolve(Motion.screen, …)`. Read the file first to get the real enum name and the back-direction logic.
  2. Transition (L73-76): reduce the travel. `.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))` becomes `reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(x: 24)) ...)`. `.offset` is not an `AnyTransition`; implement with the `Transition` protocol (iOS 17+): a tiny `private struct StepSlide: Transition` with `body(content:phase:)` using `.offset(x: phase.isIdentity ? 0 : (phase == .willAppear ? 24 : -24))` and `.opacity(phase.isIdentity ? 1 : 0)`. Result: 24 pt drift + fade instead of a full-width slide. (If the executor finds this awkward, a fallback is to keep the current move transition and only apply the token and the reduce-motion branch. Do the fallback and say so.)
  3. `ContentView.swift`: add `.animation(Motion.screen, value: onboardingManager.hasCompletedOnboarding)` on the `Group` (L21) and `.transition(.opacity)` on both branches. Confirm `onboardingManager` is `@Observable` (it is `let onboardingManager = OnboardingManager.shared`; if reading its property does not trigger view updates today, the swap already works some other way, so STOP and report instead of changing that mechanism).
- Boundaries: do not change step order, persistence, accessibility ids, or `OnboardingTaskSetupStep`. Do not change `PageIndicatorView` here (plan 002 does).
- Verification: build; run onboarding-related unit suites only. Feel check: tap through all four steps and back, fast (no stuck frames; back reverses direction), Reduce Motion on (crossfade only), finish onboarding (soft crossfade into the tab bar, no flash of the wrong background; check light and dark). Slow Animations on for the handoff.
- Done when: no `easeInOut(duration: 0.3)` remains in `OnboardingView.swift`.

### Plan 006: Gate the two infinite loops

- Status: TODO (needs 001) | Commit: f1a8020 | Severity: MEDIUM | Category: Accessibility / Purpose | Scope: 2 files
- Problem: `Views/Tasks/TaskAssistantTypingIndicatorView.swift:4,16-22,29` (three dots, `.repeatForever`, started from `onAppear`) and `Views/Tasks/TaskAssistantChatView.swift:324` (`.symbolEffect(.variableColor.iterative.reversing)` on the recording waveform). Neither reads Reduce Motion.
- Target, typing indicator: replace `@State isAnimating` + per-dot `.animation` with `PhaseAnimator` per dot, staggering with a delayed start is not available in `PhaseAnimator`, so use phase offsets via three animators with different initial phase order:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

HStack(spacing: 4) {
    ForEach(0..<3, id: \.self) { index in
        Circle()
            .fill(Color.secondary)
            .frame(width: 7, height: 7)
            .phaseAnimator(reduceMotion ? [1.0] : [0.6, 1.0, 0.6], trigger: index) { dot, scale in
                dot.scaleEffect(scale)
            } animation: { _ in .easeInOut(duration: 0.6) }
    }
}
```
  Simpler and acceptable alternative (preferred if the stagger looks wrong): keep the current implementation, add `reduceMotion` and when true render the dots static at `opacity(0.6 / 0.8 / 1.0)` (a still "…" is the standard reduced form), skipping `onAppear { isAnimating = true }`. Keep `easeInOut` here: constant looping motion is the one place the rule allows it. Do keep the 0.15 s stagger.
- Target, mic waveform: `.symbolEffect(.variableColor.iterative.reversing, isActive: !reduceMotion)`; chat view already has `reduceMotion` (L15).
- Boundaries: do not change the mascot, the indicator's accessibility label (`taskAssistantTypingIndicator`), or layout sizes.
- Verification: build; feel check: trigger the assistant (typing dots wave smoothly, no jump when the indicator is removed), start dictation, Reduce Motion on (dots static, waveform static but still red so recording state is visible).
- Done when: both sites read Reduce Motion.

### Plan 007: Trim and prepare haptics

- Status: TODO | Commit: f1a8020 | Severity: MEDIUM | Category: Purpose / frequency | Scope: 3 files
- Problem: `ContentView.swift:97-101` (and the legacy tab view near L147) fires `haptics.impact(.light)` on every tab switch (hit many times a day; Apple's own tab bar has none). `Views/HomePageView.swift:281,286` fires `.medium` for plain navigation taps (too heavy for a "sweet, minimal" feel). `Utilities/HapticsService.swift:33,44,55` makes a new generator per call without `prepare()`, adding first-hit latency.
- Target:
  1. Remove the tab-change `onChange` haptic in both tab views (keep `onChange` only if it does something else).
  2. `goTo` and `openRoutineHistory` call `haptics.selection()` (matches the chat chips' usage).
  3. In `DefaultHapticsService`, keep generators as stored properties and call `prepare()` after each use (`impact`, `notify`, `selection`), preserving the `isHapticFeedbackEnabled` guard exactly.
  4. Do NOT migrate to `.sensoryFeedback`: it ignores the user's in-app haptics toggle (`SettingsPreferences.isHapticFeedbackEnabled`). If it is ever used, route it through the same setting, e.g. `.sensoryFeedback(trigger: x) { _, _ in settings.enabled ? .selection : nil }`.
- Boundaries: leave success/error notifications (form errors, task saved) and the cat deletion haptics as they are; do not change `Haptics` protocol signatures (the dummy and test doubles conform to it).
- Verification: build; run the `HapticsService` suite if present. Feel check on a real device (simulator has no haptics): tab switching is silent, Home card taps give one soft tick, haptics off in Settings means silence.
- Done when: `git grep -n 'haptics.impact(.light)' -- ContentView.swift` returns nothing.

### Plan 008: Month/Week pill selection and calendar header

- Status: TODO (needs 001) | Commit: f1a8020 | Severity: MEDIUM | Category: Physicality / Cohesion | Scope: 1 file
- Problem: `Views/Tasks/TaskCalendarView.swift:97-125`: two buttons, each toggling its own `RoundedRectangle` fill (`Color.blue` or clear) with a bouncy spring. The selection teleports between pills.
- Target: a single `@Namespace private var pillNamespace`; the selected pill draws `Capsule().fill(Color.blue).matchedGeometryEffect(id: "calendarModePill", in: pillNamespace)` as its background; both buttons use `withAnimation(Motion.standard) { showingWeekView = … }` with a selection haptic only if the calendar already has one (do not add new haptics here). Keep the text colour animation via `.animation(Motion.quick, value: showingWeekView)` on the label. Alternative with less code and more native behaviour: replace the two buttons with `Picker(...).pickerStyle(.segmented)`; offer this to the owner as a separate decision, not part of this plan.
- Month header (L56-60 etc.): the month title currently changes with a default crossfade. Add `.contentTransition(.interpolate)` to the month `Text` and keep `Motion.standard`. Do NOT use `.numericText()` on text months (it is for digits).
- Boundaries: do not change the grid cells, week-view layout, or date logic.
- Verification: build; run the calendar suite (`git grep -l TaskCalendarView -- '*Tests*'`). Feel check: tap Month, Week, Month rapidly (the capsule glides and reverses mid-flight with no jump); month chevrons spam-tap; Reduce Motion on (capsule still moves via `Motion.resolve`, i.e. wrap the `withAnimation` in `Motion.resolve(.standard, reduceMotion:)`, since position changes must be reduced).
- Done when: no `.spring(response:` remains in this file.

### Plan 009: Delight moments (rare, first-run only; optional)

- Status: TODO (needs 001, 002) | Commit: f1a8020 | Severity: LOW | Category: Missed opportunities | Scope: 4 files. Do each sub-item as its own commit so any can be dropped.
- 9a. Notification bell, `Views/Onboarding/NotificationPermissionView.swift:23-27`: remove `.scaleEffect(permissionGranted ? 1.2 : 1.0)` and the `.animation`; add `.symbolEffect(.bounce, value: permissionGranted)` (iOS 17+; the system gates it for Reduce Motion in the symbol-effect pipeline, but verify on device).
- 9b. Welcome entrance, `Views/Onboarding/WelcomeView.swift:11-34`: add `@State private var appeared = false`; hero icon, title and subtitle each get `.opacity(appeared ? 1 : 0)` and `.scaleEffect(appeared ? 1 : 0.94)` (icon) / `.offset(y: appeared ? 0 : 6)` (texts) with `.animation(Motion.delight.delay(0.06 * Double(i)), value: appeared)` for i = 0, 1, 2. Set `appeared = true` in `.onAppear`. If Reduce Motion: `appeared` starts `true` (no entrance). Never block the Continue button (it is not part of the stagger).
- 9c. Mascot blink, `Views/Tasks/TaskAssistantMascotView.swift`: wrap `eyes` in a `KeyframeAnimator` over a `CGFloat` eye scaleY: values 1, 0.1, 1 over 0.14 s, repeated by a task `while !Task.isCancelled { try await Task.sleep(for: .seconds(Double.random(in: 4...6))); trigger += 1 }` with `.keyframeAnimator(initialValue: 1, trigger: trigger)`. Skip for `expression == .thinking` (dots already moving next to it) and when Reduce Motion is on. This mascot appears at 28 pt in the typing row too, so only blink when `diameter >= 56` (empty state).
- 9d. Completion acknowledgement, `Views/Tasks/TaskRowComponents.swift:153-162` and `TaskCompletionView`: find the point where a completion is recorded successfully (the existing `onComplete` handler in `TaskManagementView` / `TaskCalendarView.swift:335`), call `haptics.notify(.success)` if it is not there already, and add `.symbolEffect(.bounce, value: <completion count or id>)` to the checkmark in the row or confirmation. Keep it to a single bounce. This is the one frequent action in this plan, so do NOT add scale, confetti, or sound; if the haptic already exists, only add the bounce.
- Boundaries: no new dependencies (Lottie/Rive are a separate owner decision, see §3); keep accessibility ids; no looping animations outside 9c.
- Verification: build; feel check each sub-item at 10 percent speed and on a device; Reduce Motion on (9b/9c static, 9a/9d must not be jarring).

## 5. Suggested order and effort

| Order | Plan | Effort | Why first |
|-------|------|--------|-----------|
| 1 | 001 tokens | tiny | Unblocks everything |
| 2 | 003 chat | small | Core screen, one real bug (scale from 0) |
| 3 | 005 onboarding | small | First-run impression plus handoff |
| 4 | 004 press feedback | small | Felt everywhere, subtle |
| 5 | 002 migration | medium (mechanical) | Cohesion; cheap model can do it |
| 6 | 006 loops | small | Accessibility |
| 7 | 007 haptics | small | Quieter app |
| 8 | 008 calendar pills | small | Polish |
| 9 | 009 delight | medium | Optional, after owner approves taste |

Open questions for the owner: (1) is a 0.97 press scale and a 0.9 opacity dip the right amount of "sweet" or should it be quieter; (2) should the onboarding step transition stay a slide (24 pt drift) or become a pure crossfade; (3) Month/Week: keep custom pills or switch to a native segmented Picker; (4) Lottie vs Rive, later.
