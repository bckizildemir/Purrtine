import Foundation
import SwiftData

// MARK: - CareTask Model
@Model
final class CareTask: Hashable {
    var id: UUID
    var title: String
    var taskDescription: String?
    var category: CareTaskCategory
    var iconName: String
    var priority: CareTaskPriority
    var status: CareTaskStatus
    var isTemplate: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \CareTaskSchedule.task) var schedules: [CareTaskSchedule] = []
    @Relationship(deleteRule: .cascade, inverse: \CareTaskCompletion.task) var completions: [CareTaskCompletion] = []
    @Relationship(inverse: \Cat.tasks) var assignedCats: [Cat] = []
    @Relationship var assignedCaregiver: Caregiver?
    
    init(
        title: String,
        description: String? = nil,
        category: CareTaskCategory = .general,
        iconName: String = "circle",
        priority: CareTaskPriority = .medium,
        status: CareTaskStatus = .pending,
        isTemplate: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.taskDescription = description
        self.category = category
        self.iconName = iconName
        self.priority = priority
        self.status = status
        self.isTemplate = isTemplate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - CareTask Schedule Model
@Model
final class CareTaskSchedule: Hashable {
    var id: UUID
    var scheduledDate: Date
    var scheduledTime: Date?
    var frequency: CareTaskFrequency
    var frequencyInterval: Int // For custom frequencies (every X days/weeks)
    var endDate: Date?
    var isActive: Bool
    var reminderMinutes: Int? // Minutes before task time to remind
    var customDays: [Int]? // For weekly tasks (0=Sunday, 1=Monday, etc.)
    var createdAt: Date
    
    // Relationship
    @Relationship var task: CareTask?
    
    init(
        scheduledDate: Date,
        scheduledTime: Date? = nil,
        frequency: CareTaskFrequency = .once,
        frequencyInterval: Int = 1,
        endDate: Date? = nil,
        reminderMinutes: Int? = nil,
        customDays: [Int]? = nil
    ) {
        self.id = UUID()
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
        self.frequency = frequency
        self.frequencyInterval = frequencyInterval
        self.endDate = endDate
        self.isActive = true
        self.reminderMinutes = reminderMinutes
        self.customDays = customDays
        self.createdAt = Date()
    }
}

// MARK: - CareTask Completion Model
@Model
final class CareTaskCompletion: Hashable {
    // Indexes for the history/settings queries that sort or filter on completion dates.
    #Index<CareTaskCompletion>([\.completedAt], [\.completedForDate])

    var id: UUID
    var completedAt: Date
    var completedForDate: Date // The date this completion is for (e.g., which occurrence was completed)
    var notes: String?
    var photoURLs: [String] // For proof/documentation photos
    var wasOnTime: Bool
    var completionDuration: TimeInterval? // How long task took

    // Relationships
    @Relationship var task: CareTask?
    @Relationship(deleteRule: .nullify) var cats: [Cat] = []
    @Relationship var caregiver: Caregiver?

    init() {
        self.id = UUID()
        self.completedAt = Date()
        self.completedForDate = Calendar.current.startOfDay(for: Date())
        self.notes = nil
        self.photoURLs = []
        self.wasOnTime = true
        self.completionDuration = nil
    }

    init(
        completedAt: Date = Date(),
        completedForDate: Date = Calendar.current.startOfDay(for: Date()),
        notes: String? = nil,
        photoURLs: [String] = [],
        wasOnTime: Bool = true,
        completionDuration: TimeInterval? = nil
    ) {
        self.id = UUID()
        self.completedAt = completedAt
        self.completedForDate = Calendar.current.startOfDay(for: completedForDate)
        self.notes = notes
        self.photoURLs = photoURLs
        self.wasOnTime = wasOnTime
        self.completionDuration = completionDuration
    }
}

// MARK: - Enums
nonisolated enum CareTaskCategory: String, CaseIterable, Codable, Hashable {
    case feeding = "feeding"
    case water = "water"
    case medication = "medication"
    case grooming = "grooming"
    case health = "health"
    case exercise = "exercise"
    case litter = "litter"
    case vet = "vet"
    case general = "general"
    
    var displayName: String {
        switch self {
        case .feeding: return String(localized: .taskCategoryFeeding)
        case .water: return String(localized: .taskCategoryWater)
        case .medication: return String(localized: .taskCategoryMedication)
        case .grooming: return String(localized: .taskCategoryGrooming)
        case .health: return String(localized: .taskCategoryHealth)
        case .exercise: return String(localized: .taskCategoryExercise)
        case .litter: return String(localized: .taskCategoryLitter)
        case .vet: return String(localized: .taskCategoryVet)
        case .general: return String(localized: .taskCategoryGeneral)
        }
    }
    
    var iconName: String {
        switch self {
        case .feeding: return "fork.knife"
        case .water: return "drop.halffull"
        case .medication: return "pills.fill"
        case .grooming: return "comb.fill"
        case .health: return "heart.fill"
        case .exercise: return "figure.run"
        case .litter: return "tray.fill"
        case .vet: return "stethoscope.circle.fill"
        case .general: return "circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .feeding: return "systemOrange"
        case .water: return "systemBlue"
        case .medication: return "systemRed"
        case .grooming: return "systemturquoise"
        case .health: return "systemPink"
        case .exercise: return "systemGreen"
        case .litter: return "systemBrown"
        case .vet: return "systemPurple"
        case .general: return "systemGray"
        }
    }
}

enum CareTaskPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var displayName: String {
        switch self {
        case .low: return String(localized: .taskPriorityLow)
        case .medium: return String(localized: .taskPriorityMedium)
        case .high: return String(localized: .taskPriorityHigh)
        case .urgent: return String(localized: .taskPriorityUrgent)
        }
    }
    
    var color: String {
        switch self {
        case .low: return "systemGray"
        case .medium: return "systemBlue"
        case .high: return "systemOrange"
        case .urgent: return "systemRed"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

enum CareTaskStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case overdue = "overdue"
    case postponed = "postponed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return String(localized: .taskStatusPending)
        case .inProgress: return String(localized: .taskStatusInProgress)
        case .completed: return String(localized: .taskStatusCompleted)
        case .overdue: return String(localized: .tasksFilterOverdue)
        case .postponed: return String(localized: .taskPostpone)
        case .cancelled: return String(localized: .taskStatusCancelled)
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "systemGray"
        case .inProgress: return "systemBlue"
        case .completed: return "systemGreen"
        case .overdue: return "systemRed"
        case .postponed: return "systemOrange"
        case .cancelled: return "systemGray2"
        }
    }
}

