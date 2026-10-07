import Foundation
import Testing
@testable import CatCareCalendar

@Suite
struct OverdueDisplayTests {
    private let reference = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func due(secondsAgo seconds: TimeInterval) -> Date {
        reference.addingTimeInterval(-seconds)
    }

    @Test
    func returnsNilWhenNotOverdue() {
        #expect(OverdueDisplay.text(dueDate: reference, relativeTo: reference) == nil)
        #expect(OverdueDisplay.text(dueDate: reference.addingTimeInterval(60), relativeTo: reference) == nil)
    }

    @Test
    func showsJustOverdueUnderOneHour() {
        #expect(OverdueDisplay.text(dueDate: due(secondsAgo: 1), relativeTo: reference)
            == String(localized: .tasksRowJustOverdue))
        #expect(OverdueDisplay.text(dueDate: due(secondsAgo: 59 * 60), relativeTo: reference)
            == String(localized: .tasksRowJustOverdue))
    }

    @Test
    func showsSingularHourAtExactlyOneHour() {
        #expect(OverdueDisplay.text(dueDate: due(secondsAgo: 60 * 60), relativeTo: reference)
            == String(localized: .tasksRowHourOverdue))
    }

    @Test
    func showsHoursBetweenOneAndTwentyFourHours() {
        #expect(OverdueDisplay.text(dueDate: due(secondsAgo: 5 * 60 * 60), relativeTo: reference)
            == String(localized: .tasksRowHoursOverdue(5)))
        #expect(OverdueDisplay.text(dueDate: due(secondsAgo: 23 * 60 * 60), relativeTo: reference)
            == String(localized: .tasksRowHoursOverdue(23)))
    }

    @Test
    func showsSingularDayAtExactlyTwentyFourHours() {
        #expect(OverdueDisplay.text(dueDate: due(secondsAgo: 24 * 60 * 60), relativeTo: reference)
            == String(localized: .tasksRowDayOverdue))
        // 25 and 47 hours are still one whole day elapsed.
        #expect(OverdueDisplay.text(dueDate: due(secondsAgo: 47 * 60 * 60), relativeTo: reference)
            == String(localized: .tasksRowDayOverdue))
    }

    @Test
    func showsDayCountForMultipleDays() {
        #expect(OverdueDisplay.text(dueDate: due(secondsAgo: 48 * 60 * 60), relativeTo: reference)
            == String(localized: .tasksRowDaysOverdue(2)))
        #expect(OverdueDisplay.text(dueDate: due(secondsAgo: 10 * 24 * 60 * 60), relativeTo: reference)
            == String(localized: .tasksRowDaysOverdue(10)))
    }
}
