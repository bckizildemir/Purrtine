import Foundation

/// The one date and time style for completion timestamps, shared by History and Home Routine status.
enum CompletionTimestamp {
    /// Day, month and year in the locale's own order, for example "7 Kas 2026" or "Nov 7, 2026".
    static var dateStyle: Date.FormatStyle {
        .dateTime.day().month().year()
    }

    /// Hour and minute in the locale's own clock style.
    static var timeStyle: Date.FormatStyle {
        .dateTime.hour().minute()
    }

    /// Date and time in one string, for places that show them together.
    static func text(for date: Date, locale: Locale = .current, calendar: Calendar = .current) -> String {
        var dateStyle = dateStyle
        var timeStyle = timeStyle
        dateStyle.locale = locale
        dateStyle.calendar = calendar
        dateStyle.timeZone = calendar.timeZone
        timeStyle.locale = locale
        timeStyle.calendar = calendar
        timeStyle.timeZone = calendar.timeZone
        return "\(date.formatted(dateStyle)) \(date.formatted(timeStyle))"
    }
}
