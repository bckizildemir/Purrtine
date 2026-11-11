import Foundation

/// A `Sendable` copy of a delivered notification, built on the notification centre's callback
/// thread because `UNNotification` is not `Sendable`. The badge policy reads `taskId` and
/// `isTestNotification`; the debug Notification History screen also shows `title`, `body` and `date`.
nonisolated struct DeliveredNotificationSnapshot: Equatable, Identifiable, Sendable {
    let identifier: String
    let taskId: UUID?
    let isTestNotification: Bool
    let title: String
    let body: String
    /// A fixed default, never `Date()`, so equality never depends on the clock.
    let date: Date

    var id: String { identifier }

    init(
        identifier: String,
        taskId: UUID?,
        isTestNotification: Bool,
        title: String = "",
        body: String = "",
        date: Date = .distantPast
    ) {
        self.identifier = identifier
        self.taskId = taskId
        self.isTestNotification = isTestNotification
        self.title = title
        self.body = body
        self.date = date
    }

    init(
        identifier: String,
        userInfo: [AnyHashable: Any],
        title: String = "",
        body: String = "",
        date: Date = .distantPast
    ) {
        self.init(
            identifier: identifier,
            taskId: (userInfo["taskId"] as? String).flatMap(UUID.init(uuidString:)),
            isTestNotification: userInfo["testNotification"] as? Bool == true,
            title: title,
            body: body,
            date: date
        )
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
