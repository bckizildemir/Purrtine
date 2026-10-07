import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import CatCareCalendar

@Suite
@MainActor
struct NotificationActionCoordinatorTests {
    @Test
    func completeActionSilentlyCompletesPendingTask() async throws {
        let fixture = try makeFixture(frequency: .once, authorizationStatus: .authorized)

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
        let fixture = try makeFixture(frequency: .daily, authorizationStatus: .authorized)

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
        let fixture = try makeFixture(frequency: .daily, authorizationStatus: .authorized)
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
        let fixture = try makeFixture(frequency: .once, authorizationStatus: .authorized)

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
        let fixture = try makeFixture(frequency: .once, authorizationStatus: .authorized)

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

    @Test
    func coldLaunchSnoozeRefreshesAuthorizationBeforeScheduling() async throws {
        let fixture = try makeFixture(frequency: .once, authorizationStatus: .authorized)

        let result = await fixture.coordinator.handle(.snooze(minutes: 10), taskId: fixture.task.id)

        #expect(result.didPerformAction)
        #expect(fixture.authorizationChecker.refreshCallCount == 1)
        #expect(fixture.spy.snoozedRequests.first?.delayMinutes == 10)
        #expect(fixture.spy.removedDeliveredTaskIds == [fixture.task.id])
        #expect(fixture.spy.syncBadgeCallCount == 1)
    }

    private func makeFixture(
        frequency: CareTaskFrequency,
        authorizationStatus: UNAuthorizationStatus
    ) throws -> (
        container: ModelContainer,
        task: CareTask,
        schedule: CareTaskSchedule,
        spy: NotificationSchedulerSpy,
        authorizationChecker: NotificationAuthorizationCheckerSpy,
        coordinator: NotificationActionCoordinator
    ) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let spy = NotificationSchedulerSpy()
        spy.observe(container)
        let authorizationChecker = NotificationAuthorizationCheckerSpy(status: authorizationStatus)
        let coordinator = NotificationActionCoordinator(
            modelContainer: container,
            taskWriter: CareTaskWriter(scheduler: spy),
            authorizationChecker: authorizationChecker
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

        return (container, task, schedule, spy, authorizationChecker, coordinator)
    }

    private func fetchTask(id: UUID, in container: ModelContainer) throws -> CareTask? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CareTask>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

@MainActor
private final class NotificationAuthorizationCheckerSpy: NotificationAuthorizationChecking {
    private(set) var refreshCallCount = 0
    private let status: UNAuthorizationStatus

    init(status: UNAuthorizationStatus) {
        self.status = status
    }

    func refreshAuthorizationStatusFromSystem() async -> UNAuthorizationStatus {
        refreshCallCount += 1
        return status
    }
}
