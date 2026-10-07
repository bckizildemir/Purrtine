import Foundation
import Testing
import UserNotifications
@testable import CatCareCalendar

@MainActor
struct NotificationManagerSchedulingTests {
    @Test
    func oneTimeUrgentMedicationReminderBuildsExpectedContentAndTriggerDate() async throws {
        let calendar = Calendar.current
        let taskId = UUID()
        let scheduleId = UUID()
        let scheduledDate = try #require(calendar.date(byAdding: .day, value: 1, to: Date()))
        let scheduledTime = try #require(calendar.date(bySettingHour: 14, minute: 30, second: 0, of: scheduledDate))
        let expectedReminderDate = try #require(calendar.date(byAdding: .minute, value: -20, to: scheduledTime))
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settingsWithoutOverdueAlerts)
        await sut.checkAuthorizationStatus()

        try await sut.resyncCareTaskNotifications(with: [
            NotificationScheduleInfo(
                scheduleId: scheduleId,
                taskId: taskId,
                taskTitle: "Give insulin",
                taskDescription: "Use the evening dose",
                catNames: "Miso, Luna",
                category: .medication,
                iconName: "pills.fill",
                priority: .urgent,
                scheduledDate: scheduledDate,
                scheduledTime: scheduledTime,
                frequency: .once,
                frequencyInterval: 1,
                endDate: nil,
                customDays: nil,
                reminderMinutes: 20
            )
        ])

