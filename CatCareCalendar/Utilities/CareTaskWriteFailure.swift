import Foundation

/// What an error thrown by a `CareTaskWriting` verb means for the caller.
///
/// The writer's contract has three outcomes, and each one asks for a different response. Sort a
/// caught error with `init(_:)` and switch over the result, instead of hand-writing the catch order
/// "`CancellationError`, then `CareTaskRemindersOutOfSyncError`, then anything else".
///
/// `nonisolated` because it only reads an error: any caller, on any actor, can sort one.
nonisolated enum CareTaskWriteFailure {
    /// The work was cancelled. Show nothing: when the cancellation came after the commit, the write
    /// stands and the next resync rebuilds the reminders from the store.
    case cancelled

    /// The write committed, but its reminders could not be brought in line. The action stands, so
    /// warn about the reminders and never offer a retry, which would record the action twice.
    case remindersStale(CareTaskRemindersOutOfSyncError)

    /// Nothing was saved.
    case notSaved(any Error)

    init(_ error: any Error) {
        switch error {
        case is CancellationError:
            self = .cancelled
        case let staleError as CareTaskRemindersOutOfSyncError:
            self = .remindersStale(staleError)
        default:
            self = .notSaved(error)
        }
    }
}
