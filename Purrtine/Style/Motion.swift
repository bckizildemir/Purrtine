import SwiftUI

/// Shared motion values for the whole app.
///
/// Springs have no bounce except `delight`, which is reserved for rare, first-run moments.
/// Never use ease-in for UI. Values come from audit plan 001 (`docs/animation-audit.md`) and the owner's
/// decisions in `docs/stage2-polish-decisions.md`.
///
/// An animation that moves, scales or slides content goes through `resolve(_:reduceMotion:)` so Reduce Motion
/// turns it into a short fade:
///
/// ```swift
/// @Environment(\.accessibilityReduceMotion) private var reduceMotion
///
/// withAnimation(Motion.resolve(Motion.standard, reduceMotion: reduceMotion)) { … }
/// ```
///
/// Colour-only changes need no gate. `Animation` is `Sendable`, so the namespace is `nonisolated` and any
/// context (a `ButtonStyle`, a `Transition`, a test) can read it.
nonisolated enum Motion {
    /// Fades, error labels, selection colour. Strong ease-out.
    static let quick = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.2)
    /// Expand/collapse, toggles, view swaps. Interruptible spring, no bounce.
    static let standard = Animation.smooth(duration: 0.3)
    /// Onboarding steps and the root swap.
    static let screen = Animation.smooth(duration: 0.4)
    /// Rare moments only (first run, success).
    static let delight = Animation.spring(duration: 0.45, bounce: 0.2)
    /// Button press-in: quick down.
    static let pressDown = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.12)
    /// Button release: a slower, soft return.
    static let pressUp = Animation.spring(duration: 0.25, bounce: 0.15)
    /// Gentle replacement used when Reduce Motion is on. Pair it with an opacity transition.
    static let reduced = Animation.easeOut(duration: 0.15)

    /// Returns `animation`, or `reduced` when the person has Reduce Motion on.
    ///
    /// - Parameters:
    ///   - animation: The motion token to use normally.
    ///   - reduceMotion: The value of `@Environment(\.accessibilityReduceMotion)`.
    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation {
        reduceMotion ? reduced : animation
    }
}
