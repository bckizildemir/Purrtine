import Foundation
import Testing
import UserNotifications
@testable import CatCareCalendar

@Suite
@MainActor
struct NotificationManagerLifecycleTests {
    @Test(arguments: [true, false])
    func permissionResultUpdatesAuthorizationAndOnlySignalsOnGrant(shouldGrant: Bool) async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.requestAuthorizationResult = shouldGrant
        let sut = try makeManager(notificationCenter: fakeCenter)
        var settingsChangeCount = 0
        sut.onFullResyncRequested = { settingsChangeCount += 1 }

        let granted = await sut.requestPermission()

        #expect(granted == shouldGrant)
        #expect(sut.authorizationStatus == (shouldGrant ? .authorized : .denied))
        #expect(settingsChangeCount == (shouldGrant ? 1 : 0))
        #expect(fakeCenter.lastRequestedAuthorizationOptions == [
            .alert,
            .badge,
            .sound,
            .providesAppNotificationSettings
        ])
    }

    @Test
    func permissionFailureIsContainedAsDeniedWithoutSignalingSettings() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.requestAuthorizationError = NotificationCenterFailure.requestAuthorization
        let sut = try makeManager(notificationCenter: fakeCenter)
        var settingsChangeCount = 0
        sut.onFullResyncRequested = { settingsChangeCount += 1 }

        let granted = await sut.requestPermission()

        #expect(granted == false)
        #expect(sut.authorizationStatus == .denied)
        #expect(settingsChangeCount == 0)
    }

    @Test
    func authorizationRefreshSignalsOnlyWhenSchedulingAccessChanges() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter)
        var settingsChangeCount = 0
        sut.onFullResyncRequested = { settingsChangeCount += 1 }

        fakeCenter.authorizationStatusValue = .provisional
        let provisionalStatus = await sut.refreshAuthorizationStatusFromSystem()
        #expect(provisionalStatus == .provisional)
        #expect(settingsChangeCount == 1)

        fakeCenter.authorizationStatusValue = .authorized
        let authorizedStatus = await sut.refreshAuthorizationStatusFromSystem()
        #expect(authorizedStatus == .authorized)
        #expect(settingsChangeCount == 1)

        fakeCenter.authorizationStatusValue = .denied
        let deniedStatus = await sut.refreshAuthorizationStatusFromSystem()
        #expect(deniedStatus == .denied)
        #expect(settingsChangeCount == 2)
    }

    /// Delivered reminders free their slots, so each activation tops the set back up. The request
    /// comes once, after the permission refresh, even when that refresh changed access and would
    /// otherwise ask for a resync of its own.
    @Test(arguments: [UNAuthorizationStatus.notDetermined, .authorized])
    func activationRequestsOneResyncAfterRefreshingAuthorization(previousStatus: UNAuthorizationStatus) async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.authorizationStatusValue = previousStatus
        let sut = try makeManager(notificationCenter: fakeCenter)
        await sut.checkAuthorizationStatus()
        fakeCenter.authorizationStatusValue = .authorized
        var statusesAtResyncRequest: [UNAuthorizationStatus] = []
        sut.onFullResyncRequested = { statusesAtResyncRequest.append(sut.authorizationStatus) }

        await sut.handleAppActivation()

        #expect(statusesAtResyncRequest == [.authorized])
        #expect(fakeCenter.badgeCounts.isEmpty == false)
    }

    @Test
    func deliveredCleanupRemovesOnlyNonTestNotificationsForRequestedTask() async throws {
        let taskId = UUID()
        let otherTaskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.deliveredSnapshots = [
            DeliveredNotificationSnapshot(identifier: "owned", taskId: taskId, isTestNotification: false),
            DeliveredNotificationSnapshot(identifier: "test", taskId: taskId, isTestNotification: true),
            DeliveredNotificationSnapshot(identifier: "other", taskId: otherTaskId, isTestNotification: false)
        ]
        let sut = try makeManager(notificationCenter: fakeCenter)

        await sut.removeDeliveredCareTaskNotifications(forTaskId: taskId)

        #expect(fakeCenter.removedDeliveredIdentifiers == [["owned"]])
        #expect(fakeCenter.deliveredSnapshots.map(\.identifier) == ["test", "other"])
    }

    @Test
    func snoozeWithHiddenDetailsUsesGenericContentAndPositiveInterval() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        var settings = NotificationSettings.default
        settings.showTaskDetails = false
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settings)
        let task = CareTask(
            title: "Sensitive medication",
            description: "Private dosage",
            category: .medication,
            iconName: "pills.fill",
            priority: .urgent
        )
        task.assignedCats = [Cat(name: "Mochi")]

        try await sut.scheduleSnoozedNotification(
            for: NotificationScheduleInfo(snoozing: task, firingAt: Date().addingTimeInterval(600)),
            delayMinutes: 10
        )

        let request = try #require(fakeCenter.addedRequests.first)
        let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
        #expect(fakeCenter.addedRequests.count == 1)
        #expect(trigger.timeInterval == 600)
        #expect(request.content.title == String(localized: .notificationReminderGenericTitle))
        #expect(request.content.body == String(localized: .notificationGenericBody))
        #expect(Set(request.content.userInfo.keys.compactMap { $0 as? String }) == ["taskId"])
        #expect(request.content.userInfo["taskId"] as? String == task.id.uuidString)
    }

    private func makeManager(
        notificationCenter: FakeUserNotificationCenterClient,
        settings: NotificationSettings = .default
    ) throws -> NotificationManager {
        let defaults = try #require(
            UserDefaults(suiteName: "NotificationManagerLifecycleTests.\(UUID().uuidString)")
        )
        let store = NotificationSettingsStore(userDefaults: defaults, key: "settings")
        store.save(settings)
        return NotificationManager(notificationCenter: notificationCenter, settingsStore: store)
    }
}

private enum NotificationCenterFailure: Error {
    case requestAuthorization
}
