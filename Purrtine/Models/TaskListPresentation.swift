import Foundation

struct TaskListSection: Identifiable {
    let key: TaskListSectionKey
    let tasks: [CareTask]

    var id: TaskListSectionKey { key }
    var title: String { key.title }
}

enum TaskListSectionKey: String, CaseIterable, Identifiable {
    case overdue
    case today
    case tomorrow
    case thisWeek
    case later
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overdue:
            return String(localized: .tasksFilterOverdue)
        case .today:
            return String(localized: .tasksFilterToday)
        case .tomorrow:
            return String(localized: .timeTomorrow)
        case .thisWeek:
            return String(localized: .timeThisWeek)
        case .later:
            return String(localized: .tasksSectionLater)
        case .completed:
            return String(localized: .tasksFilterCompleted)
        }
    }

    static func orderedKeys(for filter: CareTaskFilter) -> [TaskListSectionKey] {
        switch filter {
        case .all:
            return [.overdue, .today, .tomorrow, .thisWeek, .later, .completed]
        case .overdue:
            return [.overdue]
        case .today:
            return [.today]
        case .upcoming:
            return [.tomorrow, .thisWeek, .later]
        case .completed:
            return [.completed]
        }
    }
}

enum TaskListDerivation {
    /// Day thresholds computed once per derivation call, instead of inside `sectionKey`/`matches`
    /// (which used to run this Calendar math per task and twice per sort comparison).
    private struct DayBoundaries {
        let referenceDate: Date
        let startOfToday: Date
        let startOfTomorrow: Date
        let startOfDayAfterTomorrow: Date
        let endOfWeek: Date

