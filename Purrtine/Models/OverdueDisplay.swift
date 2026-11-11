import Foundation

/// Produces the localized "overdue" label shown on tasks that are past their due date.
///
/// Granularity is based on *elapsed time* since the due date rather than calendar-day
/// boundaries, so the phrasing degrades gracefully:
/// - under 1 hour  → "Just overdue"
/// - 1–23 hours    → "N hours overdue"
/// - 24 hours+     → "N days overdue"
///
/// This avoids the calendar-boundary artifacts of a day-only count (e.g. a task due
/// last night reading "1 day overdue" after only a couple of hours) and never emits a
/// "0 days overdue" string.
nonisolated enum OverdueDisplay {
    private static let secondsPerHour: TimeInterval = 60 * 60
    private static let secondsPerDay: TimeInterval = 24 * 60 * 60

    /// Returns the overdue label for `dueDate` relative to `referenceDate`, or `nil`
    /// when the task is not yet overdue (`dueDate >= referenceDate`).
    static func text(dueDate: Date, relativeTo referenceDate: Date) -> String? {
        let elapsed = referenceDate.timeIntervalSince(dueDate)
        guard elapsed > 0 else { return nil }

        if elapsed < secondsPerHour {
            return String(localized: .tasksRowJustOverdue)
        }

        if elapsed < secondsPerDay {
            let hours = Int(elapsed / secondsPerHour)
            return hours == 1
                ? String(localized: .tasksRowHourOverdue)
                : String(localized: .tasksRowHoursOverdue(Int32(hours)))
        }

        let days = max(Int(elapsed / secondsPerDay), 1)
        return days == 1
            ? String(localized: .tasksRowDayOverdue)
            : String(localized: .tasksRowDaysOverdue(Int32(days)))
    }
}
