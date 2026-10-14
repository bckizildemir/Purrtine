import Foundation
import os
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
    var savePhoto: (PendingCatPhoto, UUID) async throws -> String = { photo, catID in
        try await PhotoManager.shared.save(photo, for: catID)
    }
    var deletePhoto: (String) -> Void = { PhotoManager.shared.deletePhoto(at: $0) }
    var saveContext: (ModelContext) throws -> Void = { try $0.save() }

    private let logger = Logger(subsystem: "com.berkecankizildemir.CatCareCalendar", category: "Onboarding")

    /// Throws `CareTaskRemindersOutOfSyncError` when the cat and every starter task were saved but
    /// the reminders of some tasks could not be scheduled. A `CancellationError` passes through
    /// unwrapped and may arrive after the commit, so the data can stand then too. Any other error
    /// comes from the one commit and means nothing was saved: the cat and its tasks are taken back
    /// out of the context as well, so a later save cannot commit them without reminders, and the
    /// photo written for this attempt is deleted. Stale reminders stay stale until the task is next
    /// written or a notification setting changes.
    ///
    /// The photo is optional: when it cannot be written, the failure is logged and the cat is saved
    /// without it. The caregiver can add one later in Edit Cat.
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
        let photoPath = await savedPhotoPath(tempData.photo, for: cat.id)
        if let photoPath {
            cat.photoURLs = [photoPath]
        }

        modelContext.insert(cat)
        let tasks = makeTasks(for: cat, selectedTasks: selectedTasks, in: modelContext)
        guard tasks.isEmpty == false else {
            do {
                try saveContext(modelContext)
            } catch {
                unstage(cat, [], photoPath: photoPath, in: modelContext)
                throw error
            }
            return cat
        }

        // Inserted up front so the first `save` commits the cat and all tasks together: a failed
        // commit then leaves nothing half-written, and the later saves only resync.
        for task in tasks {
            modelContext.insert(task)
        }
        try await saveTasks(tasks, of: cat, photoPath: photoPath, in: modelContext)
        return cat
    }

    private func savedPhotoPath(_ photo: PendingCatPhoto?, for catId: UUID) async -> String? {
        guard let photo else { return nil }
        do {
            return try await savePhoto(photo, catId)
        } catch {
            logger.error(
                "Onboarding cat saved without its photo: \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }

    /// The first write commits the cat and every task; a failure there is "not saved", so the rest
    /// of the onboarding data is unstaged too, beyond the one task the writer takes back itself.
    ///
    /// Every later write only resyncs, so any failure from one of them leaves its task saved with
    /// stale reminders. Those writes all run even after one fails: stopping early would only leave
    /// the remaining tasks without reminders too.
    private func saveTasks(
        _ tasks: [CareTask],
        of cat: Cat,
        photoPath: String?,
        in modelContext: ModelContext
    ) async throws {
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
                unstage(cat, tasks, photoPath: photoPath, in: modelContext)
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

    /// Deletes whatever of the onboarding data is still staged, schedules first, and the photo file
    /// written for it. Nothing of it was committed, so this only takes it back out of the context.
    private func unstage(_ cat: Cat, _ tasks: [CareTask], photoPath: String?, in modelContext: ModelContext) {
        let stagedIds = Set(modelContext.insertedModelsArray.map(\.persistentModelID))
        let models: [any PersistentModel] = tasks.flatMap(\.schedules) + tasks + [cat]
        for model in models where stagedIds.contains(model.persistentModelID) {
            modelContext.delete(model)
        }
        if let photoPath {
            deletePhoto(photoPath)
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
