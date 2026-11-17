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

/// Tells the caregiver that a reminder's Complete was refused and nothing was recorded (#141).
@MainActor
protocol CompletionRefusalNoticePosting {
    func postCompletionNotRecordedNotice(forTaskId taskId: UUID) async
}

/// Posts nothing: for launches that must not touch the real notification center.
@MainActor
struct SilentCompletionRefusalNotice: CompletionRefusalNoticePosting {
    func postCompletionNotRecordedNotice(forTaskId taskId: UUID) async {}
}

@MainActor
final class NotificationActionCoordinator {
    private let modelContainer: ModelContainer
    private let taskWriter: any CareTaskWriting
    private let authorizationChecker: NotificationAuthorizationChecking
    private let refusalNotice: CompletionRefusalNoticePosting

    init(
        modelContainer: ModelContainer,
        taskWriter: any CareTaskWriting,
        authorizationChecker: NotificationAuthorizationChecking = NotificationManager.shared,
        refusalNotice: CompletionRefusalNoticePosting
    ) {
        self.modelContainer = modelContainer
        self.taskWriter = taskWriter
        self.authorizationChecker = authorizationChecker
        self.refusalNotice = refusalNotice
    }

    func handle(
        _ action: NotificationActionCommand,
        taskId: UUID,
        occurrence: Date? = nil
    ) async -> NotificationActionResult {
        let context = ModelContext(modelContainer)

        do {
            switch action {
            case .complete:
                // A reminder names its occurrence; one without it (made before #141) completes the open one.
                let input = CareTaskCompletionInput(expectedOccurrence: occurrence)
                try await taskWriter.complete(try fetchTask(taskId, in: context), with: input, in: context)
            case .snooze(let minutes):
                let authorizationStatus = await authorizationChecker.refreshAuthorizationStatusFromSystem()
                guard authorizationStatus.allowsScheduling else {
                    return NotificationActionResult(didPerformAction: false)
                }

                try await taskWriter.snooze(
                    try fetchTask(taskId, in: context),
                    minutes: minutes,
                    occurrence: occurrence
                )
            }

            return NotificationActionResult(didPerformAction: true)
        } catch let error as CareTaskRemindersOutOfSyncError {
            // The completion committed; only its reminders are stale, and the next resync rebuilds
            // them. Reporting failure here would invite a second completion of the same occurrence.
            print("❌ Reminders stale after notification action for task \(taskId): \(error.localizedDescription)")
            return NotificationActionResult(didPerformAction: true)
        } catch TaskActionError.occurrenceNotOpen where action == .complete {
            // The tap did nothing, and the lock screen would show nothing: say so (#141).
            await refusalNotice.postCompletionNotRecordedNotice(forTaskId: taskId)
            return NotificationActionResult(didPerformAction: false)
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
