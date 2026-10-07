import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import CatCareCalendar

@MainActor
struct CatReminderRefreshServiceTests {
    /// The headline behaviour: `NotificationManager` bakes the cat names into the reminder body at
    /// scheduling time, so the only way a rename reaches a pending reminder is a reschedule. Driven
    /// through the real manager because the rebuilt *content* is the thing under test.
    @Test
    func renamingRebuildsThePendingReminderWithTheNewName() async throws {
        let environment = try makeNotificationEnvironment()
        let cat = environment.cat
        let task = try #require(environment.tasks.first)
        let staleIdentifier = "stale-\(task.id.uuidString)"
        environment.notificationCenter.pendingRequests = [
            makePendingRequest(taskId: task.id, identifier: staleIdentifier)
        ]

        cat.name = "Miso"
        try environment.context.save()

        await CatReminderRefreshService(taskWriter: CareTaskWriter(scheduler: environment.manager))
            .refreshReminders(forTasksOf: cat, in: environment.context)

        let removedIdentifiers = environment.notificationCenter.removedPendingIdentifiers.flatMap { $0 }
        let request = try #require(environment.notificationCenter.addedRequests.first)

        #expect(removedIdentifiers.contains(staleIdentifier))
        #expect(environment.notificationCenter.addedRequests.count == 1)
        #expect(request.content.body == "Brush the cat\n🐱 Miso")
        #expect(request.content.body.contains("Mochi") == false)
    }

    @Test
    func renamingKeepsTheOtherCatsInASharedTaskAndRefreshesOnlyTheChangedName() async throws {
        let environment = try makeNotificationEnvironment()
        let cat = environment.cat
        let task = try #require(environment.tasks.first)
        let luna = Cat(name: "Luna")
        environment.context.insert(luna)
        task.assignedCats = [cat, luna]
        cat.name = "Miso"
        try environment.context.save()

        await CatReminderRefreshService(taskWriter: CareTaskWriter(scheduler: environment.manager))
            .refreshReminders(forTasksOf: cat, in: environment.context)

        // `assignedCats` is a SwiftData relationship, so the join order is not guaranteed — assert
        // on membership rather than on "Miso, Luna" in that order.
        let request = try #require(environment.notificationCenter.addedRequests.first)
        let names = try #require(request.content.body.split(separator: "🐱 ").last)
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        #expect(Set(names) == ["Miso", "Luna"])
        #expect(request.content.body.hasPrefix("Brush the cat\n🐱 "))
        #expect(request.content.body.contains("Mochi") == false)
    }

    // MARK: - Coverage of the cat's tasks

    @Test
    func refreshCoversEveryTaskAssignedToTheCatInOneResync() async throws {
        let fixture = try makeFixture(taskCount: 3)

        await fixture.sut.refreshReminders(forTasksOf: fixture.cat, in: fixture.context)

        let rescheduledTaskIds = Set(fixture.spy.lastResyncedInfos.map(\.taskId))
        #expect(fixture.spy.resyncCount == 1)
        #expect(rescheduledTaskIds == Set(fixture.tasks.map(\.id)))
    }

    @Test
    func refreshCarriesTheCurrentNameIntoEveryScheduleInfo() async throws {
        let fixture = try makeFixture(taskCount: 2)
        fixture.cat.name = "Miso"
        try fixture.context.save()

        await fixture.sut.refreshReminders(forTasksOf: fixture.cat, in: fixture.context)

        let infos = fixture.spy.lastResyncedInfos
        #expect(infos.isEmpty == false)
        #expect(infos.allSatisfy { $0.catNames == "Miso" })
    }

    /// A task whose schedules are all deactivated should have no pending reminder, so the resync
    /// the refresh runs has nothing of it to schedule.
    @Test
    func refreshLeavesNothingToScheduleForATaskWithNoActiveSchedule() async throws {
        let fixture = try makeFixture(taskCount: 2)
        let dormantTask = try #require(fixture.tasks.last)
        for schedule in dormantTask.schedules {
            schedule.isActive = false
        }
        try fixture.context.save()

        await fixture.sut.refreshReminders(forTasksOf: fixture.cat, in: fixture.context)

        let rescheduledTaskIds = Set(fixture.spy.lastResyncedInfos.map(\.taskId))
        #expect(rescheduledTaskIds == [try #require(fixture.tasks.first).id])
        #expect(rescheduledTaskIds.contains(dormantTask.id) == false)
    }

