import Foundation
import Testing
@testable import Purrtine

@Suite
@MainActor
struct CompletionTimestampTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var date: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 21, minute: 51)) ?? .distantPast
    }

    @Test
    func turkishUsesAbbreviatedMonthNotNumericDate() {
        let locale = Locale(identifier: "tr_TR")
        let text = CompletionTimestamp.text(for: date, locale: locale, calendar: calendar)

        #expect(text == "7 Kas 2026 21:51")
        #expect(text.contains("07/11") == false)
    }

    @Test
    func englishUsesAbbreviatedMonth() {
        let locale = Locale(identifier: "en_US")
        let text = CompletionTimestamp.text(for: date, locale: locale, calendar: calendar)

        #expect(text.hasPrefix("Nov 7, 2026 "))
        #expect(text.contains("9:51"))
    }

    @Test(arguments: ["tr_TR", "en_US"])
    func dateStyleMatchesTextPrefix(identifier: String) {
        let locale = Locale(identifier: identifier)
        var style = CompletionTimestamp.dateStyle
        style.locale = locale
        style.calendar = calendar
        style.timeZone = calendar.timeZone

        let text = CompletionTimestamp.text(for: date, locale: locale, calendar: calendar)

        #expect(text.hasPrefix(date.formatted(style)))
    }
}
