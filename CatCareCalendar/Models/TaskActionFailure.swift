import Foundation

/// A Tasks-tab action that did not save, and the message the caregiver sees for it.
///
/// The "saved, but reminders stale" case is not here: it has its own reminder warning.
enum TaskActionFailure: Equatable {
    /// A one-tap complete saved nothing. The task stays incomplete, so the caregiver can try again.
    case completionNotSaved

    /// A delete commit failed. The delete stays staged and lands on the next successful save, so the
    /// row stays removed and the message must not say the task was kept.
    case deletePending

    var title: String {
        switch self {
        case .completionNotSaved:
            String(localized: .errorDataSave)
        case .deletePending:
            String(localized: .tasksDeletePendingTitle)
        }
    }

    var message: String {
        switch self {
        case .completionNotSaved:
            String(localized: .errorDataSaveMessage)
        case .deletePending:
            String(localized: .tasksDeletePendingMessage)
        }
    }
}
