import Foundation

/// A Tasks-tab action that did not save, and the message the caregiver sees for it.
///
/// The "saved, but reminders stale" case is not here: it has its own reminder warning.
enum TaskActionFailure: Equatable {
    /// A one-tap complete saved nothing. The task stays incomplete, so the caregiver can try again.
    case completionNotSaved

    /// A complete was refused, so nothing was recorded: the day is after today, already has a
    /// completion, or is no longer due (a list or reminder that was out of date). Trying again with
    /// the same day fails again.
    case occurrenceNotOpen

    /// A complete for a named day was refused and the rules know why (the calendar's race: the row was
    /// shown, then the day became refused). The alert says that reason instead of the catch-all.
    case dayRefused(CompletionDayRefusal)

    /// A delete commit failed. The delete stays staged and lands on the next successful save, so the
    /// row stays removed and the message must not say the task was kept.
    case deletePending

    var title: String {
        switch self {
        case .completionNotSaved:
            String(localized: .errorDataSave)
        case .occurrenceNotOpen, .dayRefused:
            String(localized: .errorTaskActionOccurrenceNotOpenTitle)
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
        case .dayRefused(let refusal):
            refusal.message
        case .deletePending:
            String(localized: .tasksDeletePendingMessage)
        }
    }
}
