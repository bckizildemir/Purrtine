import Foundation
import SwiftUI
import Testing
@testable import CatCareCalendar

@MainActor
struct SettingsPreferencesTests {
    @Test
    func hapticFeedbackDefaultsToEnabledWhenPreferenceHasNotBeenWritten() throws {
        try withUserDefaults { userDefaults in
            #expect(SettingsPreferences.isHapticFeedbackEnabled(in: userDefaults))
        }
    }

    @Test(arguments: [
        (true, true),
        (false, false)
    ])
    func hapticFeedbackReflectsPersistedPreference(storedValue: Bool, expectedValue: Bool) throws {
        try withUserDefaults { userDefaults in
            userDefaults.set(storedValue, forKey: SettingsPreferences.hapticFeedbackEnabledKey)

            #expect(SettingsPreferences.isHapticFeedbackEnabled(in: userDefaults) == expectedValue)
        }
    }

    @Test(arguments: [
        (CareTaskViewMode.list.rawValue, CareTaskViewMode.list),
        (CareTaskViewMode.calendar.rawValue, CareTaskViewMode.calendar),
        ("unsupported", CareTaskViewMode.list),
        (nil, CareTaskViewMode.list)
    ])
    func taskViewModeFallsBackToListForMissingOrUnsupportedValues(
        rawValue: String?,
        expectedMode: CareTaskViewMode
    ) {
        #expect(SettingsPreferences.resolvedTaskViewMode(from: rawValue) == expectedMode)
    }

    @Test(arguments: [
        (AppearanceMode.system.rawValue, AppearanceMode.system),
        (AppearanceMode.light.rawValue, AppearanceMode.light),
        (AppearanceMode.dark.rawValue, AppearanceMode.dark),
        ("unsupported", AppearanceMode.system),
        (nil, AppearanceMode.system)
    ])
    func appearanceModeFallsBackToSystemForMissingOrUnsupportedValues(
        rawValue: String?,
        expectedMode: AppearanceMode
    ) {
        #expect(SettingsPreferences.resolvedAppearanceMode(from: rawValue) == expectedMode)
    }

    @Test
    func taskAssistantCloudConsentIsUnansweredAndNotGrantedByDefault() throws {
        try withUserDefaults { userDefaults in
            #expect(SettingsPreferences.hasAnsweredTaskAssistantCloudConsent(in: userDefaults) == false)
            #expect(SettingsPreferences.isTaskAssistantCloudConsentGranted(in: userDefaults) == false)
        }
    }

    @Test(arguments: [true, false])
    func taskAssistantCloudConsentReflectsPersistedAnswer(storedValue: Bool) throws {
        try withUserDefaults { userDefaults in
            userDefaults.set(storedValue, forKey: SettingsPreferences.taskAssistantCloudConsentGrantedKey)

            #expect(SettingsPreferences.hasAnsweredTaskAssistantCloudConsent(in: userDefaults))
            #expect(SettingsPreferences.isTaskAssistantCloudConsentGranted(in: userDefaults) == storedValue)
        }
    }

    @Test
    func appearanceModeMapsToExpectedColorScheme() {
        #expect(AppearanceMode.system.preferredColorScheme == nil)
        #expect(AppearanceMode.light.preferredColorScheme == .light)
        #expect(AppearanceMode.dark.preferredColorScheme == .dark)
    }

    private func withUserDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "SettingsPreferencesTests-\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        try body(userDefaults)
    }
}
