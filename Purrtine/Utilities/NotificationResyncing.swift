import Foundation

@MainActor
protocol NotificationResyncing {
    func resyncCareTaskNotifications(with infos: [NotificationScheduleInfo]) async throws
}
