#if DEBUG
import Foundation
import Testing
import UserNotifications
@testable import CatCareCalendar

@Suite
@MainActor
struct NotificationManagerDebugHistoryTests {
    @Test
    func deliveredHistoryReturnsTheCenterSnapshotsWithTheirDisplayFields() async throws {
        let deliveredAt = Date(timeIntervalSince1970: 1_800_000_000)
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.deliveredSnapshots = [
            DeliveredNotificationSnapshot(
                identifier: "delivered-1",
                taskId: UUID(),
                isTestNotification: false,
                title: "Feed Mia",
                body: "Breakfast is due",
                date: deliveredAt
            )
        ]

        let sut = try makeManager(notificationCenter: fakeCenter)

        let history = await sut.deliveredNotificationsForHistory()

        let delivered = try #require(history.first)
        #expect(history.count == 1)
        #expect(delivered.id == "delivered-1")
        #expect(delivered.title == "Feed Mia")
        #expect(delivered.body == "Breakfast is due")
        #expect(delivered.date == deliveredAt)
    }

    @Test
    func pendingHistoryReturnsOnlyTestNotifications() async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        fakeCenter.pendingRequests = [
            makePendingRequest(identifier: "test-true", userInfo: ["testNotification": true]),
            makePendingRequest(identifier: "test-false", userInfo: ["testNotification": false]),
            makePendingRequest(identifier: "reminder", userInfo: ["taskId": UUID().uuidString]),
            makePendingRequest(identifier: "no-user-info", userInfo: [:])
        ]

        let sut = try makeManager(notificationCenter: fakeCenter)

        let pending = await sut.pendingTestNotificationRequests()

        #expect(pending.map(\.identifier) == ["test-true"])
    }

    private func makePendingRequest(identifier: String, userInfo: [AnyHashable: Any]) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }

    private func makeManager(notificationCenter: FakeUserNotificationCenterClient) throws -> NotificationManager {
        let defaults = try #require(
            UserDefaults(suiteName: "NotificationManagerDebugHistoryTests.\(UUID().uuidString)")
        )
        return NotificationManager(
            notificationCenter: notificationCenter,
            settingsStore: NotificationSettingsStore(userDefaults: defaults, key: "settings")
        )
    }
}
#endif
