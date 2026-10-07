import Foundation
import SwiftData

/// Rebuilds the pending reminders for every task a cat is assigned to.
///
/// `NotificationManager` bakes the cat names into the reminder body at scheduling time
/// (`"title\n🐱 catNames"`), so the names in a pending reminder are a snapshot of whatever they were
/// when it was scheduled. Renaming a cat wrote the new name to the store and stopped there, leaving
/// every reminder announcing the old one until the task happened to be edited. Deletion already
/// refreshed the surviving tasks — see `CatDeletionService` — and this is the same mechanism for the
/// case that was missed.
@MainActor
struct CatReminderRefreshService {
    private let taskWriter: any CareTaskWriting

    init(taskWriter: any CareTaskWriting) {
        self.taskWriter = taskWriter
    }

    /// Call after the cat change is saved. A failure is logged rather than thrown: the cat change
    /// already stands, and the next resync rebuilds the reminders from the store.
    func refreshReminders(forTasksOf cat: Cat, in modelContext: ModelContext) async {
        do {
            try await taskWriter.refreshReminders(for: cat.tasks.map(\.id), in: modelContext)
        } catch is CancellationError {
            // The rename flow ended before the rebuild finished. Nothing to report.
        } catch {
            print("❌ Failed to refresh reminders after a cat rename: \(error.localizedDescription)")
        }
    }
}
