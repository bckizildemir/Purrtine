import os
import SwiftData

/// Runs the full reminder resync: reads every active schedule from the store and hands it to
/// `NotificationManager`, which rebuilds the capped pending set. It is the only way care-task
/// reminders are rebuilt.
///
/// Passes run one after another. A new request cancels the pass in flight, and the new pass waits
/// for it to stop before it reads the store, so back-to-back requests coalesce into one rebuild from
/// the newest store state.
@MainActor
final class NotificationResyncCoordinator {
    private let modelContainer: ModelContainer
    private let notificationManager: NotificationResyncing
    private let fetchTasks: @MainActor (ModelContext) throws -> [CareTask]
    private let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "NotificationResync")
    private var resyncTask: Task<Void, any Error>?

    /// - Parameter fetchTasks: The store read. Production keeps the default; a test passes a
    ///   throwing one, because SwiftData offers no other way to make a real fetch fail.
    init(
        modelContainer: ModelContainer,
        notificationManager: NotificationResyncing,
        fetchTasks: @escaping @MainActor (ModelContext) throws -> [CareTask] = {
            try $0.fetch(FetchDescriptor<CareTask>())
        }
    ) {
        self.modelContainer = modelContainer
        self.notificationManager = notificationManager
        self.fetchTasks = fetchTasks
    }

    /// Starts a pass without waiting for it. Settings, permission and app-activation changes use
    /// this; a failure is logged, and the next pass rebuilds the whole set anyway.
    @discardableResult
    func scheduleResync() -> Task<Void, any Error> {
        let previousTask = resyncTask
        previousTask?.cancel()
        let task = Task { [weak self] in
            _ = await previousTask?.result
            try Task.checkCancellation()
            guard let self else { return }
            do {
                try await self.resyncNow()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                self.logger.error("Reminder resync failed: \(error.localizedDescription)")
                throw error
            }
        }
        resyncTask = task
        return task
    }

    /// Starts a pass and returns once the newest pass has finished, throwing its error.
    ///
    /// A pass that a newer request cancelled returns early, which is not success: the reminders
    /// match the store only once the newest pass completes. So this follows the chain to whichever
    /// pass is newest when the one it awaited ends.
    func resync() async throws {
        var task = scheduleResync()
        while true {
            do {
                try await task.value
                return
            } catch {
                guard let newerTask = resyncTask, newerTask != task else { throw error }
                task = newerTask
            }
        }
    }

    func resyncNow() async throws {
        let infos = try activeScheduleInfos()
        try Task.checkCancellation()
        try await notificationManager.resyncCareTaskNotifications(with: infos)
    }

    /// Every active schedule in the store. A failed fetch throws rather than returning an empty
    /// list, so the resync leaves the pending set alone instead of reading it as "no tasks".
    ///
    /// Reads through a fresh context, so it sees only committed state — including a commit made in
    /// another context, such as a notification action's — and never the main context's unsaved edits.
    func activeScheduleInfos() throws -> [NotificationScheduleInfo] {
        let context = ModelContext(modelContainer)
        return try fetchTasks(context).flatMap(NotificationScheduleInfo.activeInfos(for:))
    }
}
