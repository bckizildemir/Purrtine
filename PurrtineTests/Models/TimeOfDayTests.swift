import Foundation
import Testing
@testable import Purrtine

struct TimeOfDayTests {
    @Test(arguments: [
        (text: "09:00", hour: 9, minute: 0),
        (text: "00:00", hour: 0, minute: 0),
        (text: "23:59", hour: 23, minute: 59),
        (text: "21:30", hour: 21, minute: 30)
    ])
    func parsesTwentyFourHourText(text: String, hour: Int, minute: Int) {
        #expect(TimeOfDay(text: text) == TimeOfDay(hour: hour, minute: minute))
    }

    @Test(arguments: ["9:00", "24:00", "12:60", "09:00:00", "9 am", "", "0900", "2026-11-17T09:00:00Z", "ab:cd", "-1:00"])
    func refusesAnythingThatIsNotTwentyFourHourText(text: String) {
        #expect(TimeOfDay(text: text) == nil)
    }

    @Test(arguments: [(hour: -1, minute: 0), (hour: 24, minute: 0), (hour: 0, minute: 60), (hour: 0, minute: -1)])
    func refusesAnOutOfRangeClockTime(hour: Int, minute: Int) {
        #expect(TimeOfDay(hour: hour, minute: minute) == nil)
    }

    @Test
    func putsTheTimeOnTheGivenDayInTheGivenCalendar() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 17)))

        let date = try #require(TimeOfDay(hour: 9, minute: 30)?.date(on: day, calendar: calendar))

        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        #expect(parts.year == 2026 && parts.month == 11 && parts.day == 17)
        #expect(parts.hour == 9 && parts.minute == 30 && parts.second == 0)
    }

    /// America/New_York springs forward on 2026-03-08: 02:00 jumps to 03:00, so 02:30 does not exist.
    /// The stated time resolves to the next valid time on that same day instead of to nothing.
    @Test
    func aTimeInASpringForwardGapResolvesToTheNextValidTimeThatDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))

        let date = try #require(TimeOfDay(hour: 2, minute: 30)?.date(on: day, calendar: calendar))

        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        #expect(parts.year == 2026 && parts.month == 3 && parts.day == 8)
        #expect(parts.hour == 3 && parts.minute == 0)
    }

    @Test
    func readsTheClockTimeOfAnInstant() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Istanbul"))
        let instant = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 7, minute: 5)))

        #expect(TimeOfDay(of: instant, calendar: calendar) == TimeOfDay(hour: 7, minute: 5))
    }
}
