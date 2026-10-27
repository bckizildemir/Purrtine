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
    /// 59 of iOS's 64 slots: 59 reminders + 1 nudge slot + 4 snooze slots = 64. The snoozes sit
    /// outside this budget; the nudge is scheduled only when the selection is full (see `nudgeFireDate`).
    static let limit = 59

    /// How long before the last selected reminder the nudge fires: 24 hours.
    private static let nudgeLeadTime: TimeInterval = 24 * 3_600

    /// When the "open the app" nudge should fire, or `nil` for none.
    ///
    /// The set may run out only when it is full, so a selection shorter than `limit` gets no nudge.
    /// The nudge fires `nudgeLeadTime` before the last selected reminder. If that moment is not in the
    /// future, there is no nudge: a dense schedule must not nudge an active caregiver right after every open.
    static func nudgeFireDate(
        selected: [CareTaskReminderCandidate],
        now: Date,
        limit: Int = limit
    ) -> Date? {
        guard selected.count == limit, let lastFireDate = selected.map(\.fireDate).max() else { return nil }
        let fireDate = lastFireDate.addingTimeInterval(-nudgeLeadTime)
        return fireDate > now ? fireDate : nil
    }

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
