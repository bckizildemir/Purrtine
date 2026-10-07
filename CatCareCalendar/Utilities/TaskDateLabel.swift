import Foundation

extension Date {
    /// A relative day name when the date is near today, otherwise a localized long date.
    ///
    /// The date rows of the add-task and edit-task sheets both read this, so the rule lives here
    /// rather than on either sheet's section view.
    ///
    /// The year is included only when the date falls outside the current year, and no locale is
    /// forced: the string is display-only and is never parsed back into a `Date`.
    var taskDayLabel: String {
        let calendar = Calendar.current
        let today = Date.now

        if calendar.isDate(self, inSameDayAs: today) {
            return String(localized: .tasksConfigTodayLabel)
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(self, inSameDayAs: tomorrow) {
            return String(localized: .tasksConfigTomorrowLabel)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(self, inSameDayAs: yesterday) {
            return String(localized: .tasksConfigYesterdayLabel)
        }

        let isSameYear = calendar.component(.year, from: self) == calendar.component(.year, from: today)
        return isSameYear
            ? formatted(.dateTime.day().month(.wide).weekday(.wide))
            : formatted(.dateTime.day().month(.wide).year().weekday(.wide))
    }
}
