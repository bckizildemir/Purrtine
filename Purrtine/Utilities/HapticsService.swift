import SwiftUI
import UIKit

// MARK: - Haptics Protocol

/// Haptic feedback is UI feedback. Every call site is a SwiftUI view, and the
/// UIKit feedback generators are main-actor types, so the protocol is declared
/// on the main actor. The compiler now enforces at every call site what the
/// implementations used to check with `Thread.isMainThread` at runtime.
@MainActor
protocol Haptics {
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType)
    func selection()
}

// MARK: - Default Haptics Service
final class DefaultHapticsService: Haptics {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isHapticFeedbackEnabled else {
            #if DEBUG
            print("(Haptics disabled) impact(\(style))")
            #endif
            return
        }

        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isHapticFeedbackEnabled else {
            #if DEBUG
            print("(Haptics disabled) notify(\(type))")
            #endif
            return
        }

        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    func selection() {
        guard isHapticFeedbackEnabled else {
            #if DEBUG
            print("(Haptics disabled) selection()")
            #endif
            return
        }

        UISelectionFeedbackGenerator().selectionChanged()
    }

    private var isHapticFeedbackEnabled: Bool {
        SettingsPreferences.isHapticFeedbackEnabled(in: userDefaults)
    }
}

// MARK: - Dummy Haptics Service (for fallback)
private final class DummyHapticsService: Haptics {
    nonisolated init() { }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        // No-op implementation for fallback
    }

    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        // No-op implementation for fallback
    }

    func selection() {
        // No-op implementation for fallback
    }
}

extension EnvironmentValues {
    @Entry var haptics: Haptics = DummyHapticsService()
}
