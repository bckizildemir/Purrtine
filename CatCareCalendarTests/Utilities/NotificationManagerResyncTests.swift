import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import CatCareCalendar

/// The full capped resync (#80): one selection of the soonest reminders across every task, applied
/// to the pending set as a diff.
@MainActor
struct NotificationManagerResyncTests {
    @Test
    func onboardingStarterTasksKeepOnlyTheSixtySoonestReminders() async throws {
        let infos = try await starterTaskInfos()
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try await makeManager(notificationCenter: fakeCenter)

        try await sut.resyncCareTaskNotifications(with: infos)

        // Uncapped, these three tasks produce 83 requests spread over 30 days. Two daily series and
        // one every-other-day series fire 2.5 reminders a day, so the 60 soonest (3 of them overdue
        // follow-ups) end about 23 days out.
        let fireDates = try fakeCenter.pendingRequests.map(fireDate(of:))
        let latest = try #require(fireDates.max())
        #expect(fakeCenter.pendingRequests.count == 60)
        #expect(latest < Date().addingTimeInterval(25 * 86_400))
        for info in infos where info.frequency == .daily {
            let days = try fakeCenter.pendingRequests
                .filter { $0.identifier.hasPrefix("\(info.taskId.uuidString)_") && $0.identifier.contains("overdue") == false }
                .map { Calendar.current.startOfDay(for: try fireDate(of: $0)) }
                .sorted()
            #expect(days.count > 10)
            let gaps = zip(days, days.dropFirst()).map { Calendar.current.dateComponents([.day], from: $0, to: $1).day }
            #expect(gaps.allSatisfy { $0 == 1 })
        }
    }

    @Test
    func aPendingSnoozeSurvivesAFullResync() async throws {
        let taskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        let snooze = pendingRequest(identifier: "snooze_\(taskId.uuidString)_1800000000", taskId: taskId)
        fakeCenter.pendingRequests = [snooze]
        let sut = try await makeManager(notificationCenter: fakeCenter)

        try await sut.resyncCareTaskNotifications(with: [makeInfo(taskId: taskId)])
        try await sut.resyncCareTaskNotifications(with: [])

        #expect(fakeCenter.pendingRequests.map(\.identifier) == [snooze.identifier])
    }

    @Test
    func twoBackToBackResyncsLeaveTheSamePendingSet() async throws {
        let infos = try await starterTaskInfos()
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try await makeManager(notificationCenter: fakeCenter)

        try await sut.resyncCareTaskNotifications(with: infos)
        let firstPass = Set(fakeCenter.pendingRequests.map(\.identifier))
        let addsAfterFirstPass = fakeCenter.addedRequests.count
        try await sut.resyncCareTaskNotifications(with: infos.reversed())

        #expect(Set(fakeCenter.pendingRequests.map(\.identifier)) == firstPass)
        #expect(fakeCenter.addedRequests.count == addsAfterFirstPass)
        #expect(fakeCenter.removedPendingIdentifiers.allSatisfy { $0.isEmpty })
    }

    @Test
    func identifiersNameTheOccurrenceNotItsPosition() async throws {
        let calendar = Calendar.current
        let taskId = UUID()
        let scheduleId = UUID()
        let dueDate = try #require(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())))
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try await makeManager(notificationCenter: fakeCenter)

        try await sut.resyncCareTaskNotifications(with: [
            makeInfo(taskId: taskId, scheduleId: scheduleId, scheduledDate: dueDate, frequency: .daily)
        ])

        let epoch = Int(dueDate.timeIntervalSince1970)
        let identifiers = Set(fakeCenter.pendingRequests.map(\.identifier))
        #expect(identifiers.contains("\(taskId.uuidString)_\(scheduleId.uuidString)_\(epoch)"))
        #expect(identifiers.contains("\(taskId.uuidString)_\(scheduleId.uuidString)_overdue_\(epoch)"))
        #expect(identifiers.contains("\(taskId.uuidString)_\(scheduleId.uuidString)_0") == false)
    }

    @Test
    func aChangedReminderIsReplacedAndAStaleOneRemoved() async throws {
        let taskId = UUID()
        let goneTaskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        let unrelated = pendingRequest(identifier: "system", taskId: nil)
        fakeCenter.pendingRequests = [
            pendingRequest(identifier: "\(goneTaskId.uuidString)_old_0", taskId: goneTaskId),
            unrelated
        ]
        let sut = try await makeManager(notificationCenter: fakeCenter)
        let info = makeInfo(taskId: taskId)
        try await sut.resyncCareTaskNotifications(with: [info])
        let addsBefore = fakeCenter.addedRequests.count

        try await sut.resyncCareTaskNotifications(with: [makeInfo(taskId: taskId, scheduleId: info.scheduleId, title: "Renamed")])

        #expect(fakeCenter.removedPendingIdentifiers.first == ["\(goneTaskId.uuidString)_old_0"])
        // The reminder and its overdue follow-up both carry the title, so both are re-added in place.
        let careTaskTitles = fakeCenter.pendingRequests
            .filter { $0.content.userInfo["taskId"] != nil }
            .map { $0.content.userInfo["taskTitle"] as? String }
        #expect(fakeCenter.addedRequests.count == addsBefore + 2)
        #expect(fakeCenter.removedPendingIdentifiers.count == 1)
        #expect(fakeCenter.pendingRequests.contains { $0.identifier == "system" })
        #expect(careTaskTitles == ["Renamed", "Renamed"])
    }

