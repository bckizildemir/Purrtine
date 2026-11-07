import Foundation

@MainActor
final class NotificationSettingsStore {
    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults = .standard, key: String = "notification_settings") {
        self.userDefaults = userDefaults
        self.key = key
    }

    func load() -> NotificationSettings {
        guard let data = userDefaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save(_ settings: NotificationSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        userDefaults.set(data, forKey: key)
    }
}
