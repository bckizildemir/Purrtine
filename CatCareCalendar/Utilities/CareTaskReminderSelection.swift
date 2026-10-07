import Foundation

/// One reminder a full resync could schedule: a series occurrence or an overdue follow-up.
struct CareTaskReminderCandidate {
    /// Stable per occurrence, so two passes over the same store produce the same identifiers.
    let identifier: String
    let fireDate: Date
    let info: NotificationScheduleInfo
    let isOverdue: Bool
}

/// Picks which care-task reminders get one of iOS's pending-request slots.
///
/// iOS keeps only the 64 soonest pending requests per app and silently drops the rest, so the
/// resync has to choose before it adds anything. The selection is global — across every task —
/// because a per-task cap cannot know the total.
enum CareTaskReminderSelection {
    /// 60 of iOS's 64 slots; the other 4 stay free for snooze requests, which sit outside this budget.
    static let limit = 60

    /// The `limit` soonest candidates, soonest first. A tie breaks by identifier, so the result does
    /// not depend on the order the store returned the tasks in.
    static func soonest(
        _ candidates: some Sequence<CareTaskReminderCandidate>,
        limit: Int = limit
    ) -> [CareTaskReminderCandidate] {
        let sorted = candidates.sorted {
            ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier)
        }
        return Array(sorted.prefix(limit))
    }
}
