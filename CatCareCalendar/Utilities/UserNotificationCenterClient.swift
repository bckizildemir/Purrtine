import Foundation
import UserNotifications

@MainActor
protocol UserNotificationCenterClient: AnyObject {
    var delegate: UNUserNotificationCenterDelegate? { get set }

    func add(_ request: UNNotificationRequest) async throws
    func authorizationStatus() async -> UNAuthorizationStatus
    func deliveredNotificationSnapshots() async -> [DeliveredNotificationSnapshot]
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removeAllDeliveredNotifications()
    func removeAllPendingNotificationRequests()
    func removeDeliveredNotifications(withIdentifiers identifiers: [String])
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func setBadgeCount(_ badgeCount: Int)
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
}

@MainActor
final class SystemUserNotificationCenterClient: UserNotificationCenterClient {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    var delegate: UNUserNotificationCenterDelegate? {
        get { center.delegate }
        set { center.delegate = newValue }
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func deliveredNotificationSnapshots() async -> [DeliveredNotificationSnapshot] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[DeliveredNotificationSnapshot], Never>) in
            center.getDeliveredNotifications { notifications in
                // Map inside the callback: UNNotification is not Sendable, so the
                // snapshots have to be built before the value leaves this thread.
                continuation.resume(
                    returning: notifications.map { notification in
                        DeliveredNotificationSnapshot(
                            identifier: notification.request.identifier,
                            userInfo: notification.request.content.userInfo,
                            title: notification.request.content.title,
                            body: notification.request.content.body,
                            date: notification.date
                        )
                    }
                )
            }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func removeAllDeliveredNotifications() {
        center.removeAllDeliveredNotifications()
    }

    func removeAllPendingNotificationRequests() {
        center.removeAllPendingNotificationRequests()
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func setBadgeCount(_ badgeCount: Int) {
        center.setBadgeCount(badgeCount)
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }
}