    @Test
    func refreshingACatWithNoTasksTouchesNoReminders() async throws {
        let fixture = try makeFixture(taskCount: 0)

        await fixture.sut.refreshReminders(forTasksOf: fixture.cat, in: fixture.context)

        #expect(fixture.spy.resyncAttemptCount == 0)
    }

    // MARK: - Fixtures

    private func makeFixture(taskCount: Int) throws -> (
        container: ModelContainer,
        context: ModelContext,
        cat: Cat,
        tasks: [CareTask],
        spy: NotificationSchedulerSpy,
        sut: CatReminderRefreshService
    ) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let anchorDate = calendar.date(
            byAdding: .hour,
            value: 9,
            to: calendar.startOfDay(for: Date())
        ) ?? Date()

        let cat = Cat(name: "Mochi")
        context.insert(cat)

        var tasks: [CareTask] = []
        for index in 0..<taskCount {
            let task = CareTask(title: "Cat task \(index)", category: .grooming)
            let schedule = CareTaskSchedule(
                scheduledDate: anchorDate,
                frequency: .once,
                frequencyInterval: 1,
                reminderMinutes: 15
            )
            task.assignedCats = [cat]
            schedule.task = task
            task.schedules = [schedule]
            context.insert(task)
            context.insert(schedule)
            tasks.append(task)
        }

        try context.save()

        let spy = NotificationSchedulerSpy()
        spy.observe(container)
        let sut = CatReminderRefreshService(taskWriter: CareTaskWriter(scheduler: spy))
        return (container, context, cat, tasks, spy, sut)
    }

    private func makeNotificationEnvironment() throws -> (
        container: ModelContainer,
        context: ModelContext,
        cat: Cat,
        tasks: [CareTask],
        notificationCenter: FakeUserNotificationCenterClient,
        manager: NotificationManager
    ) {
        var settings = NotificationSettings.default
        settings.overdueReminderDelayMinutes = nil

        let notificationCenter = FakeUserNotificationCenterClient()
        let defaults = try #require(
            UserDefaults(suiteName: "CatReminderRefreshServiceTests.\(UUID().uuidString)")
        )
        let store = NotificationSettingsStore(userDefaults: defaults, key: "settings")
        store.save(settings)
        let manager = NotificationManager(notificationCenter: notificationCenter, settingsStore: store)
        manager.authorizationStatus = .authorized

        let container = try TestModelContainerFactory.makeInMemoryContainer()
        // Wired as `CatCareCalendarApp` wires it, so the writer's resync reads this store.
        let resyncCoordinator = NotificationResyncCoordinator(modelContainer: container, notificationManager: manager)
        manager.onFullResyncAwaited = { try await resyncCoordinator.resync() }
        let context = container.mainContext
        let calendar = Calendar.current
        // A day out, so the reminder date is still in the future whenever the suite runs.
        let anchorDate = try #require(
            calendar.date(byAdding: .hour, value: 9, to: calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: Date())
            ) ?? Date())
        )

        let cat = Cat(name: "Mochi")
        let task = CareTask(title: "Brush the cat", category: .grooming)
        let schedule = CareTaskSchedule(
            scheduledDate: anchorDate,
            frequency: .once,
            frequencyInterval: 1,
            reminderMinutes: 15
        )
        task.assignedCats = [cat]
        schedule.task = task
        task.schedules = [schedule]
        context.insert(cat)
        context.insert(task)
        context.insert(schedule)
        try context.save()

        return (container, context, cat, [task], notificationCenter, manager)
    }

    private func makePendingRequest(taskId: UUID, identifier: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = ["taskId": taskId.uuidString]
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }
}
