import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@MainActor
struct CatDeletionServiceTests {
    @Test
    func deletingCatRemovesExclusiveTaskAndFinishesCleanupBeforeReturning() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let cat = Cat(name: "Mochi", photoURLs: ["mochi-1.jpg", "mochi-2.jpg"])
        let task = CareTask(title: "Brush Mochi", category: .grooming)
        task.assignedCats = [cat]
        context.insert(cat)
        context.insert(task)
        try context.save()
        var deletedPhotos: [String] = []
        let spy = NotificationSchedulerSpy()
        spy.observe(container)
        let sut = CatDeletionService(
            taskWriter: CareTaskWriter(scheduler: spy),
            deletePhoto: { deletedPhotos.append($0) }
        )

        let summary = try await sut.delete(cat, from: context)

        #expect(deletedPhotos == ["mochi-1.jpg", "mochi-2.jpg"])
        #expect(summary.deletedPhotoFileNames == deletedPhotos)
        #expect(summary.deletedTaskIds == [task.id])
        #expect(spy.resyncCount == 1)
        #expect(spy.lastResyncedInfos.isEmpty)
        #expect(try context.fetch(FetchDescriptor<Cat>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareTask>()).isEmpty)
    }

    @Test
    func deletingCatPreservesSharedTaskAndReschedulesForRemainingCatBeforeReturning() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let deletedCat = Cat(name: "Mochi")
        let remainingCat = Cat(name: "Luna")
        let task = CareTask(
            title: "Clean water bowls",
            description: "Refresh both bowls",
            category: .water,
            iconName: "drop.fill",
            priority: .high
        )
        task.assignedCats = [deletedCat, remainingCat]
        let scheduledDate = Date(timeIntervalSince1970: 1_800_000_000)
        let scheduledTime = Date(timeIntervalSince1970: 1_800_036_000)
        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            frequency: .weekly,
            frequencyInterval: 2,
            reminderMinutes: 45,
            customDays: [2, 5]
        )
        task.schedules = [schedule]
        context.insert(deletedCat)
        context.insert(remainingCat)
        context.insert(task)
        try context.save()
        let spy = NotificationSchedulerSpy()
        spy.observe(container)
        let sut = CatDeletionService(taskWriter: CareTaskWriter(scheduler: spy), deletePhoto: { _ in })

        let summary = try await sut.delete(deletedCat, from: context)

        let tasks = try context.fetch(FetchDescriptor<CareTask>())
        let remainingTask = try #require(tasks.first)
        #expect(tasks.count == 1)
        #expect(remainingTask.id == task.id)
        #expect(remainingTask.assignedCats.map(\.name) == ["Luna"])
        #expect(summary.deletedTaskIds.isEmpty)

        let rescheduleGroup = spy.lastResyncedInfos
        let rescheduleInfo = try #require(rescheduleGroup.first)
        #expect(spy.resyncCount == 1)
        #expect(rescheduleGroup.count == 1)
        #expect(rescheduleInfo.scheduleId == schedule.id)
        #expect(rescheduleInfo.taskId == task.id)
        #expect(rescheduleInfo.taskTitle == "Clean water bowls")
        #expect(rescheduleInfo.taskDescription == "Refresh both bowls")
        #expect(rescheduleInfo.catNames == "Luna")
        #expect(rescheduleInfo.category == .water)
        #expect(rescheduleInfo.iconName == "drop.fill")
        #expect(rescheduleInfo.priority == .high)
        #expect(rescheduleInfo.scheduledDate == scheduledDate)
        #expect(rescheduleInfo.scheduledTime == scheduledTime)
        #expect(rescheduleInfo.frequency == .weekly)
        #expect(rescheduleInfo.frequencyInterval == 2)
        #expect(rescheduleInfo.customDays == [2, 5])
        #expect(rescheduleInfo.reminderMinutes == 45)
    }

    // MARK: - Failures

    /// The cat is gone once the delete commits, so a reminder failure after it reads as "deleted,
    /// reminders stale" — never as "not deleted".
    @Test
    func reminderRefreshFailureAfterTheCommitThrowsRemindersOutOfSync() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let (cat, task) = try insertCatWithTask(in: context)
        let writer = CareTaskWriterSpy()
        writer.refreshError = RefreshFailure()
        var deletedPhotos: [String] = []
        let sut = CatDeletionService(taskWriter: writer, deletePhoto: { deletedPhotos.append($0) })

        let error = try await #require(throws: CareTaskRemindersOutOfSyncError.self) {
            try await sut.delete(cat, from: context)
        }

        #expect(error.taskIds == [task.id])
        #expect(error.underlyingError is RefreshFailure)
        #expect(writer.refreshedTaskIds == [[task.id]])
        #expect(deletedPhotos == ["mochi.jpg"])
        #expect(try context.fetch(FetchDescriptor<Cat>()).isEmpty)
    }

    /// The real writer already wraps its scheduler failure; the service must not wrap it twice.
    @Test
    func writerOutOfSyncErrorPassesThroughUnwrapped() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let (cat, task) = try insertCatWithTask(in: context)
        let spy = NotificationSchedulerSpy()
        spy.observe(container)
        spy.resyncError = .forcedFailure
        let sut = CatDeletionService(taskWriter: CareTaskWriter(scheduler: spy), deletePhoto: { _ in })

        let error = try await #require(throws: CareTaskRemindersOutOfSyncError.self) {
            try await sut.delete(cat, from: context)
        }

        #expect(error.taskIds == [task.id])
        #expect(!(error.underlyingError is CareTaskRemindersOutOfSyncError))
        #expect(try context.fetch(FetchDescriptor<Cat>()).isEmpty)
    }

    /// Cancellation is not a reminder failure: it reaches the caller as itself, and the delete stands.
    @Test
    func cancellationDuringTheRefreshPassesThroughAndTheDeleteStands() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let (cat, _) = try insertCatWithTask(in: context)
        let writer = CareTaskWriterSpy()
        writer.refreshError = CancellationError()
        let sut = CatDeletionService(taskWriter: writer, deletePhoto: { _ in })

        await #expect(throws: CancellationError.self) {
            try await sut.delete(cat, from: context)
        }

        #expect(try context.fetch(FetchDescriptor<Cat>()).isEmpty)
    }

    /// A failed commit throws the commit error itself. Nothing was written, so no photo is deleted
    /// and no reminder is touched; the delete stays staged for the next save (#7 behaviour).
    @Test
    func commitFailureThrowsTheCommitErrorAndTouchesNothingElse() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let (cat, _) = try insertCatWithTask(in: context)
        let writer = CareTaskWriterSpy()
        var deletedPhotos: [String] = []
        let sut = CatDeletionService(
            taskWriter: writer,
            deletePhoto: { deletedPhotos.append($0) },
            saveContext: { _ in throw CommitFailure() }
        )

        await #expect(throws: CommitFailure.self) {
            try await sut.delete(cat, from: context)
        }

        #expect(deletedPhotos.isEmpty)
        #expect(writer.refreshedTaskIds.isEmpty)
    }

    // MARK: - Helpers

    private func insertCatWithTask(in context: ModelContext) throws -> (Cat, CareTask) {
        let cat = Cat(name: "Mochi", photoURLs: ["mochi.jpg"])
        let task = CareTask(title: "Brush Mochi", category: .grooming)
        task.assignedCats = [cat]
        context.insert(cat)
        context.insert(task)
        try context.save()
        return (cat, task)
    }
}

private struct RefreshFailure: Error {}
private struct CommitFailure: Error {}
