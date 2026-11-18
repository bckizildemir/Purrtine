import Foundation

/// A wall-clock time with no day and no time zone: "9:30". A stated completion time travels as this,
/// never as an instant, because only the device knows the user's time zone. The writer puts it on the
/// named day with the device calendar.
nonisolated struct TimeOfDay: Hashable, Sendable {
    let hour: Int
    let minute: Int

    /// `nil` unless `hour` is 0...23 and `minute` is 0...59.
    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    /// Parses 24-hour "HH:mm" text, the form the cloud interpreter returns. `nil` for anything else.
    init?(text: String) {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts[0].count == 2, parts[1].count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        self.init(hour: hour, minute: minute)
    }

    /// The clock time of `instant` in `calendar`.
    init(of instant: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: instant)
        // A calendar always yields hour 0...23 and minute 0...59.
        self.hour = parts.hour ?? 0
        self.minute = parts.minute ?? 0
    }

    /// The instant this time falls on `day`, in `calendar`. A time that does not exist that day (a
    /// spring-forward gap: 02:30 on the night the clock jumps from 02:00 to 03:00) resolves to the next
    /// valid time, 03:00, not to nothing.
    func date(on day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: day,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }
}
