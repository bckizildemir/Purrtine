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
final class NotificationActionCoordinator {
    private let modelContainer: ModelContainer
    private let taskWriter: any CareTaskWriting

    init(modelContainer: ModelContainer, taskWriter: any CareTaskWriting) {
        self.modelContainer = modelContainer
        self.taskWriter = taskWriter
    }

    func handle(_ action: NotificationActionCommand, taskId: UUID) async -> NotificationActionResult {
        let context = ModelContext(modelContainer)

        do {
            switch action {
            case .complete:
                try await taskWriter.complete(try fetchTask(taskId, in: context), with: .init(), in: context)
            case .snooze(let minutes):
                // No await before the writer reads the task's snooze generation: a completion landing
                // in between would be missed (#142). The scheduler checks the permission itself and
                // throws, which the catch below reports as no action.
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
