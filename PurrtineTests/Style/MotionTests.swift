import SwiftUI
import Testing
@testable import Purrtine

struct MotionTests {
    /// Every token a call site can pass to `Motion.resolve`.
    static let tokens: [Animation] = [
        Motion.quick,
        Motion.standard,
        Motion.screen,
        Motion.delight,
        Motion.pressDown,
        Motion.pressUp
    ]

    @Test(arguments: tokens)
    func resolveKeepsTheTokenWhenReduceMotionIsOff(token: Animation) {
        #expect(Motion.resolve(token, reduceMotion: false) == token)
    }

    @Test(arguments: tokens)
    func resolveSwapsEveryTokenForTheReducedFadeWhenReduceMotionIsOn(token: Animation) {
        #expect(Motion.resolve(token, reduceMotion: true) == Motion.reduced)
    }

    @Test(arguments: tokens)
    func reducedFadeIsNotOneOfTheMotionTokens(token: Animation) {
        #expect(Motion.reduced != token)
    }

    @Test
    func tokensAreDistinct() {
        #expect(Set(Self.tokens).count == Self.tokens.count)
    }
}
