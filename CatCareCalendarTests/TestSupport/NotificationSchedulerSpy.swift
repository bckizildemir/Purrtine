import Foundation
import SwiftData
@testable import CatCareCalendar

@MainActor
final class NotificationSchedulerSpy: TaskNotificationScheduling {
    enum StubError: Error {
        case forcedFailure
    }

    /// One entry per successful full resync: every active schedule the store held at that moment,
    /// read the way `NotificationResyncCoordinator` reads it. Empty unless `observe(_:)` named a store.
    private(set) var resyncedInfos: [[NotificationScheduleInfo]] = []
    private(set) var resyncCount = 0
    private(set) var resyncAttemptCount = 0
    private(set) var snoozedRequests: [(taskId: UUID, delayMinutes: Int)] = []
    private(set) var removedDeliveredTaskIds: [UUID] = []
    private(set) var cancelledSnoozeTaskIds: [UUID] = []
    private(set) var syncBadgeCallCount = 0
    var resyncError: StubError?
    /// Makes the resync throw `CancellationError`, as a cancelled resync pass does.
    var isResyncCancelled = false
    /// Any error, so a test can throw what the real scheduler throws (`NotificationSchedulingError`).
    var snoozeError: (any Error)?
    private var observedContainer: ModelContainer?

    /// Records the store's active schedules at each successful resync in `resyncedInfos`.
    func observe(_ container: ModelContainer) {
        observedContainer = container
    }

    /// The active schedules the latest successful resync saw.
    var lastResyncedInfos: [NotificationScheduleInfo] {
        resyncedInfos.last ?? []
    }

    func resyncAllCareTaskReminders() async throws {
        resyncAttemptCount += 1
        if isResyncCancelled {
            throw CancellationError()
        }
        if let resyncError {
            throw resyncError
        }
        resyncCount += 1
        if let observedContainer {
            let tasks = try ModelContext(observedContainer).fetch(FetchDescriptor<CareTask>())
            resyncedInfos.append(tasks.flatMap(NotificationScheduleInfo.activeInfos(for:)))
        }
    }

    func cancelSnoozedNotifications(forTaskId taskId: UUID) async {
        cancelledSnoozeTaskIds.append(taskId)
    }

    func scheduleSnoozedNotification(for info: NotificationScheduleInfo, delayMinutes: Int) async throws {
        if let snoozeError {
            throw snoozeError
        }
        snoozedRequests.append((info.taskId, delayMinutes))
    }

    func removeDeliveredCareTaskNotifications(forTaskId taskId: UUID) async {
        removedDeliveredTaskIds.append(taskId)
    }

    func syncBadgeCount() async {
        syncBadgeCallCount += 1
    }
}
