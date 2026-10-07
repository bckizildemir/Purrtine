import Foundation
import Testing
import UserNotifications
@testable import CatCareCalendar

@MainActor
struct NotificationSettingsStoreTests {
    @Test
    func missingPayloadUsesDefaults() throws {
        let suiteName = "NotificationSettingsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = NotificationSettingsStore(userDefaults: defaults, key: "settings")

        #expect(store.load() == .default)
    }

    @Test
    func payloadRoundTrips() throws {
        let suiteName = "NotificationSettingsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = NotificationSettingsStore(userDefaults: defaults, key: "settings")
        var settings = NotificationSettings.default
        settings.soundEnabled = false
        settings.overdueReminderDelayMinutes = 120
        settings.enabledCategories = [.medication]

        store.save(settings)

        #expect(store.load() == settings)
    }

    @Test
    func invalidPayloadUsesDefaults() throws {
        let suiteName = "NotificationSettingsStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data([0xFF]), forKey: "settings")
        let store = NotificationSettingsStore(userDefaults: defaults, key: "settings")

        #expect(store.load() == .default)
    }

    @Test(arguments: CareTaskCategory.allCases)
    func eligibilityAcceptsEachEnabledCategory(category: CareTaskCategory) {
        let info = makeInfo(category: category)
        var settings = NotificationSettings.default
        settings.enabledCategories = [category]

        #expect(NotificationSchedulingEligibility.allows(
            info: info, settings: settings, authorizationStatus: .authorized
        ))
    }

    @Test
    func eligibilityAllowsUrgentCriticalTasksForEverySchedulingAuthorization() {
        var settings = NotificationSettings.default
        settings.criticalTasksOnly = true
        let info = makeInfo(priority: .urgent, reminderMinutes: 0)

        for status in [
            UNAuthorizationStatus.authorized,
            .provisional,
            .ephemeral
        ] {
            #expect(NotificationSchedulingEligibility.allows(
                info: info,
                settings: settings,
                authorizationStatus: status
            ))
        }
    }

    @Test(arguments: EligibilityRejectionCase.all)
    private func eligibilityRejectsEveryIndependentNegativeDecision(testCase: EligibilityRejectionCase) {
        #expect(NotificationSchedulingEligibility.allows(
            info: testCase.info,
            settings: testCase.settings,
            authorizationStatus: testCase.authorizationStatus
        ) == false)
    }

    private func makeInfo(
        category: CareTaskCategory = .feeding,
        priority: CareTaskPriority = .medium,
        reminderMinutes: Int? = 15
    ) -> NotificationScheduleInfo {
        NotificationScheduleInfo(
            scheduleId: UUID(), taskId: UUID(), taskTitle: "Task", taskDescription: nil,
            catNames: "Miso", category: category, iconName: "circle", priority: priority,
            scheduledDate: .now, scheduledTime: nil, frequency: .once, frequencyInterval: 1,
            endDate: nil, customDays: nil, reminderMinutes: reminderMinutes
        )
    }
}

private struct EligibilityRejectionCase: CustomTestStringConvertible, Sendable {
    let testDescription: String
    let info: NotificationScheduleInfo
    let settings: NotificationSettings
    let authorizationStatus: UNAuthorizationStatus

    static var all: [Self] {
        var disabled = NotificationSettings.default
        disabled.isEnabled = false
        var criticalOnly = NotificationSettings.default
        criticalOnly.criticalTasksOnly = true
        var categoryDisabled = NotificationSettings.default
        categoryDisabled.enabledCategories.remove(.feeding)

        return [
            Self(
                testDescription: "globally disabled",
                info: info(),
                settings: disabled,
                authorizationStatus: .authorized
            ),
            Self(
                testDescription: "authorization not determined",
                info: info(),
                settings: .default,
                authorizationStatus: .notDetermined
            ),
            Self(
                testDescription: "authorization denied",
                info: info(),
                settings: .default,
                authorizationStatus: .denied
            ),
            Self(
                testDescription: "missing reminder",
                info: info(reminderMinutes: nil),
                settings: .default,
                authorizationStatus: .authorized
            ),
            Self(
                testDescription: "negative reminder",
                info: info(reminderMinutes: -1),
                settings: .default,
                authorizationStatus: .authorized
            ),
            Self(
                testDescription: "non-urgent task under critical-only policy",
                info: info(priority: .medium),
                settings: criticalOnly,
                authorizationStatus: .authorized
            ),
            Self(
                testDescription: "disabled category",
                info: info(),
                settings: categoryDisabled,
                authorizationStatus: .authorized
            )
        ]
    }

    private static func info(
        priority: CareTaskPriority = .medium,
        reminderMinutes: Int? = 15
    ) -> NotificationScheduleInfo {
        NotificationScheduleInfo(
            scheduleId: UUID(), taskId: UUID(), taskTitle: "Task", taskDescription: nil,
            catNames: "Miso", category: .feeding, iconName: "circle", priority: priority,
            scheduledDate: .now, scheduledTime: nil, frequency: .once, frequencyInterval: 1,
            endDate: nil, customDays: nil, reminderMinutes: reminderMinutes
        )
    }
}
