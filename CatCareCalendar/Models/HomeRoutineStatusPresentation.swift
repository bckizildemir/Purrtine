import Foundation

struct HomeRoutineStatusPresentation {
    struct Row: Identifiable, Equatable {
        let taskID: UUID
        let title: String
        let catNames: String?
        let primaryRecencyText: String
        let secondaryTimestampText: String
        let lastCompletionDate: Date?
        let dueStatusText: String
        let iconName: String

        var id: UUID { taskID }

        var accessibilityLabel: String {
            [title, catNames, primaryRecencyText, dueStatusText]
                .compactMap { value in
                    guard let value, value.isEmpty == false else { return nil }
                    return value
                }
                .joined(separator: ", ")
        }
    }

    /// A snapshot of the values that the sort and the row builder read from a task.
    ///
    /// The snapshot computes `sortPriority` and `activeDueDate` one time each. Without it, every
    /// sort comparison recomputes both values, and each row recomputes `activeDueDate` again.
    private struct DecoratedTask {
        let task: CareTask
        let activeDueDate: Date
        let lastCompletionDate: Date
        let sortPriority: Int
    }

    static func rows(
        from tasks: [CareTask],
        referenceDate: Date = Date(),
        locale: Locale = .current,
        calendar: Calendar = .current
    ) -> [Row] {
        tasks
            .compactMap { task -> DecoratedTask? in
                guard let activeSchedule = task.activeSchedule,
                      let lastCompletionDate = task.lastCompletionDate else { return nil }
                let dueDate = activeSchedule.effectiveDueDate
                return DecoratedTask(
                    task: task,
                    activeDueDate: dueDate,
                    lastCompletionDate: lastCompletionDate,
                    sortPriority: sortPriority(dueDate: dueDate, referenceDate: referenceDate, calendar: calendar)
                )
            }
            .sorted { sort($0, $1) }
            .map { decorated in
                let task = decorated.task
                return Row(
                    taskID: task.id,
                    title: task.title,
                    catNames: task.assignedCats.isEmpty ? nil : task.assignedCatNames,
                    primaryRecencyText: primaryRecencyText(
                        lastCompletionDate: decorated.lastCompletionDate,
                        referenceDate: referenceDate,
                        calendar: calendar
                    ),
                    secondaryTimestampText: secondaryTimestampText(
                        lastCompletionDate: decorated.lastCompletionDate,
                        locale: locale,
                        calendar: calendar
                    ),
                    lastCompletionDate: decorated.lastCompletionDate,
                    dueStatusText: dueStatusText(
                        dueDate: decorated.activeDueDate,
                        referenceDate: referenceDate,
                        calendar: calendar
                    ),
                    iconName: task.iconName
                )
            }
    }

    private static func sort(_ first: DecoratedTask, _ second: DecoratedTask) -> Bool {
        if first.sortPriority != second.sortPriority {
            return first.sortPriority < second.sortPriority
        }

        if first.sortPriority >= 4, first.lastCompletionDate != second.lastCompletionDate {
            return first.lastCompletionDate < second.lastCompletionDate
        }

        if first.activeDueDate != second.activeDueDate {
            return first.activeDueDate < second.activeDueDate
        }

        return first.task.title.localizedCaseInsensitiveCompare(second.task.title) == .orderedAscending
    }

    private static func sortPriority(
        dueDate: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let dueDay = calendar.startOfDay(for: dueDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday

        if dueDate < referenceDate || dueDay < startOfToday {
            return 1
        }
        if dueDay == startOfToday {
            return 2
        }
        if dueDay == tomorrow {
            return 3
        }
        return 4
    }

    private static func primaryRecencyText(
        lastCompletionDate: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> String {
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)
        let startOfCompletionDay = calendar.startOfDay(for: lastCompletionDate)
        let dayCount = max(
            calendar.dateComponents([.day], from: startOfCompletionDay, to: startOfReferenceDay).day ?? 0,
            0
        )

        let relativeText = dayCount == 0
            ? String(localized: .homeRoutineStatusToday)
            : String(localized: .homeRoutineStatusDaysAgo(Int32(dayCount)))

        return String(localized: .homeRoutineStatusLastDone(relativeText))
    }

    private static func secondaryTimestampText(
        lastCompletionDate: Date,
        locale: Locale,
        calendar: Calendar
    ) -> String {
        lastCompletionDate.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, calendar: calendar)
        )
    }

    private static func dueStatusText(
        dueDate: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> String {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let dueDay = calendar.startOfDay(for: dueDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday

        if let overdueText = OverdueDisplay.text(dueDate: dueDate, relativeTo: referenceDate) {
            return overdueText
        }

        if dueDay == startOfToday {
            return String(localized: .homeRoutineStatusDueToday)
        }

        if dueDay == tomorrow {
            return String(localized: .homeRoutineStatusDueTomorrow)
        }

        let daysUntilDue = max(calendar.dateComponents([.day], from: startOfToday, to: dueDay).day ?? 0, 0)
        return String(localized: .tasksRowDaysLater(Int32(daysUntilDue)))
    }
}
