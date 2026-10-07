import Foundation
import SwiftData

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

    private let taskWriter: any CareTaskWriting
    private let deletePhoto: (String) -> Void

    init(
        taskWriter: any CareTaskWriting,
        deletePhoto: @escaping (String) -> Void = { PhotoManager.shared.deletePhoto(at: $0) }
    ) {
        self.taskWriter = taskWriter
        self.deletePhoto = deletePhoto
    }

    /// Throws only when the cat could not be deleted. Once the delete commits, a reminder failure is
    /// logged rather than thrown: the cat is gone either way, and the next resync rebuilds the
    /// reminders from the store.
    @discardableResult
    func delete(_ cat: Cat, from modelContext: ModelContext) async throws -> DeletionSummary {
        let photoFileNames = cat.photoURLs
        let touchedTaskIds = cat.tasks.map(\.id)
        let deletedTaskIds = cat.tasks
            .filter { $0.assignedCats.count <= 1 }
            .map(\.id)
        let survivingTasks = cat.tasks.filter { $0.assignedCats.count > 1 }

        for task in survivingTasks {
            task.assignedCats.removeAll { $0.id == cat.id }
        }

        modelContext.delete(cat)
        try modelContext.save()

        for photoFileName in photoFileNames {
            deletePhoto(photoFileName)
        }

        do {
            try await taskWriter.refreshReminders(for: touchedTaskIds, in: modelContext)
        } catch is CancellationError {
            // The delete stands and the next resync rebuilds the reminders from the store.
        } catch {
            print("❌ Failed to refresh reminders after a cat delete: \(error.localizedDescription)")
        }

        return DeletionSummary(
            deletedPhotoFileNames: photoFileNames,
            deletedTaskIds: deletedTaskIds
        )
    }
}