        init(referenceDate: Date, calendar: Calendar = .current) {
            self.referenceDate = referenceDate
            let startOfToday = calendar.startOfDay(for: referenceDate)
            self.startOfToday = startOfToday
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? startOfToday
            self.startOfTomorrow = startOfTomorrow
            self.startOfDayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday) ?? startOfTomorrow
            self.endOfWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.end ?? startOfDayAfterTomorrow
        }
    }

    /// A task's derived values snapshotted once. `activeDueDate` in particular is expensive
    /// (it scans active schedules and does Calendar math), and used to be recomputed on every
    /// filter check, group lookup, and sort comparison.
    private struct DecoratedTask {
        let task: CareTask
        let activeDueDate: Date?
        let lastCompletionDate: Date?
        let isOverdue: Bool
        let status: CareTaskStatus
        let prioritySortOrder: Int
        let title: String

        init(_ task: CareTask) {
            self.task = task
            self.activeDueDate = task.activeDueDate
            self.lastCompletionDate = task.lastCompletionDate
            self.isOverdue = task.isOverdue
            self.status = task.status
            self.prioritySortOrder = task.priority.sortOrder
            self.title = task.title
        }
    }

    static func filteredTasks(
        from tasks: [CareTask],
        filter: CareTaskFilter,
        searchText: String = "",
        referenceDate: Date = Date()
    ) -> [CareTask] {
        let boundaries = DayBoundaries(referenceDate: referenceDate)
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let matching = tasks
            .map(DecoratedTask.init)
            .filter { matches($0, filter: filter, boundaries: boundaries) }
            .filter { matchesSearch($0.task, query: trimmedSearch) }

        // Cross-section ordering always uses the `.all` bucketing (as the original flat sort did).
        let order = TaskListSectionKey.orderedKeys(for: .all)
        return matching
            .map { ($0, sectionKey(for: $0, filter: .all, boundaries: boundaries)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 {
                    return (order.firstIndex(of: lhs.1) ?? 0) < (order.firstIndex(of: rhs.1) ?? 0)
                }
                return sortWithinSection(lhs.0, rhs.0, in: lhs.1)
            }
            .map { $0.0.task }
    }

    static func groupedSections(
        from tasks: [CareTask],
        filter: CareTaskFilter,
        searchText: String = "",
        referenceDate: Date = Date()
    ) -> [TaskListSection] {
        let boundaries = DayBoundaries(referenceDate: referenceDate)
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let matching = tasks
            .map(DecoratedTask.init)
            .filter { matches($0, filter: filter, boundaries: boundaries) }
            .filter { matchesSearch($0.task, query: trimmedSearch) }

        let grouped = Dictionary(grouping: matching) { decorated in
            sectionKey(for: decorated, filter: filter, boundaries: boundaries)
        }

        return TaskListSectionKey.orderedKeys(for: filter).compactMap { key in
            guard let group = grouped[key], group.isEmpty == false else { return nil }
            let sortedTasks = group
                .sorted { sortWithinSection($0, $1, in: key) }
                .map(\.task)
            return TaskListSection(key: key, tasks: sortedTasks)
        }
    }

    static func taskCounts(
        from tasks: [CareTask],
        referenceDate: Date = Date()
    ) -> [CareTaskFilter: Int] {
        let boundaries = DayBoundaries(referenceDate: referenceDate)
        // Decorate once, then count each filter over the same snapshots (was 5 full passes,
        // each recomputing every task's activeDueDate).
        let decorated = tasks.map(DecoratedTask.init)
        var counts: [CareTaskFilter: Int] = [:]
        for filter in CareTaskFilter.allCases {
            counts[filter] = decorated.reduce(into: 0) { partial, task in
                if matches(task, filter: filter, boundaries: boundaries) { partial += 1 }
            }
        }
        return counts
    }

    static func homeSections(from tasks: [CareTask], referenceDate: Date = Date()) -> [TaskListSection] {
        groupedSections(
            from: tasks,
            filter: .all,
            searchText: "",
            referenceDate: referenceDate
        )
        .filter { section in
            section.key == .overdue || section.key == .today
        }
    }

    private static func matches(_ task: DecoratedTask, filter: CareTaskFilter, boundaries: DayBoundaries) -> Bool {
        switch filter {
        case .all:
            return true
        case .overdue:
            return task.isOverdue
        case .today:
            guard let dueDate = task.activeDueDate else { return false }
            // Same calendar day as the reference date, i.e. within [startOfToday, startOfTomorrow).
            return dueDate >= boundaries.startOfToday
                && dueDate < boundaries.startOfTomorrow
                && task.isOverdue == false
        case .upcoming:
            guard let dueDate = task.activeDueDate else { return false }
            return dueDate >= boundaries.startOfTomorrow
        case .completed:
            return task.status == .completed
        }
    }

    private static func sectionKey(
        for task: DecoratedTask,
        filter: CareTaskFilter,
        boundaries: DayBoundaries
    ) -> TaskListSectionKey {
        if filter == .completed {
            return .completed
        }

        if task.status == .completed && task.activeDueDate == nil {
            return .completed
        }

        guard let dueDate = task.activeDueDate else {
            return .completed
        }

        if dueDate < boundaries.referenceDate {
            return .overdue
        } else if dueDate < boundaries.startOfTomorrow {
            return .today
        } else if dueDate < boundaries.startOfDayAfterTomorrow {
            return .tomorrow
        } else if dueDate < boundaries.endOfWeek {
            return .thisWeek
        } else {
            return .later
        }
    }

    private static func matchesSearch(_ task: CareTask, query: String) -> Bool {
        guard query.isEmpty == false else { return true }

        return task.title.localizedStandardContains(query)
            || (task.taskDescription?.localizedStandardContains(query) ?? false)
            || task.assignedCats.contains { $0.name.localizedStandardContains(query) }
            || task.category.displayName.localizedStandardContains(query)
    }

    private static func sortWithinSection(
        _ first: DecoratedTask,
        _ second: DecoratedTask,
        in section: TaskListSectionKey
    ) -> Bool {
        if section == .completed {
            let firstCompletion = first.lastCompletionDate ?? .distantPast
            let secondCompletion = second.lastCompletionDate ?? .distantPast
            if firstCompletion != secondCompletion {
                return firstCompletion > secondCompletion
            }
        } else {
            let firstDue = first.activeDueDate ?? .distantFuture
            let secondDue = second.activeDueDate ?? .distantFuture
            if firstDue != secondDue {
                return firstDue < secondDue
            }
        }

        if first.prioritySortOrder != second.prioritySortOrder {
            return first.prioritySortOrder < second.prioritySortOrder
        }

        return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
    }
}
