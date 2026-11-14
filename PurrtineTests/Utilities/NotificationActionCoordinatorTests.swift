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

    /// Yesterday's reminder is still on the lock screen after yesterday was completed in the app.
    /// Today's occurrence is open now, and the stale Complete must not record it.
    @Test
    func completeActionForAnOccurrenceAlreadyCompletedRecordsNothing() async throws {
        let fixture = try makeFixture(frequency: .daily, authorizationStatus: .authorized)
        let yesterdaysOccurrence = fixture.schedule.scheduledDate
        _ = await fixture.coordinator.handle(.complete, taskId: fixture.task.id)
        let resyncsBefore = fixture.spy.resyncCount

        let result = await fixture.coordinator.handle(
            .complete,
            taskId: fixture.task.id,
            occurrence: yesterdaysOccurrence
        )
        let task = try #require(try fetchTask(id: fixture.task.id, in: fixture.container))

        #expect(result.didPerformAction == false)
        #expect(task.completions.count == 1)
        #expect(task.activeSchedule?.scheduledDate != yesterdaysOccurrence)
        #expect(fixture.spy.resyncCount == resyncsBefore)
    }

    /// Yesterday is still open, today's reminder fires and the caregiver taps Complete on it.
    /// Recording today would skip yesterday, and recording yesterday credits the wrong day.
    @Test
    func completeActionForALaterOccurrenceThanTheOpenOneRecordsNothing() async throws {
        let fixture = try makeFixture(frequency: .daily, authorizationStatus: .authorized)
        let laterOccurrence = try #require(
            Calendar.current.date(byAdding: .day, value: 1, to: fixture.schedule.scheduledDate)
        )

        let result = await fixture.coordinator.handle(
            .complete,
            taskId: fixture.task.id,
            occurrence: laterOccurrence
        )
        let task = try #require(try fetchTask(id: fixture.task.id, in: fixture.container))

        #expect(result.didPerformAction == false)
        #expect(task.completions.isEmpty)
        #expect(task.activeSchedule?.id == fixture.schedule.id)
    }

    @Test
    func completeActionForTheOpenOccurrenceRecordsIt() async throws {
        let fixture = try makeFixture(frequency: .daily, authorizationStatus: .authorized)

        let result = await fixture.coordinator.handle(
            .complete,
            taskId: fixture.task.id,
            occurrence: fixture.schedule.scheduledDate
        )
        let task = try #require(try fetchTask(id: fixture.task.id, in: fixture.container))

        #expect(result.didPerformAction)
        #expect(task.completions.count == 1)
        #expect(task.activeSchedule?.id != fixture.schedule.id)
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

    /// The coordinator hands the reminder's occurrence to the snooze, and a snooze with none postpones
    /// the occurrence open now.
    @Test
    func snoozeActionPassesTheReminderOccurrenceOrTheOpenOne() async throws {
        let fixture = try makeFixture(frequency: .daily, authorizationStatus: .authorized)
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: fixture.schedule.scheduledDate))

        _ = await fixture.coordinator.handle(.snooze(minutes: 10), taskId: fixture.task.id, occurrence: tomorrow)
        _ = await fixture.coordinator.handle(.snooze(minutes: 10), taskId: fixture.task.id)

        #expect(fixture.spy.snoozedOccurrences == [tomorrow, fixture.schedule.scheduledDate])
    }

    /// A snooze made from the reminder for day D carries D in the content a later Complete reads. With an
    /// earlier day still open, that Complete records nothing.
    @Test
    func aSnoozedReminderCarriesItsDayAndCannotCompleteAnotherOne() async throws {
        let fixture = try makeFixture(frequency: .daily, authorizationStatus: .authorized)
        let reminderDay = try #require(Calendar.current.date(byAdding: .day, value: 1, to: fixture.schedule.scheduledDate))
        let center = FakeUserNotificationCenterClient()
        let manager = try await makeManager(center: center)

        try await manager.scheduleSnoozedNotification(
            for: NotificationScheduleInfo(
                snoozing: fixture.task,
                firingAt: Date().addingTimeInterval(600),
                occurrence: reminderDay
            ),
            delayMinutes: 10
        )
        let snooze = try #require(center.addedRequests.last)
        let carried = try #require(snooze.content.userInfo[NotificationManager.occurrenceDateKey] as? Double)
        let result = await fixture.coordinator.handle(
            .complete,
            taskId: fixture.task.id,
            occurrence: Date(timeIntervalSince1970: carried)
        )
        let task = try #require(try fetchTask(id: fixture.task.id, in: fixture.container))

        #expect(carried == reminderDay.timeIntervalSince1970)
        #expect(result.didPerformAction == false)
        #expect(task.completions.isEmpty)
        #expect(task.activeSchedule?.id == fixture.schedule.id)
    }

    /// The whole path: a resync schedules the reminders, one is read back from the center, and its
    /// Complete records the day it was made for. The task is due at 07:47 on a later day, so neither
    /// its schedule date nor its time of day is midnight.
    @Test
    func aScheduledReminderCompletesTheDayItWasMadeFor() async throws {
        let calendar = Calendar.current
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())))
        let due = try #require(calendar.date(byAdding: .minute, value: 7 * 60 + 47, to: tomorrow))
        let caregiver = Caregiver(name: "Primary Caregiver", role: .primary)
        let task = CareTask(title: "Feed Mochi")
        let schedule = CareTaskSchedule(
            scheduledDate: due,
            scheduledTime: due,
            frequency: .daily,
            frequencyInterval: 1,
            endDate: nil,
            reminderMinutes: 15
        )
        task.assignedCaregiver = caregiver
        schedule.task = task
        task.schedules = [schedule]
        context.insert(caregiver)
        context.insert(task)
        context.insert(schedule)
        try context.save()
        let center = FakeUserNotificationCenterClient()
        let manager = try await makeManager(center: center)
        let coordinator = NotificationActionCoordinator(
            modelContainer: container,
            taskWriter: CareTaskWriter(scheduler: NotificationSchedulerSpy()),
            authorizationChecker: NotificationAuthorizationCheckerSpy(status: .authorized)
        )

        try await manager.resyncCareTaskNotifications(with: NotificationScheduleInfo.activeInfos(for: task))
        let firstReminder = try #require(
            center.pendingRequests
                .compactMap { $0.content.userInfo[NotificationManager.occurrenceDateKey] as? Double }
                .min()
        )
        let result = await coordinator.handle(
            .complete,
            taskId: task.id,
            occurrence: Date(timeIntervalSince1970: firstReminder)
        )
        let completedTask = try #require(try fetchTask(id: task.id, in: container))

        #expect(result.didPerformAction)
        #expect(completedTask.completions.count == 1)
        #expect(completedTask.completions.first?.completedForDate == tomorrow)
        #expect(TaskActionService.openOccurrence(of: completedTask) == calendar.date(byAdding: .day, value: 1, to: tomorrow))
    }

    /// A reminder's Complete saves in its own context, and the main context still holds the task it
    /// loaded before. The writer reads the store as it is now before it validates, so the app's
    /// completion for the same day is refused instead of recording that day twice (#141).
    @Test
    func aCompletionSavedInAnotherContextRefusesTheSameDayInTheMainContext() async throws {
        let fixture = try makeFixture(frequency: .daily, authorizationStatus: .authorized)
        let day = fixture.schedule.scheduledDate
        let mainContext = fixture.container.mainContext
        let writer = CareTaskWriter(scheduler: NotificationSchedulerSpy())

        _ = await fixture.coordinator.handle(.complete, taskId: fixture.task.id, occurrence: day)

        await #expect(throws: TaskActionError.occurrenceNotOpen) {
            try await writer.complete(
                fixture.task,
                with: CareTaskCompletionInput(expectedOccurrence: day),
                in: mainContext
            )
        }
        #expect(fixture.task.completions.count == 1)
    }

    /// The same window with no expected day (a one-tap row): the app completes the NEXT day once, not
    /// day D again.
    @Test
    func anInAppCompletionAfterAReminderCompletionRecordsTheNextDayOnce() async throws {
        let fixture = try makeFixture(frequency: .daily, authorizationStatus: .authorized)
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: fixture.schedule.scheduledDate)
        let nextDay = try #require(calendar.date(byAdding: .day, value: 1, to: day))
        let dayAfter = try #require(calendar.date(byAdding: .day, value: 2, to: day))
        let mainContext = fixture.container.mainContext
        let writer = CareTaskWriter(scheduler: NotificationSchedulerSpy())

        _ = await fixture.coordinator.handle(.complete, taskId: fixture.task.id, occurrence: day)
        try await writer.complete(fixture.task, with: CareTaskCompletionInput(), in: mainContext)

        let days = fixture.task.completions.map(\.completedForDate).sorted()
        #expect(days == [day, nextDay])
        #expect(TaskActionService.openOccurrence(of: fixture.task) == dayAfter)
    }

    /// The refresh reads the store; it must not throw away a change the main context has staged and
    /// not saved. The next commit still carries it.
    @Test
    func theRefreshKeepsAStagedChangeOfTheMainContext() async throws {
        let fixture = try makeFixture(frequency: .daily, authorizationStatus: .authorized)
        let day = fixture.schedule.scheduledDate
        let mainContext = fixture.container.mainContext
        let writer = CareTaskWriter(scheduler: NotificationSchedulerSpy())
        fixture.task.taskDescription = "Staged, not saved"
        fixture.task.title = "Feed Mochi (staged)"

        _ = await fixture.coordinator.handle(.complete, taskId: fixture.task.id, occurrence: day)
        try await writer.complete(fixture.task, with: CareTaskCompletionInput(), in: mainContext)

        #expect(fixture.task.taskDescription == "Staged, not saved")
        #expect(fixture.task.title == "Feed Mochi (staged)")
        #expect(fixture.task.completions.count == 2)
        let stored = try #require(try fetchTask(id: fixture.task.id, in: fixture.container))
        #expect(stored.taskDescription == "Staged, not saved")
        #expect(stored.completions.count == 2)
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

    private func makeManager(center: FakeUserNotificationCenterClient) async throws -> NotificationManager {
        let defaults = try #require(UserDefaults(suiteName: "NotificationActionCoordinatorTests.\(UUID().uuidString)"))
        let manager = NotificationManager(
            notificationCenter: center,
            settingsStore: NotificationSettingsStore(userDefaults: defaults, key: "settings")
        )
        await manager.checkAuthorizationStatus()
        return manager
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
