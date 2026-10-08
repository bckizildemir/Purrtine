import Foundation
import os
import SwiftData
import SwiftUI
import Synchronization

/// The production `CareTaskWriting`. It owns the commit and the one scheduler call per write, in that
/// order: change → `save()` → full resync.
///
/// The resync is a postcondition, not a debounce: a verb returns only after the newest full resync
/// has finished, so a failure reaches the caller instead of hiding in a background task. It covers
/// the whole store rather than the tasks the verb touched, because only a pass over every task can
/// keep the pending total within iOS's limit (#80). It is awaited rather than fired and forgotten: the
/// notification "Complete" action runs in the background and ends right after the writer returns, so
/// an unawaited resync could be suspended and leave a stale overdue reminder to fire.
final class CareTaskWriter: CareTaskWriting {
    private nonisolated let scheduler: any TaskNotificationScheduling
    private nonisolated let saveContext: @MainActor (ModelContext) throws -> Void
    private nonisolated let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "CareTaskWriter")

    /// `nonisolated` so the `@Entry` environment default below, which is read outside the main
    /// actor, can build one. It only stores the references; every verb still runs on the main actor.
    ///
    /// - Parameter saveContext: The commit step. Production keeps the default; a test passes a
    ///   throwing one, because SwiftData offers no other way to make a real `save()` fail.
    nonisolated init(
        scheduler: any TaskNotificationScheduling,
        saveContext: @escaping @MainActor (ModelContext) throws -> Void = { try $0.save() }
    ) {
        self.scheduler = scheduler
        self.saveContext = saveContext
    }

    /// One watch per context that still holds a failed delete. See `delete`.
    private var stagedDeleteWatches: [StagedDeleteWatch] = []

    /// The follow-up resync a save most recently started for a failed delete, so a test can await it.
    var pendingFollowUp: Task<Void, Never>? {
        stagedDeleteWatches.last?.latestFollowUp.withLock { $0 }
    }

    func save(_ task: CareTask, in context: ModelContext) async throws {
        // Decided before the insert: once inserted, every task looks staged.
        let isNew = task.modelContext == nil || isStaged(task, in: context)
        try commit(in: context) {
            context.insert(task)
        } undo: {
            if isNew {
                unstage(task, in: context)
            }
        }
        try await resyncReminders(for: [task.id])
    }

    func delete(_ task: CareTask, in context: ModelContext) async throws {
        let taskId = task.id
        let modelId = task.persistentModelID
        // No undo: a failed commit leaves the delete staged, and a later save commits it. Re-inserting
        // the task does not restore it: SwiftData drops the task from `Cat.tasks` and its completions
        // from `Caregiver.completions`, and neither survives a re-insert and relink (measured
        // 2026-09-24). Completing the delete the user asked for is the lesser harm, so a failure
        // arms a watch that resyncs once the delete lands, and drops the task's snoozes at once (#7).
        do {
            try commit(in: context) {
                context.delete(task)
            } undo: {}
        } catch {
            // Armed before the await, so a save that runs during it cannot slip past the watch.
            watchForStagedDelete(of: modelId, in: context)
            await scheduler.cancelSnoozedNotifications(forTaskId: taskId)
            throw error
        }
        await scheduler.cancelSnoozedNotifications(forTaskId: taskId)
        try await resyncReminders(for: [taskId])
    }

    func complete(
        _ task: CareTask,
        with input: CareTaskCompletionInput,
        in context: ModelContext
    ) async throws {
        let undo = CompletionUndo(capturing: task)
        try commit(in: context) {
            try TaskActionService.recordCompletion(of: task, with: input, in: context)
        } undo: {
            undo.restore(in: context)
        }

        let taskId = task.id
        // A snooze belongs to the occurrence just completed, so it goes before the resync.
        await scheduler.cancelSnoozedNotifications(forTaskId: taskId)
        let resyncError: (any Error)?
        do {
            try await resyncReminders(for: [taskId])
            resyncError = nil
        } catch {
            resyncError = error
        }
        // The delivered reminder is for the occurrence just completed, so it goes whether or not the
        // resync succeeded.
        await scheduler.removeDeliveredCareTaskNotifications(forTaskId: taskId)
        await scheduler.syncBadgeCount()
        if let resyncError {
            throw resyncError
        }
    }

    func snooze(_ task: CareTask, minutes: Int) async throws {
        try TaskActionService.validatePostponeMinutes(minutes)

        let info = NotificationScheduleInfo(
            snoozing: task,
            firingAt: Date().addingTimeInterval(TimeInterval(minutes * 60))
        )
        try await scheduler.scheduleSnoozedNotification(for: info, delayMinutes: minutes)
        await scheduler.removeDeliveredCareTaskNotifications(forTaskId: info.taskId)
        await scheduler.syncBadgeCount()
    }

    func refreshReminders(for taskIds: [UUID], in context: ModelContext) async throws {
        guard taskIds.isEmpty == false else { return }
        try await resyncReminders(for: taskIds)
    }

    // MARK: - Commit

    /// Applies `change` and commits it. A failure before the commit runs `undo`, which reverses what
    /// this verb staged and nothing else, so "not saved" holds for the context as well as the store:
    /// nothing of the write is left for the next unrelated `save()` to commit without a resync, and a
    /// form that retries does not stage a second copy.
    ///
    /// The undo is targeted on purpose. The main context is shared, and a full `rollback()` would
    /// also throw away changes other code staged there. Changes the caller staged before the verb —
    /// such as `TaskFormPersistence` edits to an existing task — stay pending.
    private func commit(
        in context: ModelContext,
        _ change: () throws -> Void,
        undo: () -> Void
    ) throws {
        do {
            try change()
            try saveContext(context)
        } catch {
            undo()
            throw error
        }
    }

    private func isStaged(_ task: CareTask, in context: ModelContext) -> Bool {
        context.insertedModelsArray.contains { $0.persistentModelID == task.persistentModelID }
    }

    /// Takes a task that was never committed back out of the context, with the schedules and
    /// completions staged alongside it. This covers a task the caller inserted, such as one from
    /// `TaskFormPersistence.createTask`: a retry creates a fresh one, so this copy must not linger.
    private func unstage(_ task: CareTask, in context: ModelContext) {
        let stagedIds = Set(context.insertedModelsArray.map(\.persistentModelID))
        let stagedSchedules = task.schedules.filter { stagedIds.contains($0.persistentModelID) }
        let stagedCompletions = task.completions.filter { stagedIds.contains($0.persistentModelID) }
        stagedSchedules.forEach(context.delete)
        stagedCompletions.forEach(context.delete)
        context.delete(task)
    }

    /// Adds `modelId` to the context's watch, or starts one. A watch that has seen all its deletes land
    /// has stopped observing and is dropped here.
    private func watchForStagedDelete(of modelId: PersistentIdentifier, in context: ModelContext) {
        stagedDeleteWatches.removeAll(where: \.isFinished)
        if let watch = stagedDeleteWatches.first(where: { $0.context === context }) {
            watch.pendingIds.insert(modelId)
        } else {
            stagedDeleteWatches.append(
                StagedDeleteWatch(watching: context, for: modelId, scheduler: scheduler, logger: logger)
            )
        }
    }

    // MARK: - Resync

    /// Brings every pending reminder in line with the store the verb just committed to. `taskIds`
    /// names the tasks the verb touched, for the error only: the resync itself covers every task.
    ///
    /// Runs after the commit, so any failure is reported as `CareTaskRemindersOutOfSyncError` —
    /// except cancellation, which passes through.
    private func resyncReminders(for taskIds: [UUID]) async throws {
        do {
            try await scheduler.resyncAllCareTaskReminders()
        } catch {
            throw outOfSync(taskIds, error)
        }
    }

    private func outOfSync(_ taskIds: [UUID], _ error: any Error) -> any Error {
        if error is CancellationError {
            return error
        }
        logger.error("Reminders out of sync for \(taskIds.count) task(s): \(error.localizedDescription)")
        return CareTaskRemindersOutOfSyncError(taskIds: taskIds, underlyingError: error)
    }

    /// What `TaskActionService.recordCompletion` changes, captured before it runs so a failed commit
    /// can put it back: the completion and next schedule it inserts, the active schedule it retires,
    /// and the task's status and timestamp.
    private struct CompletionUndo {
        let task: CareTask
        let completionIds: Set<UUID>
        let scheduleIds: Set<UUID>
        let activeSchedule: CareTaskSchedule?
        let wasActiveScheduleActive: Bool
        let status: CareTaskStatus
        let updatedAt: Date

        init(capturing task: CareTask) {
            self.task = task
            completionIds = Set(task.completions.map(\.id))
            scheduleIds = Set(task.schedules.map(\.id))
            activeSchedule = task.activeSchedule
            wasActiveScheduleActive = task.activeSchedule?.isActive ?? false
            status = task.status
            updatedAt = task.updatedAt
        }

        func restore(in context: ModelContext) {
            let addedCompletions = task.completions.filter { completionIds.contains($0.id) == false }
            let addedSchedules = task.schedules.filter { scheduleIds.contains($0.id) == false }
            task.completions.removeAll { completionIds.contains($0.id) == false }
            task.schedules.removeAll { scheduleIds.contains($0.id) == false }
            addedCompletions.forEach(context.delete)
            addedSchedules.forEach(context.delete)
            activeSchedule?.isActive = wasActiveScheduleActive
            task.status = status
            task.updatedAt = updatedAt
        }
    }

    /// Waits for the save that commits a failed delete, whoever makes it, then runs one full resync,
    /// so the deleted task stops reminding (#7). One save that lands several pending deletes resyncs
    /// once. When that save is itself a writer verb, the verb resyncs too; the second pass is accepted.
    ///
    /// Lifetime: `NotificationCenter` keeps the observer block, and the block keeps the watch and its
    /// scheduler, until the last pending delete lands. The watch therefore outlives the writer that
    /// armed it, such as a Tasks view model's own writer. A delete that never lands (the app quits
    /// first) keeps the watch until the process ends.
    ///
    /// Autosave: the watch reacts to `ModelContext.didSave`, which an explicit `save()` posts. Whether
    /// an autosave of the main context posts it is unverified: in the unit-test host, autosave did not
    /// commit a staged delete within 10 seconds (2026-10-08), so the check proved nothing either way.
    private final class StagedDeleteWatch {
        private(set) weak var context: ModelContext?
        var pendingIds: Set<PersistentIdentifier>
        /// The newest follow-up task. Written from the observer block, which runs on whatever thread
        /// saved, so it sits behind a lock rather than on the main actor.
        nonisolated let latestFollowUp = Mutex<Task<Void, Never>?>(nil)
        private let scheduler: any TaskNotificationScheduling
        private let logger: Logger
        private var observer: (any NSObjectProtocol)?

        var isFinished: Bool { observer == nil }

        init(
            watching context: ModelContext,
            for modelId: PersistentIdentifier,
            scheduler: any TaskNotificationScheduling,
            logger: Logger
        ) {
            self.context = context
            pendingIds = [modelId]
            self.scheduler = scheduler
            self.logger = logger
            // `@Sendable` keeps the block nonisolated: a save may post from another thread, where a
            // main-actor block would trap. It copies the IDs out, then hops to the main actor.
            observer = NotificationCenter.default.addObserver(
                forName: ModelContext.didSave,
                object: context,
                queue: nil
            ) { @Sendable [self] notification in
                let deletedIds = notification.userInfo?[ModelContext.NotificationKey.deletedIdentifiers.rawValue]
                    as? [PersistentIdentifier] ?? []
                let followUp = Task { @MainActor in
                    await self.resyncIfLanded(deletedIds)
                }
                latestFollowUp.withLock { $0 = followUp }
            }
        }

        private func resyncIfLanded(_ deletedIds: [PersistentIdentifier]) async {
            let pendingCount = pendingIds.count
            pendingIds.subtract(deletedIds)
            guard pendingIds.count < pendingCount else { return }
            if pendingIds.isEmpty, let observer {
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
            do {
                try await scheduler.resyncAllCareTaskReminders()
            } catch is CancellationError {
                // The next resync rebuilds the reminders from the store.
            } catch {
                logger.error("Resync after a staged delete landed failed: \(error.localizedDescription)")
            }
        }
    }
}

extension EnvironmentValues {
    /// `CatCareCalendarApp` injects the app's writer. The default writes through the same
    /// `NotificationManager`, so a view outside that hierarchy — a preview — still keeps the
    /// guarantee rather than silently dropping its resync.
    @Entry var careTaskWriter: any CareTaskWriting = CareTaskWriter(scheduler: NotificationManager.shared)
}
