import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

/// Exercises the care-task mutation seam through `CareTaskWriting` only. The store is real and the
/// scheduler is one spy, because the guarantee under test couples the two: when a verb returns
/// without throwing, a full resync has run over what the store held after the commit. The spy
/// records that store state in `resyncedInfos`.
@MainActor
struct CareTaskWriterTests {
    let container: ModelContainer
    let context: ModelContext
    let spy = NotificationSchedulerSpy()
    let sut: any CareTaskWriting

    init() throws {
        container = try TestModelContainerFactory.makeInMemoryContainer()
        context = container.mainContext
        sut = CareTaskWriter(scheduler: spy)
        spy.observe(container)
    }

    // MARK: - save

    @Test
    func savingANewTaskCommitsItThenResyncsWithItsActiveSchedule() async throws {
        let (task, schedule) = makeTask(title: "Feed Mochi")

        try await sut.save(task, in: context)

        #expect(context.hasChanges == false)
        #expect(try fetchTaskIds() == [task.id])
        #expect(spy.resyncCount == 1)
        #expect(spy.lastResyncedInfos.map(\.scheduleId) == [schedule.id])
        #expect(spy.lastResyncedInfos.map(\.taskTitle) == ["Feed Mochi"])
    }

    @Test
    func savingATaskWithNoActiveScheduleResyncsWithNothingToRemindOf() async throws {
        let (task, schedule) = makeTask(title: "Old routine")
        schedule.isActive = false

        try await sut.save(task, in: context)

        #expect(spy.resyncCount == 1)
        #expect(spy.lastResyncedInfos.isEmpty)
    }

    /// A data edit must survive a reminder failure: the caller gets the named error, and the task
    /// is in the store all the same.
    @Test
    func aFailedResyncAfterSaveThrowsTheNamedErrorAndKeepsTheTask() async throws {
        let (task, _) = makeTask(title: "Feed Mochi")
        spy.resyncError = .forcedFailure

        let error = try await #require(throws: CareTaskRemindersOutOfSyncError.self) {
            try await sut.save(task, in: context)
        }

