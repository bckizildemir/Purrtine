import Foundation
import SwiftData
import UserNotifications

enum NotificationActionCommand: Equatable, Sendable {
    case complete
    case snooze(minutes: Int)

    init?(identifier: String) {
        switch identifier {
        case "COMPLETE_ACTION":
            self = .complete
        case "REMIND_10MIN":
            self = .snooze(minutes: 10)
        case "REMIND_30MIN", "POSTPONE_ACTION":
            self = .snooze(minutes: 30)
        case "REMIND_1HOUR":
            self = .snooze(minutes: 60)
        default:
            return nil
        }
    }
}

struct NotificationActionResult: Equatable, Sendable {
    let didPerformAction: Bool
}

@MainActor
protocol NotificationAuthorizationChecking {
    func refreshAuthorizationStatusFromSystem() async -> UNAuthorizationStatus
}

@MainActor
struct SimulatedNotificationAuthorizationChecker: NotificationAuthorizationChecking {
    func refreshAuthorizationStatusFromSystem() async -> UNAuthorizationStatus {
        .authorized
    }
}

@MainActor
final class NotificationActionCoordinator {
    private let modelContainer: ModelContainer
    private let taskWriter: any CareTaskWriting
    private let authorizationChecker: NotificationAuthorizationChecking

    init(
        modelContainer: ModelContainer,
        taskWriter: any CareTaskWriting,
        authorizationChecker: NotificationAuthorizationChecking = NotificationManager.shared
    ) {
        self.modelContainer = modelContainer
        self.taskWriter = taskWriter
        self.authorizationChecker = authorizationChecker
    }

    func handle(_ action: NotificationActionCommand, taskId: UUID) async -> NotificationActionResult {
        let context = ModelContext(modelContainer)

        do {
            switch action {
            case .complete:
                try await taskWriter.complete(try fetchTask(taskId, in: context), with: .init(), in: context)
            case .snooze(let minutes):
                let authorizationStatus = await authorizationChecker.refreshAuthorizationStatusFromSystem()
                guard authorizationStatus.allowsScheduling else {
                    return NotificationActionResult(didPerformAction: false)
                }

                try await taskWriter.snooze(try fetchTask(taskId, in: context), minutes: minutes)
            }

            return NotificationActionResult(didPerformAction: true)
        } catch let error as CareTaskRemindersOutOfSyncError {
            // The completion committed; only its reminders are stale, and the next resync rebuilds
            // them. Reporting failure here would invite a second completion of the same occurrence.
            print("❌ Reminders stale after notification action for task \(taskId): \(error.localizedDescription)")
            return NotificationActionResult(didPerformAction: true)
        } catch {
            print("❌ Failed to handle notification action for task \(taskId): \(error.localizedDescription)")
            return NotificationActionResult(didPerformAction: false)
        }
    }

    private func fetchTask(_ taskId: UUID, in context: ModelContext) throws -> CareTask {
        guard let task = try TaskActionService.fetchTask(taskId, in: context) else {
            throw TaskActionError.taskNotFound
        }
        return task
    }
}

private extension UNAuthorizationStatus {
    var allowsScheduling: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}
