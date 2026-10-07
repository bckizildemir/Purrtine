import Foundation

nonisolated struct DeliveredNotificationSnapshot: Equatable, Sendable {
    let identifier: String
    let taskId: UUID?
    let isTestNotification: Bool

    init(identifier: String, taskId: UUID?, isTestNotification: Bool) {
        self.identifier = identifier
        self.taskId = taskId
        self.isTestNotification = isTestNotification
    }

    init(identifier: String, userInfo: [AnyHashable: Any]) {
        self.identifier = identifier
        self.taskId = (userInfo["taskId"] as? String).flatMap(UUID.init(uuidString:))
        self.isTestNotification = userInfo["testNotification"] as? Bool == true
    }
}

enum NotificationBadgePolicy {
    static func badgeCount(
        for deliveredNotifications: [DeliveredNotificationSnapshot],
        badgeEnabled: Bool
    ) -> Int {
        guard badgeEnabled else { return 0 }

        return deliveredNotifications.count { snapshot in
            snapshot.isTestNotification == false && snapshot.taskId != nil
        }
    }
}
