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
        let completion = CareTaskCompletion(
            completedAt: now,
            completedForDate: effectiveCompletedForDate,
            notes: input.notes,
            photoURLs: input.photoURLs,
            wasOnTime: isOnTime(day: effectiveCompletedForDate, schedule: activeSchedule, now: now)
        )
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
    /// that names no day completes the open occurrence. One that names a day (a day picked in the
    /// calendar, or "yesterday" said to Whiskers) is accepted for any day up to today that has no
    /// completion yet, and refused for a day after today or a day already done. A caller that was
    /// shown the open day and names no day of its own (a reminder's Complete, a stale card) passes
    /// that day as `expectedOccurrence`, so it completes that day or nothing.
    private static func validateOccurrence(
        of task: CareTask,
        for input: CareTaskCompletionInput,
        now: Date
    ) throws {
        guard isOccurrenceAccepted(
            of: task,
            expected: input.expectedOccurrence,
            completedForDate: input.completedForDate,
            now: now
        ) else {
            throw TaskActionError.occurrenceNotOpen
        }
    }

    /// Whether `recordCompletion` would accept a completion of `task` for `day`. A view asks this
    /// before it opens a sheet for a day, so it refuses at once instead of on submit. It runs the
    /// same rules as `validateOccurrence`, so the two cannot drift.
    static func canComplete(_ task: CareTask, on day: Date, now: Date = Date()) -> Bool {
        isOccurrenceAccepted(of: task, expected: nil, completedForDate: day, now: now)
    }

    /// The rules behind `validateOccurrence` and `canComplete`.
    private static func isOccurrenceAccepted(
        of task: CareTask,
        expected: Date?,
        completedForDate explicit: Date?,
        now: Date
    ) -> Bool {
        let calendar = Calendar.current
        let openDay = openOccurrence(of: task)

        if let expected, openDay != calendar.startOfDay(for: expected) {
            return false
        }

        if let explicit {
            let day = calendar.startOfDay(for: explicit)
            // Any day up to and including today with no completion yet. An earlier open (missed)
            // day does not block a later one; only days after today are refused.
            if day > calendar.startOfDay(for: now) {
                return false
            }
            if TaskCalendarDerivation.hasCompletion(for: task, on: day, calendar: calendar) {
                return false
            }
        }
        return true
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

    /// On time is measured against the day recorded: that day's due time versus the completion
    /// instant. A day before today is never on time.
    private static func isOnTime(day: Date, schedule: CareTaskSchedule?, now: Date) -> Bool {
        if day < Calendar.current.startOfDay(for: now) { return false }
        guard let schedule else { return true }
        return schedule.dueDate(on: day) >= now
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
