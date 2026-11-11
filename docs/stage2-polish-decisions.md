# Stage 2 polish: decisions (owner, 2026-11-11)

Stage 2 of the release plan (2026-11-07) is app polish and animation. Source audit: [animation-audit.md](animation-audit.md)
(plans 001-009, line numbers for `f1a8020`, stop on drift). This file is the owner's answers from the grilling round of
2026-11-11 and the `decision-check` edits (swift-reviewer with the Swift skills and the HIG read through sosumi). It
overrides the audit where they differ.

Prototype: branch `prototype/calendar-whiskers` (94b3ce0), throwaway. Variant A (UICalendarView) won.

## Order

1. Plan 001 motion tokens (`Style/Motion.swift`). It does not exist on main; plans 004 and 005 depend on it.
2. Surfaces: Home cards and Tasks rows lose glass (decision 11), then press feedback (decision 1).
3. Calendar (decisions 9, 10).
4. Onboarding (decision 2).
5. Whiskers cat placeholder (decisions 5-8).
6. Rest of the audit: 003 chat, 006 loops, 007 haptics, 002 migration. 009 delight only after the owner likes the feel.

## Decisions

1. **Press feedback**: `PressScaleButtonStyle`, scale 0.97 and opacity 0.9, quick down and soft up. No scale under
   Reduce Motion. Use it on standalone CTAs and cards only: Welcome continue, the Cats empty-state add button, and the
   Home cards once they are no longer glass (decision 11). Do not use it on toolbar buttons, or on rows in `List` or `Form`.
   HIG Buttons: "Always include a press state for a custom button."
2. **Onboarding steps**: a 24 pt drift plus a fade, direction-aware (back reverses). Use the built-in transitions
   `.asymmetric(insertion: .offset(x: 24*d).combined(with: .opacity), removal: .offset(x: -24*d).combined(with: .opacity))`,
   where d = +1 forward and -1 back, and fall back to `.opacity` under Reduce Motion. One `go(to:direction:)` replaces
   the 6 copies. Feel check: forward then back, fast. **Onboarding → main app: a soft crossfade** (audit plan 005
   part 3, `ContentView`).
3. **Month/Week switch**: dropped, because the week view goes (decision 9).
4. **No Lottie, no Rive.** No new animation dependency.
5. **Whiskers art style**: line art. One stroke weight, rounded caps, the app accent.
6. **Character motion**: SwiftUI shapes drawn in code, frame by frame (`PhaseAnimator` or a cancellable `.task` loop).
   A SpriteKit cat that walks and reacts to taps is an idea for later: [IDEAS.md](IDEAS.md).
7. **Cat art for now**: the code-drawn line-art cat from the prototype, as a placeholder. An illustrator may replace
   it later. It blinks every 3-4 s. Under Reduce Motion it is **still**, with no blink (HIG: reduce "automatic and
   repetitive animations, including zooming, scaling"). Its size uses `@ScaledMetric` with a cap. It is
   `.accessibilityHidden(true)`, because the text next to it carries the meaning. Its `.task` loop returns on
   cancellation (no `try?` around `Task.sleep`).
8. **Where the cat shows first**: as the image of a `ContentUnavailableView` for "no tasks on this date" and for the
   empty calendar, and in the Whiskers chat empty state. The tail sways only in the chat empty state. Below 56 pt
   (the 28 pt typing row) it does not animate. Onboarding and task-done moments wait for plan 009.
9. **Tasks → Calendar is Apple's `UICalendarView`** (`UIViewRepresentable`, `UICalendarSelectionSingleDate`),
   month only. The week view and the Month/Week pills go. Swiping between months is built in.
   - Keep: the selected-day task panel below (complete, edit, delete; more than 1 cat opens the completion sheet), the
     "Today" button (`setVisibleDateComponents(_:animated:)` plus the selection), `taskManagement.calendar`, and the
     clearance for the iOS 26 floating tab bar. The month title and arrows come from `UICalendarView`.
   - `calendar`/`locale`/`timeZone` come from the SwiftUI environment in make/update. Use the same calendar for the
     day derivation and for turning a selection into a date. Never hardcode Gregorian.
   - Reload: SwiftUI computes an Equatable `[Date: [DotState]]` for the visible month. `updateUIView` diffs it and
     reloads only the days that changed. The delegate only looks days up.
   - Track the visible month through `didChangeVisibleDateComponentsFrom`. Derive the panel from the selected date.
   - No height cap: it sits in the existing `ScrollView`. Vertical swipes on the grid must still scroll it. Run
     `CriticalFlowsUITests` 286-297.
   - `tintColor` = app accent.
   - Prototype lesson: a frame-based `UIView` of 6 pt dots renders inside `.customView`. A `UIStackView` with Auto
     Layout rendered nothing.
10. **Day dots use category color** (the same color as the circle on task rows), up to 3, with open tasks first. An
   open task is a filled dot and a done occurrence is a hollow ring of the same color, not gray. Gray is already
   "unknown category", and color alone fails color-blind users (HIG: "Convey information with more than color alone").
   Move the private `categoryColor` (`TaskRowComponents.swift` 60-72) into one shared `CareTaskCategory.tint`. Check
   dark mode with Increase Contrast. Add a unit test for the pure dots-per-day function (open/done, order, cap of 3).
11. **Home cards and Tasks rows: no glass** (owner, 2026-11-11: "that's what Apple do"). Replace
   `.glassEffect(.regular.interactive())` on the 3 Home cards (`HomePageView.swift` ~421/431/442) and the glass
   surface of the task rows with Apple's hierarchical colors: grouped background for the screen, secondary grouped
   background for a card or row, and hierarchical foreground styles (`.primary`/`.secondary`/`.tertiary`). Then the
   Home cards get the press shrink (decision 1). Glass stays only on chrome: the tab bar, toolbars, floating controls.
   Task rows keep their swipe actions and no press scale.

## Also found (fix when touching the file)

- `WelcomeView.swift` 44-47: a fixed `.font(.system(size: 17))` and `height: 50` break Dynamic Type.

https://claude.ai/code/session_01LetMoQcfT11iPmCMitx3oZ
