import Foundation

enum TaskViewPreference {
    static let defaultTaskViewKey = SettingsPreferences.defaultTaskViewKey

    static func resolvedViewMode(from rawValue: String?) -> CareTaskViewMode {
        SettingsPreferences.resolvedTaskViewMode(from: rawValue)
    }
}
