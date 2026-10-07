import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@MainActor
struct TaskFormPersistenceTests {
    @Test
    func creatingTaskPersistsAssignmentsScheduleAndDefaultCaregiver() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let cat = Cat(name: "Mochi")
        context.insert(cat)

        let scheduledDate = try #require(makeDate(year: 2026, month: 7, day: 12, hour: 9))
        let scheduledTime = try #require(makeDate(year: 2026, month: 7, day: 12, hour: 9, minute: 30))
        let endDate = try #require(makeDate(year: 2026, month: 8, day: 12))
        let draft = TaskFormDraft(
            title: "  Brush Mochi  ",
            taskDescription: "Use soft brush",
            category: .grooming,
            iconName: "comb.fill",
            priority: .high,
            assignedCats: [cat],
            assignedCaregiver: nil,
            scheduledDate: scheduledDate,
            scheduledTime: scheduledTime,
            frequency: .weekly,
            frequencyInterval: 2,
            endDate: endDate,
            reminderMinutes: 30,
            customDays: [1, 4]
        )

        let task = try TaskFormPersistence.createTask(
            from: draft,
            in: context,
            existingCaregivers: [],
            defaultCaregiverName: "Myself"
        )

        let persistedTasks = try context.fetch(FetchDescriptor<CareTask>())
        let persistedCaregivers = try context.fetch(FetchDescriptor<Caregiver>())
        let schedule = try #require(task.schedules.first)

