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
    /// outside this budget; the nudge is scheduled whenever a reminder series is cut short (see `nudgeFireDate`).
    static let limit = 59

    /// How long before the earliest cut end the nudge fires: 24 hours.
    private static let nudgeLeadTime: TimeInterval = 24 * 3_600

    /// When the "open the app" nudge should fire, or `nil` for none.
    ///
    /// Reminders run out when something cut them short: the `limit` dropped candidates, or a series'
    /// own cap stopped it before its natural end. With no cut, nothing runs out and there is no nudge.
    /// Otherwise the nudge fires `nudgeLeadTime` before the EARLIEST of the last selected reminder and the
    /// last reminder of every series cut by its own cap, because the caregiver must return before the
    /// first of them goes quiet. If that moment has already passed, the nudge fires at the midpoint
    /// between `now` and that earliest end instead. Each resync recomputes it, so the nudge moves
    /// ahead of an active caregiver and never fires on every app open.
    ///
    /// - Parameters:
    ///   - selected: The reminders kept by `soonest(_:limit:)`.
    ///   - candidateCount: How many candidates there were before the limit; more than `selected.count`
    ///     means the limit cut the set.
    ///   - cappedSeriesEnds: For each series cut by its own cap, the fire date of its last produced reminder.
    ///   - now: Injected so tests control the clock.
    static func nudgeFireDate(
        selected: [CareTaskReminderCandidate],
        candidateCount: Int,
        cappedSeriesEnds: [Date],
        now: Date
    ) -> Date? {
        let isCutByLimit = candidateCount > selected.count
        guard isCutByLimit || cappedSeriesEnds.isEmpty == false else { return nil }

        var ends = cappedSeriesEnds
        if let lastSelected = selected.map(\.fireDate).max() {
            ends.append(lastSelected)
        }
        guard let earliestEnd = ends.min(), earliestEnd > now else { return nil }

        let leadDate = earliestEnd.addingTimeInterval(-nudgeLeadTime)
        if leadDate > now { return leadDate }
        let midpoint = now.addingTimeInterval(earliestEnd.timeIntervalSince(now) / 2)
        return midpoint > now ? midpoint : nil
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
