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

    /// The day `task` is due now: the day of its active schedule, or `nil` when it has none.
    static func openOccurrence(of task: CareTask) -> Date? {
        task.activeSchedule.map { Calendar.current.startOfDay(for: $0.scheduledDate) }
    }

    /// Records a completion of `task` in `context` without saving it.
    static func recordCompletion(
        of task: CareTask,
        with input: CareTaskCompletionInput,
        in context: ModelContext
    ) throws {
        guard let caregiver = try resolveCaregiver(
            for: task,
            preferred: input.caregiver,
            in: context
        ) else {
            throw TaskActionError.caregiverUnavailable
        }

        try validateOccurrence(of: task, for: input)

        let activeSchedule = task.activeSchedule
        let effectiveCompletedForDate = completionDate(for: task, explicit: input.completedForDate)
        let completion = CareTaskCompletion(
            completedAt: Date(),
            completedForDate: effectiveCompletedForDate,
            notes: input.notes,
            photoURLs: input.photoURLs,
            wasOnTime: isOnTime(activeSchedule)
        )
        completion.task = task
        completion.caregiver = caregiver
        completion.cats = input.cats.isEmpty ? task.assignedCats : input.cats

        task.completions.append(completion)
        context.insert(completion)

        if let activeSchedule, activeSchedule.frequency != .once {
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

    /// The one check every completion path shares, run before anything is recorded: a completion
    /// names an occurrence only when the caller was shown it, and that occurrence must be the one
    /// open now. Otherwise recording it would skip the open day (a later day), credit a day twice
    /// (a day that already has a completion), or complete a day nobody saw (a stale reminder or
    /// Whiskers card). A completion that names no day completes the open occurrence, as before.
    private static func validateOccurrence(of task: CareTask, for input: CareTaskCompletionInput) throws {
        let calendar = Calendar.current
        let openDay = openOccurrence(of: task)

        if let expected = input.expectedOccurrence {
            guard openDay == calendar.startOfDay(for: expected) else {
                throw TaskActionError.occurrenceNotOpen
            }
        }

        if let explicit = input.completedForDate {
            let day = calendar.startOfDay(for: explicit)
            if let openDay, day > openDay {
                throw TaskActionError.occurrenceNotOpen
            }
            if TaskCalendarDerivation.hasCompletion(for: task, on: day, calendar: calendar) {
                throw TaskActionError.occurrenceNotOpen
            }
        }
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

    private static func completionDate(for task: CareTask, explicit completedForDate: Date?) -> Date {
        let calendar = Calendar.current

        if let completedForDate {
            return calendar.startOfDay(for: completedForDate)
        }

        if let scheduledDate = task.activeSchedule?.scheduledDate {
            return calendar.startOfDay(for: scheduledDate)
        }

        return calendar.startOfDay(for: Date())
    }

    private static func isOnTime(_ schedule: CareTaskSchedule?) -> Bool {
        guard let schedule else { return true }
        return schedule.effectiveDueDate >= Date()
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
