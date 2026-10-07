#if DEBUG
import UserNotifications

@MainActor
final class PreviewUserNotificationCenterClient: UserNotificationCenterClient {
    var delegate: UNUserNotificationCenterDelegate?

    func add(_ request: UNNotificationRequest) async throws { }

    func authorizationStatus() async -> UNAuthorizationStatus {
        .denied
    }

    func deliveredNotificationSnapshots() async -> [DeliveredNotificationSnapshot] {
        []
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        []
    }

    func removeAllDeliveredNotifications() { }
    func removeAllPendingNotificationRequests() { }
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) { }
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) { }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        false
    }

    func setBadgeCount(_ badgeCount: Int) { }
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) { }
}
#endif
