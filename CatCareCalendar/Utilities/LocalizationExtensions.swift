import Foundation

// MARK: - Dynamic Localization Key Resolution
//
// User-facing strings whose keys are known at compile time use the generated
// String Catalog symbols (e.g. `String(localized: .tasksTitle)`,
// `Text(.homeCurrentTasks)`), generated from `Resources/Localizable.xcstrings`.
//
// This helper exists only for keys stored as *data* — currently the persisted
// `Caregiver.localizationKey` — where the key cannot be a compile-time symbol.
extension String {
    /// Resolves a localization key that is stored as data (e.g. persisted in SwiftData).
    /// For compile-time-known strings, use the generated String Catalog symbols instead.
    nonisolated var localizedDataKey: String {
        NSLocalizedString(self, comment: "")
    }
}