        #expect(error.taskIds == [task.id])
        #expect(context.hasChanges == false)
        #expect(try fetchTaskIds() == [task.id])
    }

    /// Cancellation is not a reminder failure: it reaches the caller as itself, and the commit stands.
    @Test
    func aCancelledResyncPassesCancellationThroughUnwrappedAndKeepsTheTask() async throws {
        let (task, _) = makeTask(title: "Feed Mochi")
        spy.isResyncCancelled = true

        await #expect(throws: CancellationError.self) {
            try await sut.save(task, in: context)
        }

        #expect(context.hasChanges == false)
        #expect(try fetchTaskIds() == [task.id])
    }

    // MARK: - delete

    @Test(.bug("https://github.com/bckizildemir/CatCareCalendar/issues/12", id: 12))
    func deletingATaskRemovesItThenResyncsWithoutIt() async throws {
        let (task, _) = makeTask(title: "Feed Mochi")
        try await sut.save(task, in: context)

        try await sut.delete(task, in: context)

        #expect(try fetchTaskIds().isEmpty)
        #expect(spy.resyncCount == 2)
        #expect(spy.lastResyncedInfos.isEmpty)
        #expect(spy.cancelledSnoozeTaskIds == [task.id])
    }

    @Test
    func aFailedResyncAfterDeleteThrowsTheNamedErrorAndTheTaskStaysDeleted() async throws {
        let (task, _) = makeTask(title: "Feed Mochi")
        try await sut.save(task, in: context)
        spy.resyncError = .forcedFailure

        await #expect(throws: CareTaskRemindersOutOfSyncError.self) {
            try await sut.delete(task, in: context)
        }

        #expect(try fetchTaskIds().isEmpty)
    }

    // MARK: - complete

    @Test
    func completingAOneTimeTaskCommitsThenResyncsWithNothingToRemindOf() async throws {
        let (task, _) = makeTask(title: "Vet visit")
        try await sut.save(task, in: context)
        context.insert(Caregiver(name: "Primary", role: .primary))

        try await sut.complete(task, with: CareTaskCompletionInput(), in: context)

        #expect(context.hasChanges == false)
        #expect(task.status == .completed)
        #expect(spy.resyncCount == 2)
        #expect(spy.lastResyncedInfos.isEmpty)
        #expect(spy.cancelledSnoozeTaskIds == [task.id])
        #expect(spy.removedDeliveredTaskIds == [task.id])
        #expect(spy.syncBadgeCallCount == 1)
    }

    @Test(.bug("https://github.com/bckizildemir/CatCareCalendar/issues/12", id: 12))
    func completingARecurringTaskReschedulesOnlyTheNextOccurrence() async throws {
        let (task, firstSchedule) = makeTask(title: "Feed Mochi", frequency: .daily)
        try await sut.save(task, in: context)
        context.insert(Caregiver(name: "Primary", role: .primary))

        try await sut.complete(task, with: CareTaskCompletionInput(), in: context)

        let nextSchedule = try #require(task.activeSchedule)
        #expect(nextSchedule.id != firstSchedule.id)
        #expect(spy.lastResyncedInfos.map(\.scheduleId) == [nextSchedule.id])
        // A snooze belongs to the occurrence just completed, not to the next one.
        #expect(spy.cancelledSnoozeTaskIds == [task.id])
    }

    /// A committed completion that reports plain failure invites a second completion of the same
    /// occurrence, so the caller has to be able to tell this apart from "not completed".
    @Test
    func aFailedResyncAfterCompletionThrowsTheNamedErrorAndStillClearsDeliveredReminders() async throws {
        let (task, _) = makeTask(title: "Feed Mochi", frequency: .daily)
        try await sut.save(task, in: context)
        context.insert(Caregiver(name: "Primary", role: .primary))
        spy.resyncError = .forcedFailure

        await #expect(throws: CareTaskRemindersOutOfSyncError.self) {
            try await sut.complete(task, with: CareTaskCompletionInput(), in: context)
        }

        #expect(context.hasChanges == false)
        #expect(task.completionCount == 1)
        #expect(spy.removedDeliveredTaskIds == [task.id])
        #expect(spy.syncBadgeCallCount == 1)
    }

    @Test
    func completingWithNoCaregiverCommitsNothingAndTouchesNoReminders() async throws {
        let (task, _) = makeTask(title: "Feed Mochi")
        try await sut.save(task, in: context)
        let attemptsBefore = spy.resyncAttemptCount

        await #expect(throws: TaskActionError.caregiverUnavailable) {
            try await sut.complete(task, with: CareTaskCompletionInput(), in: context)
        }

        #expect(task.completions.isEmpty)
        #expect(spy.resyncAttemptCount == attemptsBefore)
        #expect(spy.removedDeliveredTaskIds.isEmpty)
    }

    // MARK: - A failed commit

    /// A new task that fails to commit must not stay staged: the next unrelated save would commit it
    /// with no resync, and a form that retries would stage a second copy. The undo is targeted, so a
    /// change someone else staged in the same context survives. `callerInsertedFirst` covers
    /// `TaskFormPersistence.createTask`, which inserts the task before the writer sees it.
    @Test(arguments: [false, true])
    func aFailedCommitOfANewTaskUnstagesItAndKeepsUnrelatedPendingChanges(callerInsertedFirst: Bool) async throws {
        let assignedCat = Cat(name: "Mochi")
        context.insert(assignedCat)
        try context.save()
        let unrelatedCat = Cat(name: "Unrelated")
        context.insert(unrelatedCat)
        let (task, schedule) = makeTask(title: "Feed Mochi", cats: [assignedCat])
        if callerInsertedFirst {
            context.insert(task)
            context.insert(schedule)
        }

        await #expect(throws: SaveFailure.self) {
            try await failingWriter().save(task, in: context)
        }

        #expect(insertedIds(of: CareTask.self).isEmpty)
        #expect(insertedIds(of: CareTaskSchedule.self).isEmpty)
        #expect(insertedIds(of: Cat.self) == [unrelatedCat.persistentModelID])
        #expect(spy.resyncAttemptCount == 0)
        try context.save()
        #expect(try fetchTaskIds().isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareTaskSchedule>()).isEmpty)
        #expect(Set(try context.fetch(FetchDescriptor<Cat>()).map(\.name)) == ["Mochi", "Unrelated"])
        #expect(assignedCat.tasks.isEmpty)
    }

    @Test
    func aFailedCommitOfACompletionUndoesOnlyTheCompletionsOwnChanges() async throws {
        let cat = Cat(name: "Mochi")
        context.insert(cat)
        let (task, firstSchedule) = makeTask(title: "Feed Mochi", frequency: .daily)
        try await sut.save(task, in: context)
        context.insert(Caregiver(name: "Primary", role: .primary))
        let statusBefore = task.status
        let updatedAtBefore = task.updatedAt
        try context.save()
        cat.name = "Miso"
        let attemptsBefore = spy.resyncAttemptCount

        await #expect(throws: SaveFailure.self) {
            try await failingWriter().complete(task, with: CareTaskCompletionInput(), in: context)
        }

        #expect(task.completions.isEmpty)
        #expect(task.schedules.map(\.id) == [firstSchedule.id])
        #expect(firstSchedule.isActive)
        #expect(task.status == statusBefore)
        #expect(task.updatedAt == updatedAtBefore)
        #expect(insertedIds(of: CareTaskCompletion.self).isEmpty)
        #expect(insertedIds(of: CareTaskSchedule.self).isEmpty)
        #expect(spy.resyncAttemptCount == attemptsBefore)
        #expect(spy.removedDeliveredTaskIds.isEmpty)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<CareTaskCompletion>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareTaskSchedule>()).map(\.id) == [firstSchedule.id])
        #expect(try context.fetch(FetchDescriptor<Cat>()).map(\.name) == ["Miso"])
    }

    /// A failed delete cannot be undone — see `CareTaskWriter.delete` — so it stays staged. What the
    /// test pins is that nothing else is lost: no reminder is touched and the unrelated change stays.
    @Test
    func aFailedCommitOfADeleteLeavesItStagedAndKeepsUnrelatedPendingChanges() async throws {
        let cat = Cat(name: "Mochi")
        context.insert(cat)
        let (task, _) = makeTask(title: "Feed Mochi", cats: [cat])
        try await sut.save(task, in: context)
        cat.name = "Miso"

        await #expect(throws: SaveFailure.self) {
            try await failingWriter().delete(task, in: context)
        }

        #expect(context.deletedModelsArray.contains { $0.persistentModelID == task.persistentModelID })
        #expect(spy.resyncAttemptCount == 1)
        #expect(cat.hasChanges)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Cat>()).map(\.name) == ["Miso"])
    }

    // MARK: - snooze

    @Test
    func snoozingSchedulesAOneOffReminderAndWritesNothing() async throws {
        let (task, _) = makeTask(title: "Feed Mochi")
        try await sut.save(task, in: context)

        try await sut.snooze(task, minutes: 10)

        #expect(spy.snoozedRequests.map(\.taskId) == [task.id])
        #expect(spy.snoozedRequests.map(\.delayMinutes) == [10])
        #expect(spy.cancelledSnoozeTaskIds.isEmpty)
        #expect(spy.removedDeliveredTaskIds == [task.id])
        #expect(spy.syncBadgeCallCount == 1)
        #expect(context.hasChanges == false)
    }

    @Test(arguments: [-1, 0, Int.max])
    func snoozingRejectsInvalidDurationsWithoutSideEffects(minutes: Int) async throws {
        let (task, _) = makeTask(title: "Feed Mochi")

        await #expect(throws: TaskActionError.invalidPostponeMinutes) {
            try await sut.snooze(task, minutes: minutes)
        }

        #expect(spy.snoozedRequests.isEmpty)
        #expect(spy.removedDeliveredTaskIds.isEmpty)
        #expect(spy.syncBadgeCallCount == 0)
    }

    // MARK: - refreshReminders

    @Test(.bug("https://github.com/bckizildemir/CatCareCalendar/issues/13", id: 13))
    func refreshingAfterACatRenameResyncsOnceWithTheNewName() async throws {
        let cat = Cat(name: "Mochi")
        context.insert(cat)
        let (first, _) = makeTask(title: "Feed", cats: [cat])
        let (second, _) = makeTask(title: "Brush", cats: [cat])
        try await sut.save(first, in: context)
        try await sut.save(second, in: context)
        cat.name = "Miso"
        try context.save()
        let resyncsBefore = spy.resyncCount

        try await sut.refreshReminders(for: [first.id, second.id], in: context)

        let infos = spy.lastResyncedInfos
        #expect(spy.resyncCount == resyncsBefore + 1)
        #expect(Set(infos.map(\.taskId)) == [first.id, second.id])
        #expect(infos.allSatisfy { $0.catNames == "Miso" })
    }

    @Test
    func refreshingAfterADeleteResyncsWithOnlyTheTasksThatRemain() async throws {
        let (survivor, _) = makeTask(title: "Feed")
        let (doomed, _) = makeTask(title: "Brush")
        try await sut.save(survivor, in: context)
        try await sut.save(doomed, in: context)
        let doomedId = doomed.id
        context.delete(doomed)
        try context.save()

        try await sut.refreshReminders(for: [survivor.id, doomedId, survivor.id], in: context)

        #expect(spy.resyncCount == 3)
        #expect(spy.lastResyncedInfos.map(\.taskId) == [survivor.id])
    }

    @Test
    func refreshingNoTasksDoesNotResync() async throws {
        try await sut.refreshReminders(for: [], in: context)

        #expect(spy.resyncAttemptCount == 0)
    }

    /// A failed refresh names the tasks the caller asked about, so its alert can say which ones.
    @Test
    func aFailedRefreshThrowsTheNamedErrorForTheRequestedTasks() async throws {
        let ids = [UUID(), UUID()]
        spy.resyncError = .forcedFailure

        let error = try await #require(throws: CareTaskRemindersOutOfSyncError.self) {
            try await sut.refreshReminders(for: ids, in: context)
        }

        #expect(error.taskIds == ids)
    }

    // MARK: - Helpers

    private func makeTask(
        title: String,
        frequency: CareTaskFrequency = .once,
        cats: [Cat] = []
    ) -> (CareTask, CareTaskSchedule) {
        let task = CareTask(title: title)
        let schedule = CareTaskSchedule(
            scheduledDate: Date().addingTimeInterval(3_600),
            frequency: frequency,
            frequencyInterval: 1,
            reminderMinutes: 15
        )
        schedule.task = task
        task.schedules = [schedule]
        task.assignedCats = cats
        return (task, schedule)
    }

    private func fetchTaskIds() throws -> [UUID] {
        try context.fetch(FetchDescriptor<CareTask>()).map(\.id)
    }

    /// A writer whose commit always fails, so the pre-commit failure path runs against a real store.
    private func failingWriter() -> CareTaskWriter {
        CareTaskWriter(scheduler: spy, saveContext: { _ in throw SaveFailure() })
    }

    private func insertedIds<Model: PersistentModel>(of type: Model.Type) -> [PersistentIdentifier] {
        context.insertedModelsArray.filter { $0 is Model }.map(\.persistentModelID)
    }
}

private struct SaveFailure: Error {}
