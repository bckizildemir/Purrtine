import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Reusable helpers for hiding the keyboard in SwiftUI.
///
/// `UIApplication.shared` is main-actor isolated, so the helper is too.
@MainActor
enum KeyboardDismissal {
    static func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
#endif
    }
}

private struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            // Recognize taps anywhere inside the hosting view.
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    KeyboardDismissal.hideKeyboard()
                }
            )
    }
}

extension View {
    /// Adds a tap gesture that dismisses the keyboard without blocking other interactions.
    func dismissKeyboardOnTap() -> some View {
        modifier(DismissKeyboardOnTapModifier())
    }

    /// Programmatically hides the keyboard (useful for toolbar actions).
    @MainActor
    func hideKeyboard() {
        KeyboardDismissal.hideKeyboard()
    }
}