        #expect(persistedTasks.map(\.id) == [task.id])
        #expect(task.title == "Brush Mochi")
        #expect(task.taskDescription == "Use soft brush")
        #expect(task.category == .grooming)
        #expect(task.priority == .high)
        #expect(task.assignedCats.map(\.id) == [cat.id])
        #expect(task.assignedCaregiver?.name == "Myself")
        #expect(persistedCaregivers.count == 1)
        #expect(schedule.scheduledDate == scheduledDate)
        #expect(schedule.scheduledTime == scheduledTime)
        #expect(schedule.frequency == .weekly)
        #expect(schedule.frequencyInterval == 2)
        #expect(schedule.endDate == endDate)
        #expect(schedule.reminderMinutes == 30)
        #expect(schedule.customDays == [1, 4])
    }

    @Test
    func creatingTaskRejectsBlankTitleWithoutPersistingPartialData() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let scheduledDate = try #require(makeDate(year: 2026, month: 7, day: 12))
        let draft = TaskFormDraft(
            title: " \n ",
            taskDescription: "",
            category: .general,
            iconName: "circle",
            priority: .medium,
            assignedCats: [],
            assignedCaregiver: nil,
            scheduledDate: scheduledDate,
            scheduledTime: nil,
            frequency: .once,
            frequencyInterval: 1,
            endDate: nil,
            reminderMinutes: nil,
            customDays: nil
        )

        #expect(throws: TaskFormPersistenceError.invalidTitle) {
            try TaskFormPersistence.createTask(
                from: draft,
                in: context,
                existingCaregivers: [],
                defaultCaregiverName: "Myself"
            )
        }

        #expect(try context.fetch(FetchDescriptor<CareTask>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CareTaskSchedule>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Caregiver>()).isEmpty)
    }

    @Test
    func creatingTaskNormalizesMalformedScheduleValues() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let scheduledDate = try #require(makeDate(year: 2026, month: 7, day: 12))
        let draft = TaskFormDraft(
            title: "Feed Mochi",
            taskDescription: "",
            category: .feeding,
            iconName: "fork.knife",
            priority: .medium,
            assignedCats: [],
            assignedCaregiver: nil,
            scheduledDate: scheduledDate,
            scheduledTime: nil,
            frequency: .weekly,
            frequencyInterval: Int.min,
            endDate: nil,
            reminderMinutes: -30,
            customDays: [-1, 1, 1, 6, 7, Int.max]
        )

        let task = try TaskFormPersistence.createTask(
            from: draft,
            in: context,
            existingCaregivers: [],
            defaultCaregiverName: "Myself"
        )

        let schedule = try #require(task.schedules.first)
        #expect(schedule.frequencyInterval == 1)
        #expect(schedule.reminderMinutes == nil)
        #expect(schedule.customDays == [1, 6])
    }

    @Test
    func updatingTaskTrimsTitleAndReplacesScheduleValues() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let firstCat = Cat(name: "Mochi")
        let secondCat = Cat(name: "Luna")
        let task = CareTask(title: "Old Task", description: "Old notes", category: .general, priority: .low)
        let oldScheduleDate = try #require(makeDate(year: 2026, month: 7, day: 10))
        let schedule = CareTaskSchedule(
            scheduledDate: oldScheduleDate,
            frequency: .daily,
            reminderMinutes: 15
        )
        schedule.task = task
        task.schedules = [schedule]
        task.assignedCats = [firstCat]
        context.insert(firstCat)
        context.insert(secondCat)
        context.insert(task)
        context.insert(schedule)
        try context.save()

        let updatedDate = try #require(makeDate(year: 2026, month: 7, day: 20))
        let updatedAt = try #require(makeDate(year: 2026, month: 7, day: 10, hour: 12))
        let draft = TaskFormDraft(
            title: "  Refill Fountain  ",
            taskDescription: "",
            category: .water,
            iconName: "drop.halffull",
            priority: .urgent,
            assignedCats: [secondCat],
            assignedCaregiver: nil,
            scheduledDate: updatedDate,
            scheduledTime: nil,
            frequency: .monthly,
            frequencyInterval: 1,
            endDate: nil,
            reminderMinutes: nil,
            customDays: nil
        )

        try TaskFormPersistence.updateTask(task, from: draft, in: context, updatedAt: updatedAt)

        let schedules = try context.fetch(FetchDescriptor<CareTaskSchedule>())
        let updatedSchedule = try #require(task.schedules.first)

        #expect(task.title == "Refill Fountain")
        #expect(task.taskDescription == nil)
        #expect(task.category == .water)
        #expect(task.iconName == "drop.halffull")
        #expect(task.priority == .urgent)
        #expect(task.assignedCats.map(\.id) == [secondCat.id])
        #expect(task.updatedAt == updatedAt)
        #expect(schedules.count == 1)
        #expect(updatedSchedule.id == schedule.id)
        #expect(updatedSchedule.scheduledDate == updatedDate)
        #expect(updatedSchedule.scheduledTime == nil)
        #expect(updatedSchedule.frequency == .monthly)
        #expect(updatedSchedule.reminderMinutes == nil)
    }

    @Test
    func updatingTaskPersistsReassignedCaregiver() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let originalCaregiver = Caregiver(name: "Alex", role: .primary)
        let newCaregiver = Caregiver(name: "Sam", role: .member)
        let scheduleDate = try #require(makeDate(year: 2026, month: 7, day: 10))
        let task = CareTask(title: "Feed Mochi", category: .feeding)
        let schedule = CareTaskSchedule(scheduledDate: scheduleDate, frequency: .daily)
        schedule.task = task
        task.schedules = [schedule]
        task.assignedCaregiver = originalCaregiver
        context.insert(originalCaregiver)
        context.insert(newCaregiver)
        context.insert(task)
        context.insert(schedule)
        try context.save()

        let draft = TaskFormDraft(
            title: "Feed Mochi",
            taskDescription: "",
            category: .feeding,
            iconName: "fork.knife",
            priority: .medium,
            assignedCats: [],
            assignedCaregiver: newCaregiver,
            scheduledDate: scheduleDate,
            scheduledTime: nil,
            frequency: .daily,
            frequencyInterval: 1,
            endDate: nil,
            reminderMinutes: nil,
            customDays: nil
        )

        try TaskFormPersistence.updateTask(task, from: draft, in: context)

        let persistedTask = try #require(try context.fetch(FetchDescriptor<CareTask>()).first)
        #expect(persistedTask.assignedCaregiver?.id == newCaregiver.id)
    }

    @Test
    func updatingTaskKeepsExistingCaregiverWhenDraftCarriesNone() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let originalCaregiver = Caregiver(name: "Alex", role: .primary)
        let scheduleDate = try #require(makeDate(year: 2026, month: 7, day: 10))
        let task = CareTask(title: "Feed Mochi", category: .feeding)
        let schedule = CareTaskSchedule(scheduledDate: scheduleDate, frequency: .daily)
        schedule.task = task
        task.schedules = [schedule]
        task.assignedCaregiver = originalCaregiver
        context.insert(originalCaregiver)
        context.insert(task)
        context.insert(schedule)
        try context.save()

        let draft = TaskFormDraft(
            title: "Feed Mochi",
            taskDescription: "",
            category: .feeding,
            iconName: "fork.knife",
            priority: .medium,
            assignedCats: [],
            assignedCaregiver: nil,
            scheduledDate: scheduleDate,
            scheduledTime: nil,
            frequency: .daily,
            frequencyInterval: 1,
            endDate: nil,
            reminderMinutes: nil,
            customDays: nil
        )

        try TaskFormPersistence.updateTask(task, from: draft, in: context)

        #expect(task.assignedCaregiver?.id == originalCaregiver.id)
    }

    @Test
    func updatingTaskRejectsBlankTitleWithoutMutatingExistingValues() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let originalDate = try #require(makeDate(year: 2026, month: 7, day: 10))
        let attemptedDate = try #require(makeDate(year: 2026, month: 8, day: 10))
        let task = CareTask(title: "Original", category: .feeding)
        let schedule = CareTaskSchedule(scheduledDate: originalDate, frequency: .daily)
        schedule.task = task
        task.schedules = [schedule]
        context.insert(task)
        context.insert(schedule)
        try context.save()

        let draft = TaskFormDraft(
            title: "\t ",
            taskDescription: "Changed",
            category: .water,
            iconName: "drop.fill",
            priority: .urgent,
            assignedCats: [],
            assignedCaregiver: nil,
            scheduledDate: attemptedDate,
            scheduledTime: nil,
            frequency: .monthly,
            frequencyInterval: 2,
            endDate: nil,
            reminderMinutes: 30,
            customDays: nil
        )

        #expect(throws: TaskFormPersistenceError.invalidTitle) {
            try TaskFormPersistence.updateTask(task, from: draft, in: context)
        }

        #expect(task.title == "Original")
        #expect(task.taskDescription == nil)
        #expect(task.category == .feeding)
        #expect(schedule.scheduledDate == originalDate)
        #expect(schedule.frequency == .daily)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    }
}
