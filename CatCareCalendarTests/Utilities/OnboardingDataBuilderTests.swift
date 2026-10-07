import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@MainActor
struct OnboardingDataBuilderTests {
    let scheduler = NotificationSchedulerSpy()

    @Test
    func createsCatAndSelectedStarterTasks() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)

        let referenceDate = try #require(makeDate(year: 2026, month: 4, day: 7))
        let sut = OnboardingDataBuilder(
            taskWriter: CareTaskWriter(scheduler: scheduler),
            now: { referenceDate },
            savePhoto: { _, _ in "saved-cat-photo.jpg" }
        )
        var tempData = TempCatData()
        tempData.name = "Mochi"
        tempData.age = 2
        tempData.ageUnit = .years
        tempData.gender = .female
        tempData.breed = "Tabby"
        tempData.notes = "Needs slow feeding"
        tempData.photoData = Data("photo".utf8)

        let cat = try #require(
            try await sut.createCatAndTasks(
                from: tempData,
                selectedTasks: [.feeding, .water],
                in: context
            )
        )
        let tasks = try context.fetch(FetchDescriptor<CareTask>())
        let schedules = tasks.flatMap(\.schedules)

        #expect(cat.name == "Mochi")
        #expect(cat.age == 24)
        #expect(cat.gender == .female)
        #expect(cat.breed == "Tabby")
        #expect(cat.medicalNotes == "Needs slow feeding")
        #expect(cat.photoURLs == ["saved-cat-photo.jpg"])
        #expect(tasks.count == 2)
        #expect(tasks.allSatisfy { $0.assignedCats.map(\.id) == [cat.id] })
        #expect(tasks.allSatisfy { $0.assignedCaregiver?.isPrimary == true })
        #expect(schedules.count == 2)
    }

    @Test
    func starterTaskSchedulesUseExpectedDefaults() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)

        let referenceDate = try #require(makeDate(year: 2026, month: 4, day: 7))
        let sut = makeSUT(now: { referenceDate })
        var tempData = TempCatData()
        tempData.name = "Luna"

        try await sut.createCatAndTasks(
            from: tempData,
            selectedTasks: [.feeding, .water, .litterBox],
            in: context
        )

        let tasks = try context.fetch(FetchDescriptor<CareTask>())
        let schedulesByCategory = Dictionary(uniqueKeysWithValues: tasks.compactMap { task in
            task.schedules.first.map { (task.category, $0) }
        })

        let feeding = try #require(schedulesByCategory[.feeding])
        let water = try #require(schedulesByCategory[.water])
        let litter = try #require(schedulesByCategory[.litter])

        #expect(feeding.frequency == .daily)
        #expect(hour(for: feeding.scheduledDate) == 8)
        #expect(feeding.reminderMinutes == 15)
        #expect(water.frequency == .daily)
        #expect(hour(for: water.scheduledDate) == 10)
        #expect(water.reminderMinutes == 15)
        #expect(litter.frequency == .custom)
        #expect(litter.frequencyInterval == 2)
        #expect(hour(for: litter.scheduledDate) == 18)
        #expect(litter.reminderMinutes == 15)
    }

    @Test
    func emptyTaskSelectionCreatesCatWithoutTasksOrSchedules() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        var tempData = TempCatData()
        tempData.name = "Mochi"

        let sut = makeSUT()
        let cat = try await sut.createCatAndTasks(
            from: tempData,
            selectedTasks: [],
            in: context
        )
        let cats = try context.fetch(FetchDescriptor<Cat>())
        let tasks = try context.fetch(FetchDescriptor<CareTask>())
        let schedules = try context.fetch(FetchDescriptor<CareTaskSchedule>())

        #expect(cat != nil)
        #expect(cats.count == 1)
        #expect(tasks.isEmpty)
        #expect(schedules.isEmpty)
    }

    @Test
    func blankCatNameDoesNotCreateRecords() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)

        let sut = makeSUT()
        let cat = try await sut.createCatAndTasks(
            from: TempCatData(),
            selectedTasks: [.feeding],
            in: context
        )
        let cats = try context.fetch(FetchDescriptor<Cat>())
        let tasks = try context.fetch(FetchDescriptor<CareTask>())

        #expect(cat == nil)
        #expect(cats.isEmpty)
        #expect(tasks.isEmpty)
        #expect(scheduler.resyncAttemptCount == 0)
    }

    // MARK: - Reminders

    /// The onboarding grant happens before this step, so a starter task committed without a resync
    /// would sit without reminders until something else happened to reschedule it.
    @Test
    func everyStarterTaskHasItsRemindersScheduledOnceCommitted() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)
        scheduler.observe(container)
        var tempData = TempCatData()
        tempData.name = "Luna"

        try await makeSUT().createCatAndTasks(
            from: tempData,
            selectedTasks: [.feeding, .water, .litterBox],
            in: context
        )

        let tasks = try context.fetch(FetchDescriptor<CareTask>())
        let scheduledInfos = scheduler.lastResyncedInfos
        let scheduleIds = tasks.flatMap(\.schedules).map(\.id)

        #expect(context.hasChanges == false)
        #expect(tasks.count == 3)
        #expect(Set(scheduledInfos.map(\.taskId)) == Set(tasks.map(\.id)))
        #expect(Set(scheduledInfos.map(\.scheduleId)) == Set(scheduleIds))
        #expect(scheduledInfos.allSatisfy { $0.catNames == "Luna" })
    }

    @Test
    func emptyTaskSelectionSchedulesNothing() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        var tempData = TempCatData()
        tempData.name = "Mochi"

        try await makeSUT().createCatAndTasks(from: tempData, selectedTasks: [], in: context)

        #expect(context.hasChanges == false)
        #expect(scheduler.resyncAttemptCount == 0)
    }

    /// "Saved, reminders stale": the onboarding data must stand, and the caller must be able to tell
    /// this apart from a failed save.
    @Test
    func aFailedResyncKeepsTheOnboardingDataAndNamesEveryStaleTask() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)
        scheduler.resyncError = .forcedFailure
        var tempData = TempCatData()
        tempData.name = "Luna"

        let error = try await #require(throws: CareTaskRemindersOutOfSyncError.self) {
            _ = try await makeSUT().createCatAndTasks(
                from: tempData,
                selectedTasks: [.feeding, .water],
                in: context
            )
        }

        let cats = try context.fetch(FetchDescriptor<Cat>())
        let tasks = try context.fetch(FetchDescriptor<CareTask>())

        #expect(context.hasChanges == false)
        #expect(cats.map(\.name) == ["Luna"])
        #expect(tasks.count == 2)
        #expect(Set(error.taskIds) == Set(tasks.map(\.id)))
        #expect(scheduler.resyncAttemptCount == 2)
    }

    /// The cat and its tasks land in one commit, so a failed commit leaves no cat without its tasks.
    @Test
    func theCatAndEveryStarterTaskArePendingWhenTheFirstWriteRuns() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)
        try context.save()
        let writer = FirstSaveRecordingWriter()
        var tempData = TempCatData()
        tempData.name = "Luna"

        try await OnboardingDataBuilder(taskWriter: writer).createCatAndTasks(
            from: tempData,
            selectedTasks: [.feeding, .water, .litterBox],
            in: context
        )

        let pendingAtFirstSave = try #require(writer.pendingAtFirstSave)
        let pendingTaskIds = pendingAtFirstSave.compactMap { ($0 as? CareTask)?.id }
        let pendingCatNames = pendingAtFirstSave.compactMap { ($0 as? Cat)?.name }

        #expect(writer.savedTaskIds.count == 3)
        #expect(Set(pendingTaskIds) == Set(writer.savedTaskIds))
        #expect(pendingCatNames == ["Luna"])
    }

    /// "Not saved" has to hold for the context too: a later, unrelated save must not commit the
    /// cat or any starter task without their reminders.
    @Test
    func aFailedFirstCommitLeavesNothingStaged() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)
        try context.save()
        let writer = CareTaskWriter(scheduler: scheduler, saveContext: { _ in throw SaveFailure() })
        var tempData = TempCatData()
        tempData.name = "Luna"

        await #expect(throws: SaveFailure.self) {
            _ = try await OnboardingDataBuilder(taskWriter: writer).createCatAndTasks(
                from: tempData,
                selectedTasks: [.feeding, .water, .litterBox],
                in: context
            )
        }

        #expect(context.insertedModelsArray.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Cat>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareTask>()).isEmpty)
        #expect(scheduler.resyncAttemptCount == 0)
    }

    /// Once the first write has committed everything, a later write that fails is stale reminders
    /// on its task, not "not saved".
    @Test
    func aFailedLaterWriteReportsItsTaskAsStaleNotUnsaved() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)
        var saveCount = 0
        scheduler.observe(container)
        let writer = CareTaskWriter(scheduler: scheduler, saveContext: { context in
            saveCount += 1
            guard saveCount == 1 else { throw SaveFailure() }
            try context.save()
        })
        var tempData = TempCatData()
        tempData.name = "Luna"

        let error = try await #require(throws: CareTaskRemindersOutOfSyncError.self) {
            _ = try await OnboardingDataBuilder(taskWriter: writer).createCatAndTasks(
                from: tempData,
                selectedTasks: [.feeding, .water, .litterBox],
                in: context
            )
        }

        let tasks = try context.fetch(FetchDescriptor<CareTask>())
        let taskIds = Set(tasks.map(\.id))

        #expect(try context.fetch(FetchDescriptor<Cat>()).map(\.name) == ["Luna"])
        #expect(tasks.count == 3)
        // The first write committed every task, and its full resync covered all three.
        #expect(scheduler.resyncCount == 1)
        #expect(Set(scheduler.lastResyncedInfos.map(\.taskId)) == taskIds)
        // The two writes that failed name their own tasks.
        #expect(error.taskIds.count == 2)
        #expect(Set(error.taskIds).isSubset(of: taskIds))
        #expect(error.underlyingError is SaveFailure)
    }

    private func makeSUT(now: @escaping () -> Date = Date.init) -> OnboardingDataBuilder {
        OnboardingDataBuilder(taskWriter: CareTaskWriter(scheduler: scheduler), now: now)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }

    private func hour(for date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }
}

/// Records what the context held, uncommitted, when the first `save` arrived. Commits nothing.
private final class FirstSaveRecordingWriter: CareTaskWriting {
    private(set) var pendingAtFirstSave: [any PersistentModel]?
    private(set) var savedTaskIds: [UUID] = []

    func save(_ task: CareTask, in context: ModelContext) async throws {
        if pendingAtFirstSave == nil {
            pendingAtFirstSave = context.insertedModelsArray
        }
        savedTaskIds.append(task.id)
    }

    func delete(_ task: CareTask, in context: ModelContext) async throws {}

    func complete(
        _ task: CareTask,
        with input: CareTaskCompletionInput,
        in context: ModelContext
    ) async throws {}

    func snooze(_ task: CareTask, minutes: Int) async throws {}

    func refreshReminders(for taskIds: [UUID], in context: ModelContext) async throws {}
}

private struct SaveFailure: Error {}
