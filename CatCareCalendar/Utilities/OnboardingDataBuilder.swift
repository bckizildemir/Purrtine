import Foundation
import SwiftData

/// Turns the onboarding answers into the first cat and its starter tasks.
///
/// The cat and every starter task are committed in one save, made by the first `taskWriter.save`;
/// each task's reminders are then scheduled as part of its write. Onboarding asks for notification
/// permission before this step, so the starter tasks are the first ones that can remind the user.
@MainActor
struct OnboardingDataBuilder {
    let taskWriter: any CareTaskWriting
    var now: () -> Date = Date.init
    var savePhoto: (Data, UUID) -> String? = { data, catID in
        try? PhotoManager.shared.savePhoto(data, for: catID)
    }

    /// Throws `CareTaskRemindersOutOfSyncError` when the cat and every starter task were saved but
    /// the reminders of some tasks could not be scheduled. A `CancellationError` passes through
    /// unwrapped and may arrive after the commit, so the data can stand then too. Any other error
    /// comes from the one commit and means nothing was saved: the cat and its tasks are taken back
    /// out of the context as well, so a later save cannot commit them without reminders. Stale
    /// reminders stay stale until the task is next written or a notification setting changes.
    @discardableResult
    func createCatAndTasks(
        from tempData: TempCatData,
        selectedTasks: Set<TaskType>,
        in modelContext: ModelContext
    ) async throws -> Cat? {
        guard tempData.name.isEmpty == false else {
            try modelContext.save()
            return nil
        }

        let cat = makeCat(from: tempData)

        if let photoData = tempData.photoData,
           let savedPath = savePhoto(photoData, cat.id) {
            cat.photoURLs = [savedPath]
        }

        modelContext.insert(cat)
        let tasks = makeTasks(for: cat, selectedTasks: selectedTasks, in: modelContext)
        guard tasks.isEmpty == false else {
            try modelContext.save()
            return cat
        }

        // Inserted up front so the first `save` commits the cat and all tasks together: a failed
        // commit then leaves nothing half-written, and the later saves only resync.
        for task in tasks {
            modelContext.insert(task)
        }
        try await saveTasks(tasks, of: cat, in: modelContext)
        return cat
    }

    /// The first write commits the cat and every task; a failure there is "not saved", so the rest
    /// of the onboarding data is unstaged too, beyond the one task the writer takes back itself.
    ///
    /// Every later write only resyncs, so any failure from one of them leaves its task saved with
    /// stale reminders. Those writes all run even after one fails: stopping early would only leave
    /// the remaining tasks without reminders too.
    private func saveTasks(_ tasks: [CareTask], of cat: Cat, in modelContext: ModelContext) async throws {
        var staleTaskIds: [UUID] = []
        var firstStaleError: (any Error)?

        for (index, task) in tasks.enumerated() {
            do {
                try await taskWriter.save(task, in: modelContext)
            } catch let error as CareTaskRemindersOutOfSyncError {
                staleTaskIds.append(contentsOf: error.taskIds)
                firstStaleError = firstStaleError ?? error.underlyingError
            } catch let error as CancellationError {
                throw error
            } catch where index == 0 {
                unstage(cat, tasks, in: modelContext)
                throw error
            } catch {
                staleTaskIds.append(task.id)
                firstStaleError = firstStaleError ?? error
            }
        }

        if let firstStaleError {
            throw CareTaskRemindersOutOfSyncError(taskIds: staleTaskIds, underlyingError: firstStaleError)
        }
    }

    /// Deletes whatever of the onboarding data is still staged, schedules first. Nothing of it was
    /// committed, so this only takes it back out of the context.
    private func unstage(_ cat: Cat, _ tasks: [CareTask], in modelContext: ModelContext) {
        let stagedIds = Set(modelContext.insertedModelsArray.map(\.persistentModelID))
        let models: [any PersistentModel] = tasks.flatMap(\.schedules) + tasks + [cat]
        for model in models where stagedIds.contains(model.persistentModelID) {
            modelContext.delete(model)
        }
    }

    private func makeCat(from tempData: TempCatData) -> Cat {
        let ageInMonths = AgeUtils.months(from: tempData.age, unit: tempData.ageUnit)
        let cat = Cat(
            name: tempData.name,
            age: ageInMonths,
            gender: tempData.gender,
            breed: tempData.breed.isEmpty ? nil : tempData.breed
        )

        if tempData.notes.isEmpty == false {
            cat.medicalNotes = tempData.notes
        }

        return cat
    }

    private func makeTasks(
        for cat: Cat,
        selectedTasks: Set<TaskType>,
        in modelContext: ModelContext
    ) -> [CareTask] {
        let caregiver = defaultCaregiver(in: modelContext)

        return selectedTasks.map { taskType in
            let template = taskTemplate(for: taskType)
            let task = CareTask(
                title: template.title,
                description: template.description,
                category: template.category,
                iconName: template.iconName,
                priority: template.priority
            )

            task.assignedCats.append(cat)
            task.assignedCaregiver = caregiver

            let schedule = schedule(for: taskType, task: task)
            task.schedules.append(schedule)
            return task
        }
    }

    private func defaultCaregiver(in modelContext: ModelContext) -> Caregiver? {
        let descriptor = FetchDescriptor<Caregiver>()
        let caregivers = (try? modelContext.fetch(descriptor)) ?? []
        return caregivers.first(where: \.isPrimary) ?? caregivers.first
    }

    private func taskTemplate(
        for taskType: TaskType
    ) -> (
        title: String,
        description: String,
        category: CareTaskCategory,
        iconName: String,
        priority: CareTaskPriority
    ) {
        switch taskType {
        case .feeding:
            return (
                title: String(localized: .onboardingTaskFeedingTitle),
                description: String(localized: .onboardingTaskFeedingDescription),
                category: .feeding,
                iconName: "fork.knife",
                priority: .medium
            )
        case .water:
            return (
                title: String(localized: .templateFreshWaterTitle),
                description: String(localized: .templateFreshWaterDescription),
                category: .water,
                iconName: "drop.fill",
                priority: .medium
            )
        case .litterBox:
            return (
                title: String(localized: .onboardingTaskLitterBoxTitle),
                description: String(localized: .onboardingTaskLitterBoxDescription),
                category: .litter,
                iconName: "tray.fill",
                priority: .medium
            )
        }
    }

    private func schedule(for taskType: TaskType, task: CareTask) -> CareTaskSchedule {
        let scheduledDate: Date
        let frequency: CareTaskFrequency
        let frequencyInterval: Int
        let reminderMinutes: Int

        switch taskType {
        case .feeding:
            scheduledDate = dateToday(hour: 8)
            frequency = .daily
            frequencyInterval = 1
            reminderMinutes = 15
        case .water:
            scheduledDate = dateToday(hour: 10)
            frequency = .daily
            frequencyInterval = 1
            reminderMinutes = 15
        case .litterBox:
            scheduledDate = dateToday(hour: 18)
            frequency = .custom
            frequencyInterval = 2
            reminderMinutes = 15
        }

        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: frequency,
            frequencyInterval: frequencyInterval,
            reminderMinutes: reminderMinutes
        )
        schedule.task = task
        return schedule
    }

    private func dateToday(hour: Int) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now())
        return calendar.date(byAdding: .hour, value: hour, to: startOfDay) ?? now()
    }
}
