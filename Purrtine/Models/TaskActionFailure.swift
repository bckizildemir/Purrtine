import Foundation

/// A Tasks-tab action that did not save, and the message the caregiver sees for it.
///
/// The "saved, but reminders stale" case is not here: it has its own reminder warning.
enum TaskActionFailure: Equatable {
    /// A one-tap complete saved nothing. The task stays incomplete, so the caregiver can try again.
    case completionNotSaved

    /// A complete named a day that is not the one due now (a later day picked in the calendar, or a
    /// list that was out of date), so nothing was recorded. Trying again with the same day fails again.
    case occurrenceNotOpen

    /// A delete commit failed. The delete stays staged and lands on the next successful save, so the
    /// row stays removed and the message must not say the task was kept.
    case deletePending

    var title: String {
        switch self {
        case .completionNotSaved, .occurrenceNotOpen:
            String(localized: .errorDataSave)
        case .deletePending:
            String(localized: .tasksDeletePendingTitle)
        }
    }

    var message: String {
        switch self {
        case .completionNotSaved:
            String(localized: .errorDataSaveMessage)
        case .occurrenceNotOpen:
            String(localized: .errorTaskActionOccurrenceNotOpen)
        case .deletePending:
            String(localized: .tasksDeletePendingMessage)
        }
    }
}
