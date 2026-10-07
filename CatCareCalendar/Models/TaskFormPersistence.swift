import Foundation
import SwiftData

struct TaskFormDraft {
    var title: String
    var taskDescription: String
    var category: CareTaskCategory
    var iconName: String
    var priority: CareTaskPriority
    var assignedCats: [Cat]
    var assignedCaregiver: Caregiver?
    var scheduledDate: Date
    var scheduledTime: Date?
    var frequency: CareTaskFrequency
    var frequencyInterval: Int
    var endDate: Date?
    var reminderMinutes: Int?
    var customDays: [Int]?
}

enum TaskFormPersistenceError: LocalizedError, Equatable {
    case invalidTitle

    var errorDescription: String? {
        switch self {
        case .invalidTitle:
            String(localized: .tasksConfigTitleRequired)
        }
    }
}

/// Applies a form draft to the models. Nothing here commits: the caller hands the task to
/// `CareTaskWriting.save`, which owns the `save()` and the reminder resync that must follow it.
@MainActor
enum TaskFormPersistence {
    @discardableResult
    static func createTask(
        from draft: TaskFormDraft,
        in modelContext: ModelContext,
        existingCaregivers: [Caregiver],
        defaultCaregiverName: String,
        defaultCaregiverLocalizationKey: String? = nil
    ) throws -> CareTask {
        let title = try normalizedTitle(draft.title)
        let caregiver = resolvedCaregiver(
            selectedCaregiver: draft.assignedCaregiver,
            existingCaregivers: existingCaregivers,
            modelContext: modelContext,
            defaultCaregiverName: defaultCaregiverName,
            defaultCaregiverLocalizationKey: defaultCaregiverLocalizationKey
        )

        let task = CareTask(
            title: title,
            description: draft.taskDescription.isEmpty ? nil : draft.taskDescription,
            category: draft.category,
            iconName: draft.iconName,
            priority: draft.priority
        )
        task.assignedCats = draft.assignedCats
        task.assignedCaregiver = caregiver

        let schedule = makeSchedule(from: draft)
        schedule.task = task
        task.schedules = [schedule]

        modelContext.insert(task)
        modelContext.insert(schedule)

        return task
    }

    static func updateTask(
        _ task: CareTask,
        from draft: TaskFormDraft,
        in modelContext: ModelContext,
        updatedAt: Date = Date()
    ) throws {
        let title = try normalizedTitle(draft.title)

        task.title = title
        task.taskDescription = draft.taskDescription.isEmpty ? nil : draft.taskDescription
        task.category = draft.category
        task.iconName = draft.iconName
        task.priority = draft.priority
        task.assignedCats = draft.assignedCats
        // Persist a reassigned caregiver. A nil draft caregiver means "no change" here
        // (the edit form has no way to unassign), so keep the task's existing caregiver.
        if let caregiver = draft.assignedCaregiver {
            task.assignedCaregiver = caregiver
        }
        task.updatedAt = updatedAt

        if let schedule = task.schedules.first(where: { $0.isActive }) ?? task.schedules.first {
            apply(draft, to: schedule)
        } else {
            let schedule = makeSchedule(from: draft)
            schedule.task = task
            task.schedules = [schedule]
            modelContext.insert(schedule)
        }
    }

    private static func resolvedCaregiver(
        selectedCaregiver: Caregiver?,
        existingCaregivers: [Caregiver],
        modelContext: ModelContext,
        defaultCaregiverName: String,
        defaultCaregiverLocalizationKey: String?
    ) -> Caregiver {
        if let selectedCaregiver {
            return selectedCaregiver
        }

        if let primaryCaregiver = existingCaregivers.first(where: { $0.isPrimary }) ?? existingCaregivers.first {
            return primaryCaregiver
        }

        let defaultCaregiver = Caregiver(
            name: defaultCaregiverName,
            role: .primary,
            localizationKey: defaultCaregiverLocalizationKey
        )
        modelContext.insert(defaultCaregiver)
        return defaultCaregiver
    }

    private static func makeSchedule(from draft: TaskFormDraft) -> CareTaskSchedule {
        let scheduleValues = normalizedScheduleValues(from: draft)
        return CareTaskSchedule(
            scheduledDate: draft.scheduledDate,
            scheduledTime: draft.scheduledTime,
            frequency: draft.frequency,
            frequencyInterval: scheduleValues.frequencyInterval,
            endDate: draft.endDate,
            reminderMinutes: scheduleValues.reminderMinutes,
            customDays: scheduleValues.customDays
        )
    }

    private static func apply(_ draft: TaskFormDraft, to schedule: CareTaskSchedule) {
        let scheduleValues = normalizedScheduleValues(from: draft)
        schedule.scheduledDate = draft.scheduledDate
        schedule.scheduledTime = draft.scheduledTime
        schedule.frequency = draft.frequency
        schedule.frequencyInterval = scheduleValues.frequencyInterval
        schedule.endDate = draft.endDate
        schedule.reminderMinutes = scheduleValues.reminderMinutes
        schedule.customDays = scheduleValues.customDays
    }

    private static func normalizedTitle(_ title: String) throws -> String {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedTitle.isEmpty == false else {
            throw TaskFormPersistenceError.invalidTitle
        }
        return normalizedTitle
    }

    private static func normalizedScheduleValues(
        from draft: TaskFormDraft
    ) -> (frequencyInterval: Int, reminderMinutes: Int?, customDays: [Int]?) {
        let frequencyInterval = min(max(1, draft.frequencyInterval), Int(Int32.max))
        let reminderMinutes = draft.reminderMinutes.flatMap { $0 >= 0 ? $0 : nil }
        let customDays: [Int]?
        if draft.frequency == .weekly {
            let validDays = Set(draft.customDays ?? [])
                .filter { (0...6).contains($0) }
                .sorted()
            customDays = validDays.isEmpty ? nil : validDays
        } else {
            customDays = nil
        }
        return (frequencyInterval, reminderMinutes, customDays)
    }
}
