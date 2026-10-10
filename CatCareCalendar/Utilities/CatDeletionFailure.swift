import Foundation

/// What a failed `CatDeletionService.delete` means to the caregiver. Either way the cat is gone from
/// the screen and stays gone, so neither message says "not deleted" (#19).
enum CatDeletionFailure: Hashable {
    /// The delete committed, but the reminders could not be brought in line with it.
    case remindersStale(catName: String)
    /// The commit failed. The delete stays staged in the shared context, and the next successful
    /// save commits it.
    case commitPending(catName: String)

    /// Sorts an error thrown by `CatDeletionService.delete` with the shared `CareTaskWriteFailure`.
    /// Returns `nil` for a cancellation: that arrives only after the commit, and the next resync
    /// rebuilds the reminders, so there is nothing to tell the caregiver.
    init?(error: any Error, catName: String) {
        switch CareTaskWriteFailure(error) {
        case .cancelled:
            return nil
        case .remindersStale:
            self = .remindersStale(catName: catName)
        case .notSaved:
            self = .commitPending(catName: catName)
        }
    }

    var title: String {
        switch self {
        case .remindersStale:
            String(localized: .errorReminderSchedule)
        case .commitPending:
            String(localized: .catDeletePendingSaveTitle)
        }
    }

    var message: String {
        switch self {
        case .remindersStale(let catName):
            String(localized: .catDeleteRemindersStaleMessage(catName))
        case .commitPending(let catName):
            String(localized: .catDeletePendingSaveMessage(catName))
        }
    }
}
