import Foundation
import SwiftData

enum TaskActionError: LocalizedError, Equatable {
    case taskNotFound
    case caregiverUnavailable
    case invalidPostponeMinutes
    case occurrenceNotOpen

    var errorDescription: String? {
        switch self {
        case .occurrenceNotOpen:
            String(localized: .errorTaskActionOccurrenceNotOpen)
        case .taskNotFound:
            String(localized: .errorTaskActionTaskNotFound)
        case .caregiverUnavailable:
            String(localized: .errorTaskActionCaregiverUnavailable)
        case .invalidPostponeMinutes:
            String(localized: .errorTaskActionInvalidPostponeMinutes)
        }
    }
}

/// The completion rules: which caregiver is credited, which day a completion counts for, and how a
/// recurring schedule advances. It changes models and nothing else — the commit and the reminder
/// resync belong to `CareTaskWriting.complete`, so only one type owns that postcondition.
@MainActor
enum TaskActionService {
    static func fetchTask(_ id: UUID, in context: ModelContext) throws -> CareTask? {
        var descriptor = FetchDescriptor<CareTask>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        descriptor.includePendingChanges = true
        return try context.fetch(descriptor).first
    }

    /// Reads `task`'s own rows (the task and its schedules) from the store, so the objects `context`
    /// already holds show what another context committed since, such as a reminder's Complete (#141).
    /// Without it, a held schedule still says it is active and the same day would be recorded twice.
    /// A fetch does not discard a change staged in `context` and not yet saved. It covers only this
    /// task; new completions arrive through the task's relationship.
    static func refreshFromStore(_ task: CareTask, in context: ModelContext) throws {
        let id = task.id
        var taskDescriptor = FetchDescriptor<CareTask>(predicate: #Predicate { $0.id == id })
        taskDescriptor.fetchLimit = 1
        _ = try context.fetch(taskDescriptor)
        _ = try context.fetch(FetchDescriptor<CareTaskSchedule>(predicate: #Predicate { $0.task?.id == id }))
    }

    /// The day `task` is due now: the day of its active schedule, or `nil` when it has none.
    static func openOccurrence(of task: CareTask) -> Date? {
        task.activeSchedule.map { Calendar.current.startOfDay(for: $0.scheduledDate) }
    }

    /// Records a completion of `task` in `context` without saving it. `now` is the completion
    /// instant; callers leave it at the default, tests pin it.
    static func recordCompletion(
        of task: CareTask,
        with input: CareTaskCompletionInput,
        in context: ModelContext,
        now: Date = Date()
    ) throws {
        guard let caregiver = try resolveCaregiver(
            for: task,
            preferred: input.caregiver,
            in: context
        ) else {
            throw TaskActionError.caregiverUnavailable
        }

        try validateOccurrence(of: task, for: input, now: now)

        let activeSchedule = task.activeSchedule
        let effectiveCompletedForDate = completionDate(for: task, explicit: input.completedForDate, now: now)
        // `nil`: no real time of care, so this is a fill-in.
        let careTime = realTimeOfCare(
            for: task,
            namedDay: input.completedForDate,
            time: input.completedAtTime,
            now: now
        )
        let completedAt = careTime ?? now
        let completion = CareTaskCompletion(
            completedAt: completedAt,
            completedForDate: effectiveCompletedForDate,
            notes: input.notes,
            photoURLs: input.photoURLs,
            wasOnTime: isOnTime(
                day: effectiveCompletedForDate,
                schedule: activeSchedule,
                completedAt: completedAt,
                now: now
            )
        )
        if careTime == nil {
            // The marker `CareTaskCompletion.isFillIn` reads: both stored dates are one start-of-day instant.
            completion.completedAt = completion.completedForDate
        }
        completion.task = task
        completion.caregiver = caregiver
        completion.cats = input.cats.isEmpty ? task.assignedCats : input.cats

        task.completions.append(completion)
        context.insert(completion)

        if let activeSchedule, activeSchedule.frequency != .once {
            // A day before the open one (a day left behind, filled in late through Whiskers
            // "yesterday") is recorded only: moving the schedule would pull the open day back.
            if effectiveCompletedForDate < Calendar.current.startOfDay(for: activeSchedule.scheduledDate) {
                task.updatedAt = now
                return
            }
            handleRecurringCompletion(
                for: task,
                activeSchedule: activeSchedule,
                completedOccurrenceDate: effectiveCompletedForDate,
                in: context
            )
        } else {
            activeSchedule?.isActive = false
            task.status = .completed
            task.updatedAt = Date()
        }
    }

    /// Throws `invalidPostponeMinutes` unless `minutes` is positive and converts to seconds.
    static func validatePostponeMinutes(_ minutes: Int) throws {
        let (_, didOverflow) = minutes.multipliedReportingOverflow(by: 60)
        guard minutes > 0, didOverflow == false else {
            throw TaskActionError.invalidPostponeMinutes
        }
    }

    // MARK: - Helpers

    /// The one check every completion path shares, run before anything is recorded. A completion
    /// that names no day completes the open occurrence, today or later. One that names a day (a day
    /// picked in the calendar, or "yesterday" said to Whiskers) is accepted for any day from the
    /// task's first day up to today that has no completion yet (`completionRefusal`), and refused
    /// otherwise. A time stated for that day is refused when it is after `now`. A caller that was
    /// shown the open day and names no day of its own (a reminder's Complete, a stale card) passes
    /// that day as `expectedOccurrence`, so it completes that day or nothing.
    private static func validateOccurrence(
        of task: CareTask,
        for input: CareTaskCompletionInput,
        now: Date
    ) throws {
        let calendar = Calendar.current

        if let expected = input.expectedOccurrence,
           openOccurrence(of: task) != calendar.startOfDay(for: expected) {
            throw TaskActionError.occurrenceNotOpen
        }

        guard let namedDay = input.completedForDate else { return }

        if completionRefusal(of: task, on: namedDay, at: input.completedAtTime, now: now) != nil {
            throw TaskActionError.occurrenceNotOpen
        }
    }

    /// Whether `recordCompletion` would accept a completion of `task` for `day`. A view asks this
    /// before it opens a sheet for a day, so it refuses at once instead of on submit. It runs the
    /// same rules as `validateOccurrence`, so the two cannot drift.
    static func canComplete(_ task: CareTask, on day: Date, now: Date = Date()) -> Bool {
        completionRefusal(of: task, on: day, now: now) == nil
    }

    /// Why `task` cannot be completed for the named `day` (at the stated `time`, when there is one),
    /// or `nil` when it can. Any day from the task's first day up to today is accepted while it has no
    /// completion. The first day is the earlier of the day the task was created (`CareTask.createdAt`;
    /// not the schedule's, which is remade at every completion) and its open occurrence day, so a task
    /// created with a past start date keeps its own first day. An earlier open (missed) day does not
    /// block a later one. A stated time after `now` is refused.
    static func completionRefusal(
        of task: CareTask,
        on day: Date,
        at time: TimeOfDay? = nil,
        now: Date = Date()
    ) -> CompletionDayRefusal? {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: day)

        if day > calendar.startOfDay(for: now) {
            return .dayAfterToday
        }
        if TaskCalendarDerivation.hasCompletion(for: task, on: day, calendar: calendar) {
            return .alreadyDone
        }
        let createdDay = calendar.startOfDay(for: task.createdAt)
        let firstDay = openOccurrence(of: task).map { min($0, createdDay) } ?? createdDay
        if day < firstDay {
            return .beforeTaskExisted
        }
        if let statedInstant = time?.date(on: day, calendar: calendar), statedInstant > now {
            return .timeAfterNow
        }
        return nil
    }

    private static func resolveCaregiver(
        for task: CareTask,
        preferred caregiver: Caregiver?,
        in context: ModelContext
    ) throws -> Caregiver? {
        if let caregiver {
            return caregiver
        }

        if let caregiver = task.assignedCaregiver {
            return caregiver
        }

        let descriptor = FetchDescriptor<Caregiver>()
        let caregivers = try context.fetch(descriptor)

        if let primary = caregivers.first(where: { $0.isPrimary }) {
            return primary
        }

        return caregivers.first
    }

    /// When the care was really done, or `nil` for a fill-in with no real time.
    /// - A plain tap (no day named) is `now`.
    /// - A named day with a stated time is that time on the day.
    /// - Today named with no time is `now`.
    /// - A past day named with no time is the task's own time that day, or `nil` when the task has
    ///   none (the one fill-in case).
    private static func realTimeOfCare(
        for task: CareTask,
        namedDay: Date?,
        time: TimeOfDay?,
        now: Date
    ) -> Date? {
        let calendar = Calendar.current
        guard let namedDay else { return now }
        let day = calendar.startOfDay(for: namedDay)

        if let time {
            return time.date(on: day, calendar: calendar)
        }
        if day == calendar.startOfDay(for: now) {
            return now
        }
        guard let dueTime = task.activeSchedule?.scheduledTime else { return nil }
        // A due time that does not exist on `day` (a spring-forward gap) resolves to the next valid time.
        return TimeOfDay(of: dueTime, calendar: calendar).date(on: day, calendar: calendar)
    }

    private static func completionDate(for task: CareTask, explicit completedForDate: Date?, now: Date) -> Date {
        let calendar = Calendar.current

        if let completedForDate {
            return calendar.startOfDay(for: completedForDate)
        }

        if let scheduledDate = task.activeSchedule?.scheduledDate {
            return calendar.startOfDay(for: scheduledDate)
        }

        return calendar.startOfDay(for: now)
    }

    /// On time is measured against the day recorded: that day's due time versus when the care was
    /// done. A day before today is never on time, whatever time was stated for it.
    private static func isOnTime(day: Date, schedule: CareTaskSchedule?, completedAt: Date, now: Date) -> Bool {
        if day < Calendar.current.startOfDay(for: now) { return false }
        guard let schedule else { return true }
        return schedule.dueDate(on: day) >= completedAt
    }

    private static func handleRecurringCompletion(
        for task: CareTask,
        activeSchedule: CareTaskSchedule,
        completedOccurrenceDate: Date,
        in context: ModelContext
    ) {
        // `completedOccurrenceDate` is day-granular (see `completionDate(for:explicit:)`), so the
        // next occurrence has to be the first one on a *later* day. Measuring from the completed
        // instant instead lets a schedule whose `scheduledDate` carries a time of day — such as the
        // 08:00 feeding `OnboardingDataBuilder` creates — match itself, leaving the task pinned to
        // its first date forever. Resolved before `isActive` is cleared, because
        // `nextOccurrence(from:)` returns nil for an inactive schedule.
        let calendar = Calendar.current
        let nextOccurrence = calendar
            .date(byAdding: .day, value: 1, to: calendar.startOfDay(for: completedOccurrenceDate))
            .flatMap { activeSchedule.nextOccurrence(from: $0, calendar: calendar) }
        activeSchedule.isActive = false

        if let nextOccurrence {
            let nextSchedule = CareTaskSchedule(
                scheduledDate: nextOccurrence,
                scheduledTime: activeSchedule.scheduledTime,
                frequency: activeSchedule.frequency,
                frequencyInterval: activeSchedule.frequencyInterval,
                endDate: activeSchedule.endDate,
                reminderMinutes: activeSchedule.reminderMinutes,
                customDays: activeSchedule.customDays
            )
            nextSchedule.task = task
            context.insert(nextSchedule)

            task.status = .pending
        } else {
            task.status = .completed
        }
        task.updatedAt = Date()
    }
}
