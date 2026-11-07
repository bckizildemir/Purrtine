import Foundation

struct DebugPendingNotification: Identifiable, Equatable, Sendable {
    let id: String
    let taskId: UUID
    let taskTitle: String
    let body: String
    let scheduledDate: Date
}

actor NotificationDebugStore {
    static let shared = NotificationDebugStore()

    private var pendingNotifications: [DebugPendingNotification] = []

    func recordPendingNotification(
        id: String,
        taskId: UUID,
        taskTitle: String,
        body: String,
        scheduledDate: Date
    ) {
        pendingNotifications.removeAll { $0.id == id }
        pendingNotifications.append(
            DebugPendingNotification(
                id: id,
                taskId: taskId,
                taskTitle: taskTitle,
                body: body,
                scheduledDate: scheduledDate
            )
        )
    }

    func removePendingNotifications(forTaskId taskId: UUID) {
        pendingNotifications.removeAll { $0.taskId == taskId }
    }

    func removeAllPendingNotifications() {
        pendingNotifications.removeAll()
    }

    func pendingNotificationSnapshots() -> [DebugPendingNotification] {
        pendingNotifications.sorted { $0.scheduledDate < $1.scheduledDate }
    }
}