enum CareTaskFrequency: String, CaseIterable, Codable {
    case once = "once"
    case daily = "daily"
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .once: return String(localized: .taskFrequencyOnce)
        case .daily: return String(localized: .taskFrequencyDaily)
        case .weekly: return String(localized: .taskFrequencyWeekly)
        case .biweekly: return String(localized: .taskFrequencyBiweekly)
        case .monthly: return String(localized: .taskFrequencyMonthly)
        case .custom: return String(localized: .taskFrequencyCustom)
        }
    }
}

// MARK: - Caregiver Model
enum CaregiverRole: String, Codable, CaseIterable {
    case primary
    case member
}

@Model
final class Caregiver: Hashable {
    var id: UUID
    var name: String
    var avatarURL: String?   // isteğe bağlı
    var createdAt: Date
    var role: CaregiverRole
    var localizationKey: String?

    // İlişkiler
    @Relationship(inverse: \CareTaskCompletion.caregiver)
    var completions: [CareTaskCompletion] = []

    init(
        name: String,
        avatarURL: String? = nil,
        role: CaregiverRole = .member,
        localizationKey: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.avatarURL = avatarURL
        self.createdAt = Date()
        self.role = role
        self.localizationKey = localizationKey
    }

    var displayName: String {
        localizationKey?.localizedDataKey ?? name
    }

    var isPrimary: Bool {
        role == .primary
    }
}

// MARK: - CareTask Extensions
extension CareTask {
    var activeSchedules: [CareTaskSchedule] {
        schedules.filter(\.isActive)
    }

    var activeSchedule: CareTaskSchedule? {
        activeSchedules.min { first, second in
            first.effectiveDueDate < second.effectiveDueDate
        }
    }

