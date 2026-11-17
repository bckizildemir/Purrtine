import Foundation

enum NotificationSchedulingError: LocalizedError {
    case unauthorized
    /// Reminders are switched off in the app's settings, or the permission was lost while the snooze
    /// waited. Settings cannot fix it from the chat, so it reads as the generic "could not set up".
    case remindersOff

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            String(localized: .errorNotificationSchedulingUnauthorized)
        case .remindersOff:
            String(localized: .errorReminderSchedule)
        }
    }
}

/// `Sendable` so a `CareTaskWriter` can hold one from its `nonisolated` init. Every conformer is a
/// main-actor class, which is `Sendable` already.
@MainActor
protocol TaskNotificationScheduling: Sendable {
    /// Rebuilds every care-task reminder from the store and returns once the newest full resync has
    /// finished, throwing its error. There is no per-task entry point on purpose: only a pass over
    /// every task can keep the total within `CareTaskReminderSelection.limit`.
    func resyncAllCareTaskReminders() async throws
    /// Removes the pending snoozes of one task. The full resync leaves snoozes alone, so a verb that
    /// finishes the task's occurrence (complete, delete) clears them itself.
    func cancelSnoozedNotifications(forTaskId taskId: UUID) async
    /// Takes the value, not the model: a `CareTask` must not cross this async boundary.
    func scheduleSnoozedNotification(for info: NotificationScheduleInfo, delayMinutes: Int) async throws
    func removeDeliveredCareTaskNotifications(forTaskId taskId: UUID) async
    func syncBadgeCount() async
}
