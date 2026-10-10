import Foundation
import os
import SwiftData
import Synchronization

/// Deletes a cat, the tasks only it was assigned to, and its photos, then resyncs the reminders of
/// every task the cat was on.
///
/// A task shared with another cat survives with this cat removed, and its reminders are rebuilt
/// because they carry the cat names they were scheduled with. A task this cat alone was on is
/// deleted by the `Cat.tasks` cascade, and its reminders are cancelled.
@MainActor
struct CatDeletionService {
    struct DeletionSummary {
        let deletedPhotoFileNames: [String]
        let deletedTaskIds: [UUID]
    }

    /// What a failed delete still owes once a later save lands it, captured before the delete.
    private struct StagedCatDelete {
        let photoFileNames: [String]
        let touchedTaskIds: [UUID]
    }

    private static let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "CatDeletion")

    /// One watch per context that still holds a failed cat delete. Static, because the service is a
    /// value each view builds per delete, and one landing save must resync once for every cat it lands.
    /// A watch keeps the `deletePhoto` and `taskWriter` of the service that started it, for every cat
    /// it lands; in the app every service gets the same ones, so that is the same work.
    private static var stagedDeleteWatches: [StagedDeleteWatch<StagedCatDelete>] = []

    /// Test handle only: the follow-up a save most recently started for the watch on `context`, so a
    /// test can await it without sleeping.
    static func pendingFollowUp(in context: ModelContext) -> Task<Void, Never>? {
        stagedDeleteWatches.last { $0.context === context }?.latestFollowUp.withLock { $0 }
    }

    private let taskWriter: any CareTaskWriting
    private let deletePhoto: (String) -> Void
    private let saveContext: @MainActor (ModelContext) throws -> Void

    /// - Parameter saveContext: The commit step. Production keeps the default; a test passes a
    ///   throwing one, because SwiftData offers no other way to make a real `save()` fail.
    init(
        taskWriter: any CareTaskWriting,
        deletePhoto: @escaping (String) -> Void = { PhotoManager.shared.deletePhoto(at: $0) },
        saveContext: @escaping @MainActor (ModelContext) throws -> Void = CatDeletionService.commit
    ) {
        self.taskWriter = taskWriter
        self.deletePhoto = deletePhoto
        self.saveContext = saveContext
    }

    private static func commit(_ modelContext: ModelContext) throws {
        #if DEBUG
        // UI-test-only; see `AppLaunchConfiguration.failsCatDeleteCommit`.
        if AppLaunchConfiguration.current.failsCatDeleteCommit {
            throw InjectedCommitFailure()
        }
        #endif
        try modelContext.save()
    }

    #if DEBUG
    /// Failure injected by the `-fail-cat-delete-commit` UI-test launch argument.
    struct InjectedCommitFailure: Error {}
    #endif

    /// Follows the `CareTaskWriting` failure contract, so `CatDeletionFailure` can sort what it throws:
    /// - A commit failure throws the commit error. The delete is **not** rolled back: it stays staged
    ///   in the shared context, the cat already reads as gone, and the next successful save commits
    ///   it. No photo is deleted and no reminder is touched before `delete` returns; a watch does both
    ///   once that later save lands the delete, whoever makes it (#25).
    /// - `CareTaskRemindersOutOfSyncError` means the delete committed and the photos are gone, but
    ///   the reminders of the cat's tasks could not be brought in line.
    /// - A `CancellationError` after the commit passes through unwrapped; the delete stands, and the
    ///   next resync rebuilds the reminders from the store.
    @discardableResult
    func delete(_ cat: Cat, from modelContext: ModelContext) async throws -> DeletionSummary {
        let photoFileNames = cat.photoURLs
        let touchedTaskIds = cat.tasks.map(\.id)
        let deletedTaskIds = cat.tasks
            .filter { $0.assignedCats.count <= 1 }
            .map(\.id)
        let survivingTasks = cat.tasks.filter { $0.assignedCats.count > 1 }
        let catModelId = cat.persistentModelID
        // Decided before the delete: a cat that was never committed has no delete for a save to land.
        let wasCommitted = cat.modelContext != nil
            && modelContext.insertedModelsArray.contains { $0.persistentModelID == catModelId } == false

        for task in survivingTasks {
            task.assignedCats.removeAll { $0.id == cat.id }
        }

        modelContext.delete(cat)
        do {
            try saveContext(modelContext)
        } catch {
            Self.logger.error("Cat delete not committed, left staged: \(String(describing: error), privacy: .public)")
            if wasCommitted {
                watchForStagedDelete(
                    of: catModelId,
                    carrying: StagedCatDelete(photoFileNames: photoFileNames, touchedTaskIds: touchedTaskIds),
                    in: modelContext
                )
            }
            throw error
        }

        for photoFileName in photoFileNames {
            deletePhoto(photoFileName)
        }

        do {
            try await taskWriter.refreshReminders(for: touchedTaskIds, in: modelContext)
        } catch {
            // The commit is done, so no refresh failure may read as "not saved". The real writer
            // already wraps its own; anything it did not wrap is wrapped here.
            guard case .notSaved = CareTaskWriteFailure(error) else { throw error }
            Self.logger.error("Reminders stale after a cat delete: \(String(describing: error), privacy: .public)")
            throw CareTaskRemindersOutOfSyncError(taskIds: touchedTaskIds, underlyingError: error)
        }

        return DeletionSummary(
            deletedPhotoFileNames: photoFileNames,
            deletedTaskIds: deletedTaskIds
        )
    }

    /// Arms the context's watch for a failed delete. The save that lands it deletes the photo files the
    /// cat had — by name, never `deleteAllPhotos(for:)`, because a duplicated cat can share the files —
    /// and runs one full resync for every cat it lands, so the reminders of the cat's tasks stop
    /// carrying its name or firing for tasks the cascade deleted (#25). When that save is itself a
    /// writer verb, the verb resyncs too; the second pass is accepted.
    private func watchForStagedDelete(
        of catModelId: PersistentIdentifier,
        carrying stagedDelete: StagedCatDelete,
        in modelContext: ModelContext
    ) {
        StagedDeleteWatch.watch(
            catModelId,
            carrying: stagedDelete,
            in: modelContext,
            among: &Self.stagedDeleteWatches
        ) { [deletePhoto, taskWriter, weak modelContext] landedDeletes in
            for photoFileName in landedDeletes.flatMap(\.photoFileNames) {
                deletePhoto(photoFileName)
            }
            // A cat with no tasks brings no task IDs, and the writer skips the resync: no reminder
            // carried its name.
            guard let modelContext else { return }
            do {
                try await taskWriter.refreshReminders(
                    for: landedDeletes.flatMap(\.touchedTaskIds),
                    in: modelContext
                )
            } catch is CancellationError {
                // The next resync rebuilds the reminders from the store.
            } catch {
                Self.logger.error(
                    "Resync after a staged cat delete landed failed: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }
}