    var activeDueDate: Date? {
        activeSchedule?.effectiveDueDate
    }

    var isOverdue: Bool {
        guard status == .pending || status == .inProgress || status == .overdue else { return false }
        guard let activeDueDate else { return false }
        return activeDueDate < Date()
    }
    
    var isRecurring: Bool {
        activeSchedules.contains { schedule in
            schedule.frequency != .once
        }
    }
    
    var nextDueDate: Date? {
        activeDueDate
    }
    
    var lastCompletion: CareTaskCompletion? {
        completions.max { first, second in
            first.completedAt < second.completedAt
        }
    }

    var lastCompletionDate: Date? {
        lastCompletion?.completedAt
    }
    
    var completionCount: Int {
        completions.count
    }
    
    var assignedCatNames: String {
        if assignedCats.isEmpty {
            return String(localized: .tasksConfigAllCats)
        }
        return assignedCats.map { $0.name }.joined(separator: ", ")
    }

    func dueDisplayText(relativeTo referenceDate: Date = Date()) -> String {
        if let scheduledTime = activeSchedule?.scheduledTime {
            return scheduledTime.formatted(date: .omitted, time: .shortened)
        }

        guard let dueDate = activeDueDate else { return "" }

        if let overdueText = OverdueDisplay.text(dueDate: dueDate, relativeTo: referenceDate) {
            return overdueText
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        if calendar.isDateInToday(dueDate) {
            return String(localized: .generalToday)
        } else if calendar.isDateInTomorrow(dueDate) {
            return String(localized: .timeTomorrow)
        } else {
            let days = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
            return String(localized: .tasksRowDaysLater(Int32(days)))
        }
    }

    func lastCompletionDisplayText(relativeTo referenceDate: Date = Date()) -> String {
        guard let lastCompletion else {
            return String(localized: .tasksRowNoCompletionsYet)
        }

        let calendar = Calendar.current

        let completedAt = lastCompletion.completedAt
        let dateText: String
        if calendar.isDateInToday(completedAt) {
            dateText = String(localized: .generalToday)
        } else if calendar.isDateInYesterday(completedAt) {
            dateText = String(localized: .timeYesterday)
        } else {
            // Note: legacy `.short` used a locale-dependent 2-digit year for en_US;
            // `.numeric` always uses 4 digits. Accepted behavior change, only shown
            // for completions ≥2 days old and not covered by any test.
            dateText = completedAt.formatted(date: .numeric, time: .omitted)
        }

        return String(localized: .tasksRowLastCompleted(dateText, completedAt.formatted(date: .omitted, time: .shortened)))
    }
    
    // MARK: - Hashable Conformance
    static func == (lhs: CareTask, rhs: CareTask) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension CareTaskSchedule {
    /// Combines date and time into a single due date. Date-only schedules resolve to end-of-day.
    var effectiveDueDate: Date {
        let calendar = Calendar.current
        
        if let scheduledTime {
            let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: scheduledTime)
            return calendar.date(
                bySettingHour: timeComponents.hour ?? 0,
                minute: timeComponents.minute ?? 0,
                second: timeComponents.second ?? 0,
                of: scheduledDate
            ) ?? scheduledDate
        }
        
        let startOfDay = calendar.startOfDay(for: scheduledDate)
        // End of day is start + 1 day - 1 second (23:59:59)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? scheduledDate
    }
    
    var nextOccurrence: Date? {
        return nextOccurrence(from: Date())
    }

    var followingOccurrence: Date? {
        followingOccurrence(after: scheduledDate)
    }

    func nextOccurrence(
        from referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard isActive else { return nil }
        guard let nextDate = occurrence(
            relativeTo: referenceDate,
            includesReference: true,
            calendar: calendar
        ) else {
            return nil
        }
        guard endDate.map({ nextDate <= $0 }) ?? true else { return nil }
        return nextDate
    }

    func followingOccurrence(
        after referenceDate: Date,
        calendar: Calendar = .current
    ) -> Date? {
        guard isActive, frequency != .once else { return nil }
        guard let nextDate = occurrence(
            relativeTo: referenceDate,
            includesReference: false,
            calendar: calendar
        ) else {
            return nil
        }
        guard endDate.map({ nextDate <= $0 }) ?? true else { return nil }
        return nextDate
    }

    private func occurrence(
        relativeTo referenceDate: Date,
        includesReference: Bool,
        calendar: Calendar
    ) -> Date? {
        switch frequency {
        case .once:
            return qualifies(
                scheduledDate,
                relativeTo: referenceDate,
                includesReference: includesReference
            ) ? scheduledDate : nil

        case .daily:
            return fixedIntervalOccurrence(
                component: .day,
                unitsPerOccurrence: max(1, frequencyInterval),
                relativeTo: referenceDate,
                includesReference: includesReference,
                calendar: calendar
            )

        case .weekly:
            let validCustomDays = customDays?.filter { (0...6).contains($0) } ?? []
            if validCustomDays.isEmpty == false {
                return customWeeklyOccurrence(
                    onDays: validCustomDays,
                    relativeTo: referenceDate,
                    includesReference: includesReference,
                    calendar: calendar
                )
            }
            return fixedIntervalOccurrence(
                component: .weekOfYear,
                unitsPerOccurrence: max(1, frequencyInterval),
                relativeTo: referenceDate,
                includesReference: includesReference,
                calendar: calendar
            )

        case .biweekly:
            let (weekInterval, overflowed) = max(1, frequencyInterval)
                .multipliedReportingOverflow(by: 2)
            guard overflowed == false else { return nil }
            return fixedIntervalOccurrence(
                component: .weekOfYear,
                unitsPerOccurrence: weekInterval,
                relativeTo: referenceDate,
                includesReference: includesReference,
                calendar: calendar
            )

        case .monthly:
            return fixedIntervalOccurrence(
                component: .month,
                unitsPerOccurrence: max(1, frequencyInterval),
                relativeTo: referenceDate,
                includesReference: includesReference,
                calendar: calendar
            )

        case .custom:
            return fixedIntervalOccurrence(
                component: .day,
                unitsPerOccurrence: max(1, frequencyInterval),
                relativeTo: referenceDate,
                includesReference: includesReference,
                calendar: calendar
            )
        }
    }

    /// Calculates from the original schedule anchor, avoiding both cadence drift and an
    /// occurrence-by-occurrence walk through years of history.
    private func fixedIntervalOccurrence(
        component: Calendar.Component,
        unitsPerOccurrence: Int,
        relativeTo referenceDate: Date,
        includesReference: Bool,
        calendar: Calendar
    ) -> Date? {
        guard unitsPerOccurrence > 0 else { return nil }

        let elapsedUnits = max(
            0,
            calendar.dateComponents([component], from: scheduledDate, to: referenceDate)
                .value(for: component) ?? 0
        )
        var occurrenceIndex = elapsedUnits / unitsPerOccurrence

        // Calendar date-component differences can round down around short months and DST.
        // Starting from their estimate means at most a small constant number of adjustments.
        for _ in 0..<3 {
            let (units, overflowed) = occurrenceIndex
                .multipliedReportingOverflow(by: unitsPerOccurrence)
            guard overflowed == false,
                  let candidate = calendar.date(
                    byAdding: component,
                    value: units,
                    to: scheduledDate
                  ) else {
                return nil
            }
            if qualifies(
                candidate,
                relativeTo: referenceDate,
                includesReference: includesReference
            ) {
                return candidate
            }
            let (nextIndex, indexOverflowed) = occurrenceIndex.addingReportingOverflow(1)
            guard indexOverflowed == false else { return nil }
            occurrenceIndex = nextIndex
        }
        return nil
    }

    private func customWeeklyOccurrence(
        onDays days: [Int],
        relativeTo referenceDate: Date,
        includesReference: Bool,
        calendar: Calendar
    ) -> Date? {
        let anchorWeek = weekStart(for: scheduledDate, calendar: calendar)
        let referenceWeek = weekStart(for: max(referenceDate, scheduledDate), calendar: calendar)

        let weekInterval = max(1, frequencyInterval)
        let elapsedWeeks = max(
            0,
            calendar.dateComponents(
                [.weekOfYear],
                from: anchorWeek,
                to: referenceWeek
            ).weekOfYear ?? 0
        )
        let completedIntervals = elapsedWeeks / weekInterval
        let (initialActiveWeek, initialOverflowed) = completedIntervals
            .multipliedReportingOverflow(by: weekInterval)
        guard initialOverflowed == false else { return nil }
        var activeWeekOffset = initialActiveWeek
        if activeWeekOffset < elapsedWeeks {
            let (nextOffset, overflowed) = activeWeekOffset
                .addingReportingOverflow(weekInterval)
            guard overflowed == false else { return nil }
            activeWeekOffset = nextOffset
        }

        let time = calendar.dateComponents([.hour, .minute, .second], from: scheduledDate)
        // Three tries, not two. A correct search needs at most two active weeks — the reference's
        // own week, whose selected days may all precede the reference, and the next active one.
        // The third absorbs an `elapsedWeeks` that reads one low, which happens where a week begins
        // on a day with no local midnight (Asia/Beirut, America/Havana, America/Santiago,
        // Atlantic/Azores and Africa/Cairo all transition at 00:00 in the current rule set): the
        // first week tried then lies entirely before the reference and burns a slot. With only two
        // slots the function returned nil even though occurrences existed, and the schedule stopped
        // producing them for the rest of its life.
        for _ in 0..<3 {
            guard let activeWeek = calendar.date(
                byAdding: .weekOfYear,
                value: activeWeekOffset,
                to: anchorWeek
            ) else {
                return nil
            }

            let dayOffsets = Set(days)
                .map { day in
                    (day + 1 - calendar.firstWeekday + 7) % 7
                }
                .sorted()
            for dayOffset in dayOffsets {
                guard let dayDate = calendar.date(
                    byAdding: .day,
                    value: dayOffset,
                    to: activeWeek
                ) else {
                    continue
                }

                // `bySettingHour` searches forward and will cross into the next day when the
                // requested wall time does not exist — Australia/Lord_Howe shifts at 02:00, so an
                // 02:00 Sunday schedule resolved to Monday and fired on a weekday the user never
                // selected. Keep the day the user chose and fall back to its first valid instant.
                let resolved = calendar.date(
                    bySettingHour: time.hour ?? 0,
                    minute: time.minute ?? 0,
                    second: time.second ?? 0,
                    of: dayDate
                )
                let candidate: Date
                if let resolved, calendar.isDate(resolved, inSameDayAs: dayDate) {
                    candidate = resolved
                } else {
                    candidate = calendar.startOfDay(for: dayDate)
                }

                guard candidate >= scheduledDate else {
                    continue
                }
                if qualifies(
                    candidate,
                    relativeTo: referenceDate,
                    includesReference: includesReference
                ) {
                    return candidate
                }
            }

            let (nextOffset, overflowed) = activeWeekOffset
                .addingReportingOverflow(weekInterval)
            guard overflowed == false else { return nil }
            activeWeekOffset = nextOffset
        }
        return nil
    }

    /// First instant of the `firstWeekday`-aligned day that starts `date`'s week.
    ///
    /// Deliberately not `calendar.dateInterval(of: .weekOfYear, for:)`, which returns nil outright
    /// for weeks whose first day has no local midnight — America/Scoresbysund and America/Nuuk hit
    /// this every spring. That nil propagated straight out of `customWeeklyOccurrence`, so affected
    /// schedules produced no occurrences at all regardless of reference date, selected days, or
    /// interval. Weekday arithmetic over `startOfDay` always resolves.
    private func weekStart(for date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        guard offset > 0,
              let shifted = calendar.date(byAdding: .day, value: -offset, to: day) else {
            return day
        }
        return calendar.startOfDay(for: shifted)
    }

    private func qualifies(
        _ candidate: Date,
        relativeTo referenceDate: Date,
        includesReference: Bool
    ) -> Bool {
        includesReference ? candidate >= referenceDate : candidate > referenceDate
    }
    
    // MARK: - Hashable Conformance
    static func == (lhs: CareTaskSchedule, rhs: CareTaskSchedule) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension CareTaskCompletion {
    var completionTimeText: String {
        completedAt.formatted(date: .omitted, time: .shortened)
    }
    
    // MARK: - Hashable Conformance
    static func == (lhs: CareTaskCompletion, rhs: CareTaskCompletion) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 
