import Foundation

/// The write committed, but the reminders of `taskIds` could not be brought in line with it.
///
/// Thrown only after the commit, so a caller reads it as "saved, reminders stale" — never as
/// "not saved". It carries the scheduler's own error so the existing alerts keep their text.
struct CareTaskRemindersOutOfSyncError: LocalizedError {
    let taskIds: [UUID]
    let underlyingError: any Error

    var errorDescription: String? {
        underlyingError.localizedDescription
    }
}
