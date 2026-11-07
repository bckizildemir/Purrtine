import Foundation

enum SettingsPreferences {
    static let defaultTaskViewKey = "default_task_view"
    static let showCompletedTasksKey = "show_completed_tasks"
    static let hapticFeedbackEnabledKey = "haptic_feedback_enabled"
    static let appearanceModeKey = "appearance_mode"
    static let taskAssistantCloudConsentGrantedKey = "task_assistant_cloud_consent_granted"

    static func resolvedTaskViewMode(from rawValue: String?) -> CareTaskViewMode {
        guard let rawValue else {
            return .list
        }

        return CareTaskViewMode(rawValue: rawValue) ?? .list
    }

    static func resolvedAppearanceMode(from rawValue: String?) -> AppearanceMode {
        guard let rawValue else {
            return .system
        }

        return AppearanceMode(rawValue: rawValue) ?? .system
    }

    static func isHapticFeedbackEnabled(in userDefaults: UserDefaults) -> Bool {
        guard userDefaults.object(forKey: hapticFeedbackEnabledKey) != nil else {
            return true
        }

        return userDefaults.bool(forKey: hapticFeedbackEnabledKey)
    }

    /// Whether the user has been asked whether Task Assistant may send unresolved
    /// requests to the cloud interpretation tier. Presence of the stored value (not
    /// its content) is the signal — absent means never asked.
    static func hasAnsweredTaskAssistantCloudConsent(in userDefaults: UserDefaults) -> Bool {
        userDefaults.object(forKey: taskAssistantCloudConsentGrantedKey) != nil
    }

    static func isTaskAssistantCloudConsentGranted(in userDefaults: UserDefaults) -> Bool {
        guard userDefaults.object(forKey: taskAssistantCloudConsentGrantedKey) != nil else {
            return false
        }

        return userDefaults.bool(forKey: taskAssistantCloudConsentGrantedKey)
    }
}