        let request = try #require(fakeCenter.addedRequests.first)
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        let expectedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: expectedReminderDate)

        #expect(fakeCenter.addedRequests.count == 1)
        #expect(fakeCenter.removedPendingIdentifiers.isEmpty)
        #expect(request.identifier == "\(taskId.uuidString)_\(scheduleId.uuidString)_\(Int(scheduledTime.timeIntervalSince1970))")
        #expect(trigger.dateComponents.year == expectedComponents.year)
        #expect(trigger.dateComponents.month == expectedComponents.month)
        #expect(trigger.dateComponents.day == expectedComponents.day)
        #expect(trigger.dateComponents.hour == expectedComponents.hour)
        #expect(trigger.dateComponents.minute == expectedComponents.minute)
        #expect(request.content.title == "💊 \(String(localized: .notificationReminderTitle))")
        #expect(request.content.subtitle == "Use the evening dose")
        #expect(request.content.body == "Give insulin\n🐱 Miso, Luna")
        #expect(request.content.threadIdentifier == taskId.uuidString)
        #expect(request.content.categoryIdentifier == NotificationCategory.medicationCritical.identifier)
        #expect(request.content.userInfo["taskId"] as? String == taskId.uuidString)
        #expect(request.content.userInfo["taskTitle"] as? String == "Give insulin")
        #expect(request.content.userInfo["categoryIcon"] as? String == "pills.fill")
        #expect(request.content.userInfo["category"] as? String == CareTaskCategory.medication.rawValue)
        #expect(request.content.userInfo["priority"] as? String == CareTaskPriority.urgent.rawValue)
        #expect(request.content.userInfo["catNames"] as? String == "Miso, Luna")
        #expect(request.content.badge == 1)
    }

    @Test
    func dailyReminderSchedulesEachOccurrenceUntilEndDate() async throws {
        let calendar = Calendar.current
        let taskId = UUID()
        let scheduleId = UUID()
        let firstDueDate = try #require(calendar.date(byAdding: .day, value: 1, to: Date()))
        let firstDueTime = try #require(calendar.date(bySettingHour: 9, minute: 0, second: 0, of: firstDueDate))
        let endDate = try #require(calendar.date(byAdding: .day, value: 2, to: firstDueTime))
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settingsWithoutOverdueAlerts)
        await sut.checkAuthorizationStatus()

        try await sut.resyncCareTaskNotifications(with: [
            NotificationScheduleInfo(
                scheduleId: scheduleId,
                taskId: taskId,
                taskTitle: "Refresh water",
                taskDescription: nil,
                catNames: "Miso",
                category: .water,
                iconName: "drop.fill",
                priority: .medium,
                scheduledDate: firstDueDate,
                scheduledTime: firstDueTime,
                frequency: .daily,
                frequencyInterval: 1,
                endDate: endDate,
                customDays: nil,
                reminderMinutes: 15
            )
        ])

        let scheduledDates = try fakeCenter.addedRequests.map { request in
            let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
            return try #require(calendar.date(from: trigger.dateComponents))
        }
        let expectedDates = try (0..<3).map { offset in
            let dueDate = try #require(calendar.date(byAdding: .day, value: offset, to: firstDueTime))
            return try #require(calendar.date(byAdding: .minute, value: -15, to: dueDate))
        }

        let expectedIdentifiers = try (0..<3).map { offset in
            let dueDate = try #require(calendar.date(byAdding: .day, value: offset, to: firstDueTime))
            return "\(taskId.uuidString)_\(scheduleId.uuidString)_\(Int(dueDate.timeIntervalSince1970))"
        }
        #expect(fakeCenter.addedRequests.map(\.identifier) == expectedIdentifiers)
        #expect(scheduledDates == expectedDates)
        #expect(fakeCenter.addedRequests.allSatisfy { request in
            request.content.categoryIdentifier == NotificationCategory.taskReminder.identifier
        })
    }

    @Test
    func dailyReminderKeepsOriginalCadenceWhenAnchorIsPast() async throws {
        let calendar = Calendar.current
        let currentMinute = try #require(calendar.date(
            from: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        ))
        let anchor = try #require(calendar.date(byAdding: .day, value: -10, to: currentMinute))
        let endDate = try #require(calendar.date(byAdding: .day, value: 18, to: anchor))
        let expectedDates = try [12, 15, 18].map { offset in
            try #require(calendar.date(byAdding: .day, value: offset, to: anchor))
        }
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settingsWithoutOverdueAlerts)
        await sut.checkAuthorizationStatus()

        try await sut.resyncCareTaskNotifications(with: [
            makeInfo(
                scheduledDate: anchor,
                frequency: .daily,
                frequencyInterval: 3,
                endDate: endDate,
                reminderMinutes: 0
            )
        ])

        #expect(try scheduledDates(from: fakeCenter, calendar: calendar) == expectedDates)
    }

    @Test
    func monthlyReminderReturnsToAnchorDayAfterShortMonth() async throws {
        let calendar = Calendar.current
        let anchor = try #require(calendar.date(
            from: DateComponents(year: 2091, month: 1, day: 31, hour: 9)
        ))
        let endDate = try #require(calendar.date(
            from: DateComponents(year: 2091, month: 6, day: 30, hour: 9)
        ))
        let expectedDates = try [
            DateComponents(year: 2091, month: 1, day: 31, hour: 9),
            DateComponents(year: 2091, month: 2, day: 28, hour: 9),
            DateComponents(year: 2091, month: 3, day: 31, hour: 9),
            DateComponents(year: 2091, month: 4, day: 30, hour: 9),
            DateComponents(year: 2091, month: 5, day: 31, hour: 9),
            DateComponents(year: 2091, month: 6, day: 30, hour: 9)
        ].map { components in
            try #require(calendar.date(from: components))
        }
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settingsWithoutOverdueAlerts)
        await sut.checkAuthorizationStatus()

        try await sut.resyncCareTaskNotifications(with: [
            makeInfo(
                scheduledDate: anchor,
                frequency: .monthly,
                endDate: endDate,
                reminderMinutes: 0
            )
        ])

        #expect(try scheduledDates(from: fakeCenter, calendar: calendar) == expectedDates)
    }

    @Test
    func overdueAlertIsScheduledAfterDueTimeWhenDelayConfigured() async throws {
        let calendar = Calendar.current
        let taskId = UUID()
        let scheduleId = UUID()
        let scheduledDate = try #require(calendar.date(byAdding: .day, value: 1, to: Date()))
        let scheduledTime = try #require(calendar.date(bySettingHour: 14, minute: 30, second: 0, of: scheduledDate))
        var settings = NotificationSettings.default
        settings.overdueReminderDelayMinutes = 45
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settings)
        await sut.checkAuthorizationStatus()

        try await sut.resyncCareTaskNotifications(with: [
            NotificationScheduleInfo(
                scheduleId: scheduleId,
                taskId: taskId,
                taskTitle: "Give insulin",
                taskDescription: nil,
                catNames: "Miso",
                category: .medication,
                iconName: "pills.fill",
                priority: .medium,
                scheduledDate: scheduledDate,
                scheduledTime: scheduledTime,
                frequency: .once,
                frequencyInterval: 1,
                endDate: nil,
                customDays: nil,
                reminderMinutes: 10
            )
        ])

        #expect(fakeCenter.addedRequests.count == 2)
        let overdueRequest = try #require(fakeCenter.addedRequests.last)
        let trigger = try #require(overdueRequest.trigger as? UNCalendarNotificationTrigger)
        let expectedOverdueDate = try #require(calendar.date(byAdding: .minute, value: 45, to: scheduledTime))
        let expectedComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: expectedOverdueDate)

        #expect(
            overdueRequest.identifier
                == "\(taskId.uuidString)_\(scheduleId.uuidString)_overdue_\(Int(scheduledTime.timeIntervalSince1970))"
        )
        #expect(trigger.dateComponents.day == expectedComponents.day)
        #expect(trigger.dateComponents.hour == expectedComponents.hour)
        #expect(trigger.dateComponents.minute == expectedComponents.minute)
        #expect(overdueRequest.content.categoryIdentifier == NotificationCategory.taskOverdue.identifier)
    }

    @Test
    /// A full resync owns every care-task request: one whose task is no longer among the active
    /// schedules — a deleted task — goes too. Requests without a task are not the resync's.
    func fullResyncReplacesEveryCareTaskRequestAndLeavesOthersAlone() async throws {
        let firstTaskId = UUID()
        let secondTaskId = UUID()
        let deletedTaskId = UUID()
        let fakeCenter = FakeUserNotificationCenterClient()
        let system = UNNotificationRequest(identifier: "system", content: UNMutableNotificationContent(), trigger: nil)
        fakeCenter.pendingRequests = [
            pendingRequest(identifier: "first-old", taskId: firstTaskId),
            pendingRequest(identifier: "second-old", taskId: secondTaskId),
            pendingRequest(identifier: "deleted-task", taskId: deletedTaskId),
            system
        ]
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settingsWithoutOverdueAlerts)
        await sut.checkAuthorizationStatus()

        try await sut.resyncCareTaskNotifications(with: [
            makeInfo(taskId: firstTaskId),
            makeInfo(taskId: secondTaskId),
            makeInfo(taskId: firstTaskId)
        ])

        #expect(fakeCenter.removedPendingIdentifiers == [["first-old", "second-old", "deleted-task"]])
        #expect(fakeCenter.addedRequests.count == 3)
        #expect(fakeCenter.pendingRequests.map(\.identifier).first == "system")
        #expect(fakeCenter.pendingRequests.count == 4)
    }

    @Test
    func weeklyCustomDaysPreserveTimeReminderOffsetAndWeekInterval() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let scheduledDate = try #require(calendar.date(
            from: DateComponents(year: 2090, month: 1, day: 4, hour: 8, minute: 0)
        ))
        let scheduledTime = try #require(calendar.date(
            from: DateComponents(year: 2000, month: 1, day: 1, hour: 14, minute: 45)
        ))
        let dueDate = try #require(calendar.date(bySettingHour: 14, minute: 45, second: 0, of: scheduledDate))
        let customDay = calendar.component(.weekday, from: dueDate) - 1
        let endDate = try #require(calendar.date(byAdding: .weekOfYear, value: 4, to: dueDate))
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settingsWithoutOverdueAlerts)
        await sut.checkAuthorizationStatus()

        try await sut.resyncCareTaskNotifications(with: [
            makeInfo(
                scheduledDate: scheduledDate,
                scheduledTime: scheduledTime,
                frequency: .weekly,
                frequencyInterval: 2,
                endDate: endDate,
                customDays: [customDay],
                reminderMinutes: 30
            )
        ])

        let actualDates = try fakeCenter.addedRequests.map { request in
            let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
            return try #require(calendar.date(from: trigger.dateComponents))
        }
        let expectedDates = try [0, 2, 4].map { weekOffset in
            let occurrence = try #require(calendar.date(byAdding: .weekOfYear, value: weekOffset, to: dueDate))
            return try #require(calendar.date(byAdding: .minute, value: -30, to: occurrence))
        }

        #expect(actualDates == expectedDates)
    }

    @Test(arguments: [-1, 0, Int.max])
    func snoozeRejectsNonPositiveAndOverflowingDelays(delayMinutes: Int) async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter)
        let task = CareTask(title: "Feed Miso", category: .feeding, iconName: "fork.knife")

        await #expect(throws: NotificationDelayError.invalidMinutes) {
            try await sut.scheduleSnoozedNotification(
                for: NotificationScheduleInfo(snoozing: task, firingAt: Date()),
                delayMinutes: delayMinutes
            )
        }
        #expect(fakeCenter.addedRequests.isEmpty)
    }

    @Test(arguments: [-1, 0, Int.max])
    func invalidOverdueDelaysDoNotCreateMalformedAlerts(delayMinutes: Int) async throws {
        var settings = NotificationSettings.default
        settings.overdueReminderDelayMinutes = delayMinutes
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settings)
        await sut.checkAuthorizationStatus()

        try await sut.resyncCareTaskNotifications(with: [makeInfo()])

        #expect(fakeCenter.addedRequests.count == 1)
        #expect(fakeCenter.addedRequests.contains {
            $0.content.categoryIdentifier == NotificationCategory.taskOverdue.identifier
        } == false)
    }

    /// A very long interval is reachable from the UI: the repeat sheet offers intervals up to 99 and
    /// the `.year` unit maps to `monthly` with `interval * 12`. Without a horizon the six monthly
    /// slots landed centuries apart, occupying pending-request slots that iOS would never deliver
    /// as planned while crowding out nearer reminders.
    @Test(arguments: [
        (CareTaskFrequency.monthly, 1188),
        (CareTaskFrequency.weekly, 99),
        (CareTaskFrequency.custom, 400)
    ])
    func pathologicalIntervalsDoNotScheduleBeyondTheHorizon(
        frequency: CareTaskFrequency,
        interval: Int
    ) async throws {
        let calendar = Calendar.current
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settingsWithoutOverdueAlerts)
        await sut.checkAuthorizationStatus()
        let horizon = try #require(calendar.date(byAdding: .month, value: 12, to: Date()))

        try await sut.resyncCareTaskNotifications(with: [
            makeInfo(frequency: frequency, frequencyInterval: interval, reminderMinutes: 0)
        ])

        let scheduled = try scheduledDates(from: fakeCenter, calendar: calendar)
        // The leading reminder is still scheduled; only the far-future tail is dropped.
        #expect(scheduled.count == 1)
        #expect(scheduled.allSatisfy { $0 <= horizon })
    }

    @Test(arguments: [
        (CareTaskFrequency.daily, 1, 30),
        (CareTaskFrequency.weekly, 1, 12),
        (CareTaskFrequency.biweekly, 1, 12),
        (CareTaskFrequency.monthly, 1, 6),
        (CareTaskFrequency.custom, 2, 20)
    ])
    func ordinaryCadencesStillFillTheirFullRequestBudget(
        frequency: CareTaskFrequency,
        interval: Int,
        expectedCount: Int
    ) async throws {
        let fakeCenter = FakeUserNotificationCenterClient()
        let sut = try makeManager(notificationCenter: fakeCenter, settings: settingsWithoutOverdueAlerts)
        await sut.checkAuthorizationStatus()

        try await sut.resyncCareTaskNotifications(with: [
            makeInfo(frequency: frequency, frequencyInterval: interval, reminderMinutes: 0)
        ])

        #expect(fakeCenter.addedRequests.count == expectedCount)
    }

    private var settingsWithoutOverdueAlerts: NotificationSettings {
        var settings = NotificationSettings.default
        settings.overdueReminderDelayMinutes = nil
        return settings
    }

    private func makeManager(
        notificationCenter: FakeUserNotificationCenterClient,
        settings: NotificationSettings = .default
    ) throws -> NotificationManager {
        let defaults = try #require(
            UserDefaults(suiteName: "NotificationManagerSchedulingTests.\(UUID().uuidString)")
        )
        let store = NotificationSettingsStore(userDefaults: defaults, key: "settings")
        store.save(settings)
        return NotificationManager(notificationCenter: notificationCenter, settingsStore: store)
    }

    private func scheduledDates(
        from notificationCenter: FakeUserNotificationCenterClient,
        calendar: Calendar
    ) throws -> [Date] {
        try notificationCenter.addedRequests.map { request in
            let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
            return try #require(calendar.date(from: trigger.dateComponents))
        }
    }

    private func makeInfo(
        taskId: UUID = UUID(),
        scheduledDate: Date? = nil,
        scheduledTime: Date? = nil,
        frequency: CareTaskFrequency = .once,
        frequencyInterval: Int = 1,
        endDate: Date? = nil,
        customDays: [Int]? = nil,
        reminderMinutes: Int? = 15
    ) -> NotificationScheduleInfo {
        NotificationScheduleInfo(
            scheduleId: UUID(),
            taskId: taskId,
            taskTitle: "Feed Miso",
            taskDescription: nil,
            catNames: "Miso",
            category: .feeding,
            iconName: "fork.knife",
            priority: .medium,
            scheduledDate: scheduledDate ?? Date().addingTimeInterval(86_400),
            scheduledTime: scheduledTime,
            frequency: frequency,
            frequencyInterval: frequencyInterval,
            endDate: endDate,
            customDays: customDays,
            reminderMinutes: reminderMinutes
        )
    }

    private func pendingRequest(identifier: String, taskId: UUID) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = ["taskId": taskId.uuidString]
        return UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
    }
}
