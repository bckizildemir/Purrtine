import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Purrtine

@Suite
@MainActor
struct NotificationActionCoordinatorTests {
    @Test
    func completeActionSilentlyCompletesPendingTask() async throws {
        let fixture = try makeFixture(frequency: .once)

        let result = await fixture.coordinator.handle(.complete, taskId: fixture.task.id)
        let refreshedTask = try fetchTask(id: fixture.task.id, in: fixture.container)
        let task = try #require(refreshedTask)

        #expect(result.didPerformAction)
        #expect(task.status == .completed)
        #expect(task.completions.count == 1)
        #expect(fixture.spy.resyncCount == 1)
        #expect(fixture.spy.lastResyncedInfos.isEmpty)
        #expect(fixture.spy.removedDeliveredTaskIds == [fixture.task.id])
        #expect(fixture.spy.syncBadgeCallCount == 1)
    }

    @Test
    func completeActionForRecurringTaskCreatesNextOccurrenceAndReschedules() async throws {
        let fixture = try makeFixture(frequency: .daily)

        let result = await fixture.coordinator.handle(.complete, taskId: fixture.task.id)
        let refreshedTask = try fetchTask(id: fixture.task.id, in: fixture.container)
        let task = try #require(refreshedTask)
        let activeSchedules = task.schedules.filter(\.isActive)
        let nextSchedule = try #require(activeSchedules.first)

        #expect(result.didPerformAction)
        #expect(task.status == .pending)
        #expect(task.completions.count == 1)
        #expect(activeSchedules.count == 1)
        #expect(nextSchedule.id != fixture.schedule.id)
        #expect(fixture.spy.removedDeliveredTaskIds == [fixture.task.id])
        #expect(fixture.spy.syncBadgeCallCount == 1)
        #expect(fixture.spy.resyncCount == 1)
        #expect(fixture.spy.lastResyncedInfos.map(\.scheduleId) == [nextSchedule.id])
    }

    /// The completion committed, so reporting failure would invite a second completion of the same
    /// occurrence. Stale reminders are the next resync's job.
    @Test
    func completeActionWithStaleRemindersStillReportsThePerformedAction() async throws {
        let fixture = try makeFixture(frequency: .daily)
        fixture.spy.resyncError = .forcedFailure

        let result = await fixture.coordinator.handle(.complete, taskId: fixture.task.id)
        let refreshedTask = try fetchTask(id: fixture.task.id, in: fixture.container)
        let task = try #require(refreshedTask)

        #expect(result.didPerformAction)
        #expect(task.completions.count == 1)
        #expect(fixture.spy.removedDeliveredTaskIds == [fixture.task.id])
    }

    @Test
    func snoozeActionCreatesExpectedDelayedRequest() async throws {
        let fixture = try makeFixture(frequency: .once)

        let result = await fixture.coordinator.handle(.snooze(minutes: 10), taskId: fixture.task.id)

        #expect(result.didPerformAction)
        #expect(fixture.task.status == .pending)
        #expect(fixture.spy.snoozedRequests.count == 1)
        #expect(fixture.spy.snoozedRequests.first?.taskId == fixture.task.id)
        #expect(fixture.spy.snoozedRequests.first?.delayMinutes == 10)
        #expect(fixture.spy.removedDeliveredTaskIds == [fixture.task.id])
        #expect(fixture.spy.syncBadgeCallCount == 1)
    }

    @Test
    func invalidTaskIdentifierIsNoOpAndKeepsDeliveredNotification() async throws {
        let fixture = try makeFixture(frequency: .once)

        let result = await fixture.coordinator.handle(.complete, taskId: UUID())
        let refreshedTask = try fetchTask(id: fixture.task.id, in: fixture.container)
        let task = try #require(refreshedTask)

        #expect(result.didPerformAction == false)
        #expect(task.status == .pending)
        #expect(task.completions.isEmpty)
        #expect(fixture.spy.resyncAttemptCount == 0)
        #expect(fixture.spy.removedDeliveredTaskIds.isEmpty)
        #expect(fixture.spy.syncBadgeCallCount == 0)
    }

    /// The scheduler checks the permission itself and throws; the coordinator reports no action.
    @Test
    func snoozeActionWithoutPermissionReportsNoActionAndKeepsDeliveredNotification() async throws {
        let fixture = try makeFixture(frequency: .once)
        fixture.spy.snoozeError = NotificationSchedulingError.unauthorized

        let result = await fixture.coordinator.handle(.snooze(minutes: 10), taskId: fixture.task.id)

        #expect(result.didPerformAction == false)
        #expect(fixture.spy.snoozedRequests.isEmpty)
        #expect(fixture.spy.removedDeliveredTaskIds.isEmpty)
    }

    @Test
    func snoozeActionWithRemindersOffReportsNoAction() async throws {
        let fixture = try makeFixture(frequency: .once)
        fixture.spy.snoozeError = NotificationSchedulingError.remindersOff

        let result = await fixture.coordinator.handle(.snooze(minutes: 10), taskId: fixture.task.id)

        #expect(result.didPerformAction == false)
        #expect(fixture.spy.removedDeliveredTaskIds.isEmpty)
    }

    private func makeFixture(frequency: CareTaskFrequency) throws -> (
        container: ModelContainer,
        task: CareTask,
        schedule: CareTaskSchedule,
        spy: NotificationSchedulerSpy,
        coordinator: NotificationActionCoordinator
    ) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let spy = NotificationSchedulerSpy()
        spy.observe(container)
        let coordinator = NotificationActionCoordinator(
            modelContainer: container,
            taskWriter: CareTaskWriter(scheduler: spy)
        )

        let cat = Cat(name: "Mochi")
        let caregiver = Caregiver(name: "Primary Caregiver", role: .primary)
        let task = CareTask(title: "Feed Mochi")
        let schedule = CareTaskSchedule(
            scheduledDate: Calendar.current.startOfDay(for: Date()),
            frequency: frequency,
            frequencyInterval: 1,
            endDate: nil,
            reminderMinutes: 15
        )

        task.assignedCats = [cat]
        task.assignedCaregiver = caregiver
        schedule.task = task
        task.schedules = [schedule]

        context.insert(cat)
        context.insert(caregiver)
        context.insert(task)
        context.insert(schedule)
        try context.save()

        return (container, task, schedule, spy, coordinator)
    }

    private func fetchTask(id: UUID, in container: ModelContainer) throws -> CareTask? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CareTask>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