    @Test(arguments: [false, true])
    func turningRemindersOffRemovesEveryCareTaskReminderAndSnooze(viaPermission: Bool) async throws {
        let taskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        let snooze = pendingRequest(identifier: "snooze_\(taskId.uuidString)_1", taskId: taskId)
        fakeCenter.pendingRequests = [snooze]
        let sut = try await makeManager(notificationCenter: fakeCenter)
        try await sut.resyncCareTaskNotifications(with: [makeInfo(taskId: taskId)])
        #expect(fakeCenter.pendingRequests.count == 3) // the snooze, the reminder, its overdue follow-up

        if viaPermission {
            fakeCenter.authorizationStatusValue = .denied
            await sut.checkAuthorizationStatus()
        } else {
            var settings = sut.settings
            settings.isEnabled = false
            sut.applySettings(settings)
        }
        try await sut.resyncCareTaskNotifications(with: [makeInfo(taskId: taskId)])

        // The caregiver asked for silence, so a snooze must not fire either.
        #expect(fakeCenter.pendingRequests.isEmpty)
    }

    @Test
    func cancellingATasksSnoozesLeavesOtherTasksAndItsRemindersAlone() async throws {
        let taskId = UUID()
        let otherTaskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try await makeManager(notificationCenter: fakeCenter)
        try await sut.resyncCareTaskNotifications(with: [makeInfo(taskId: taskId)])
        let reminderIds = fakeCenter.pendingRequests.map(\.identifier)
        let otherSnooze = pendingRequest(identifier: "snooze_\(otherTaskId.uuidString)_1", taskId: otherTaskId)
        fakeCenter.pendingRequests += [
            pendingRequest(identifier: "snooze_\(taskId.uuidString)_1", taskId: taskId),
            otherSnooze
        ]

        await sut.cancelSnoozedNotifications(forTaskId: taskId)

        #expect(fakeCenter.pendingRequests.map(\.identifier) == reminderIds + [otherSnooze.identifier])
    }

    /// A cold launch from a notification action can run the writer's pass before the launch-time
    /// permission read returns. "Not determined" must not read as "reminders off".
    @Test
    func aPassBeforeTheFirstPermissionReadReadsItInsteadOfWipingTheSet() async throws {
        let taskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        let snooze = pendingRequest(identifier: "snooze_\(taskId.uuidString)_1", taskId: taskId)
        fakeCenter.pendingRequests = [snooze]
        let defaults = try #require(UserDefaults(suiteName: "NotificationManagerResyncTests.\(UUID().uuidString)"))
        let sut = NotificationManager(
            notificationCenter: fakeCenter,
            settingsStore: NotificationSettingsStore(userDefaults: defaults, key: "settings")
        )
        try #require(sut.authorizationStatus == .notDetermined)

        try await sut.resyncCareTaskNotifications(with: [makeInfo(taskId: taskId)])

        #expect(sut.authorizationStatus == .authorized)
        #expect(fakeCenter.pendingRequests.contains { $0.identifier == snooze.identifier })
        #expect(fakeCenter.pendingRequests.count == 3)
    }

    // MARK: - Helpers

    private func starterTaskInfos() async throws -> [NotificationScheduleInfo] {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: context)
        var tempData = TempCatData()
        tempData.name = "Luna"
        let builder = OnboardingDataBuilder(taskWriter: CareTaskWriter(scheduler: NotificationSchedulerSpy()))
        try await builder.createCatAndTasks(from: tempData, selectedTasks: [.feeding, .water, .litterBox], in: context)
        let tasks = try context.fetch(FetchDescriptor<CareTask>())
        #expect(tasks.count == 3)
        return tasks.flatMap(NotificationScheduleInfo.activeInfos(for:))
    }

    private func makeManager(notificationCenter: FakeUserNotificationCenterClient) async throws -> NotificationManager {
        let defaults = try #require(UserDefaults(suiteName: "NotificationManagerResyncTests.\(UUID().uuidString)"))
        let sut = NotificationManager(
            notificationCenter: notificationCenter,
            settingsStore: NotificationSettingsStore(userDefaults: defaults, key: "settings")
        )
        await sut.checkAuthorizationStatus()
        return sut
    }

    private func makeInfo(
        taskId: UUID,
        scheduleId: UUID = UUID(),
        title: String = "Feed Mochi",
        scheduledDate: Date = Date().addingTimeInterval(86_400),
        frequency: CareTaskFrequency = .once
    ) -> NotificationScheduleInfo {
        NotificationScheduleInfo(
            scheduleId: scheduleId,
            taskId: taskId,
            taskTitle: title,
            taskDescription: nil,
            catNames: "Mochi",
            category: .feeding,
            iconName: "fork.knife",
            priority: .medium,
            scheduledDate: scheduledDate,
            scheduledTime: nil,
            frequency: frequency,
            frequencyInterval: 1,
            endDate: nil,
            customDays: nil,
            reminderMinutes: 0
        )
    }

    private func pendingRequest(identifier: String, taskId: UUID?) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        if let taskId {
            content.userInfo = ["taskId": taskId.uuidString]
        }
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }

    private func fireDate(of request: UNNotificationRequest) throws -> Date {
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        return try #require(Calendar.current.date(from: trigger.dateComponents))
    }
}
