import Foundation

/// Why a day cannot be completed for a task. The completion rules decide it
/// (`TaskActionService.completionRefusal`); the calendar shows the reason in the row instead of
/// offering Complete and refusing with an alert.
enum CompletionDayRefusal: Equatable {
    /// A day after today.
    case dayAfterToday
    /// The day already has a completion.
    case alreadyDone
    /// A day before the task was created and before its open day.
    case beforeTaskExisted

    var message: String {
        switch self {
        case .dayAfterToday:
            String(localized: .taskCalendarRefusalDayAfterToday)
        case .alreadyDone:
            String(localized: .taskCalendarRefusalAlreadyDone)
        case .beforeTaskExisted:
            String(localized: .taskCalendarRefusalBeforeTaskExisted)
        }
    }
}
