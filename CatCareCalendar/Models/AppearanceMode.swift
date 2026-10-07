import SwiftUI

/// The user-selectable app appearance: follow the system, or force light/dark.
enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    /// The color scheme to apply via `preferredColorScheme`; `nil` follows the system.
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system:
            return String(localized: .settingsAppearanceSystem)
        case .light:
            return String(localized: .settingsAppearanceLight)
        case .dark:
            return String(localized: .settingsAppearanceDark)
        }
    }
}
