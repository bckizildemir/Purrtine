import Foundation
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct CareTaskScheduleTests {
    @Test
    func vaccinationTemplateHasVeterinaryAppointmentDefaults() throws {
        let templates = CareTaskTemplateManager.shared.allTemplates
        let vaccinationTemplate = try #require(templates.first { $0.kind == .vaccination })

        #expect(templates.filter { $0.kind == .vaccination }.count == 1)
        #expect(vaccinationTemplate.category == .vet)
        #expect(vaccinationTemplate.priority == .high)
        #expect(vaccinationTemplate.defaultFrequency == .once)

        let clinicField = try #require(vaccinationTemplate.customFields.first)
        #expect(clinicField.key == "vaccination.field.clinic")
        #expect(clinicField.type == .text)
        #expect(clinicField.isRequired == false)
    }

    @Test
    func dateOnlySchedulesResolveToEndOfDayDueDates() {
        let calendar = Calendar.current
        let scheduledDate = calendar.startOfDay(for: Date())
        let schedule = CareTaskSchedule(scheduledDate: scheduledDate, frequency: .once)
        let task = CareTask(title: "Same Day Feeding")

        schedule.task = task
        task.schedules = [schedule]

        let expectedDueDate = calendar.date(
            byAdding: DateComponents(day: 1, second: -1),
            to: scheduledDate
        )

        #expect(schedule.effectiveDueDate == expectedDueDate)
        #expect(task.activeDueDate == expectedDueDate)
        #expect(task.isOverdue == false)
    }

    @Test
    func dueDisplayUsesTheEffectiveDateOfADateOnlySchedule() throws {
        let calendar = Calendar.current
        let scheduledDate = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_704_067_200))
        let referenceDate = try #require(
            calendar.date(byAdding: DateComponents(day: 1, minute: 30), to: scheduledDate)
        )
        let schedule = CareTaskSchedule(scheduledDate: scheduledDate, frequency: .once)
        let task = CareTask(title: "Midnight Overdue")
        schedule.task = task
        task.schedules = [schedule]

        #expect(task.dueDisplayText(relativeTo: referenceDate) == String(localized: .tasksRowJustOverdue))
    }

    @Test(arguments: [
        (CareTaskFrequency.daily, 2, DateComponents(day: 2)),
        (CareTaskFrequency.weekly, 3, DateComponents(weekOfYear: 3)),
        (CareTaskFrequency.biweekly, 2, DateComponents(weekOfYear: 4)),
        (CareTaskFrequency.monthly, 2, DateComponents(month: 2)),
        (CareTaskFrequency.custom, 3, DateComponents(day: 3))
    ])
    func followingOccurrenceHonorsFrequencyIntervals(
        frequency: CareTaskFrequency,
        interval: Int,
        expectedOffset: DateComponents
    ) throws {
        let calendar = Self.gregorianCalendar()
        let scheduledDate = try #require(Self.date(2024, 1, 10, calendar: calendar))
        let expectedDate = try #require(calendar.date(byAdding: expectedOffset, to: scheduledDate))
        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: frequency,
            frequencyInterval: interval
        )

        #expect(schedule.followingOccurrence(after: scheduledDate, calendar: calendar) == expectedDate)
    }

    @Test(arguments: [
        (CareTaskFrequency.daily, 0, DateComponents(day: 1)),
        (CareTaskFrequency.weekly, -5, DateComponents(weekOfYear: 1)),
        (CareTaskFrequency.custom, Int.min, DateComponents(day: 1))
    ])
    func corruptIntervalsAreNormalizedBeforeCalculatingOccurrences(
        frequency: CareTaskFrequency,
        interval: Int,
        expectedOffset: DateComponents
    ) throws {
        let calendar = Self.gregorianCalendar()
        let scheduledDate = try #require(Self.date(2024, 1, 10, calendar: calendar))
        let expectedDate = try #require(calendar.date(byAdding: expectedOffset, to: scheduledDate))
        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: frequency,
            frequencyInterval: interval
        )

        #expect(schedule.followingOccurrence(after: scheduledDate, calendar: calendar) == expectedDate)
    }

    @Test
    func overflowingBiweeklyIntervalHasNoRepresentableFollowingOccurrence() throws {
        let calendar = Self.gregorianCalendar()
        let scheduledDate = try #require(Self.date(2024, 1, 10, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: .biweekly,
            frequencyInterval: Int.max
        )

        #expect(schedule.followingOccurrence(after: scheduledDate, calendar: calendar) == nil)
    }

    @Test
    func occurrenceQueriesUseTheOriginalCadenceInsteadOfDriftingFromReferenceDate() throws {
        let calendar = Self.gregorianCalendar()
        let scheduledDate = try #require(Self.date(2024, 1, 1, calendar: calendar))
        let referenceDate = try #require(Self.date(2024, 1, 4, calendar: calendar))
        let expectedDate = try #require(Self.date(2024, 1, 5, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: .daily,
            frequencyInterval: 2
        )

        #expect(schedule.nextOccurrence(from: referenceDate, calendar: calendar) == expectedDate)
        #expect(schedule.nextOccurrence(from: expectedDate, calendar: calendar) == expectedDate)
        #expect(schedule.followingOccurrence(after: referenceDate, calendar: calendar) == expectedDate)
    }

    @Test
    func customWeeklyIntervalUsesSelectedDaysWithinActiveWeeks() throws {
        let calendar = Self.gregorianCalendar()
        let monday = try #require(Self.date(2024, 1, 1, calendar: calendar))
        let wednesday = try #require(Self.date(2024, 1, 3, calendar: calendar))
        let nextActiveMonday = try #require(Self.date(2024, 1, 15, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: monday,
            frequency: .weekly,
            frequencyInterval: 2,
            customDays: [3, 1]
        )

        #expect(schedule.followingOccurrence(after: monday, calendar: calendar) == wednesday)
        #expect(schedule.followingOccurrence(after: wednesday, calendar: calendar) == nextActiveMonday)
    }

    @Test
    func customWeeklyDaysWrapFromSaturdayToSunday() throws {
        let calendar = Self.gregorianCalendar()
        let saturday = try #require(Self.date(2024, 1, 6, calendar: calendar))
        let sunday = try #require(Self.date(2024, 1, 7, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: saturday,
            frequency: .weekly,
            customDays: [0]
        )

        #expect(schedule.followingOccurrence(after: saturday, calendar: calendar) == sunday)
    }

    @Test
    func emptyCustomWeekdaysFallBackToTheWeeklyInterval() throws {
        let calendar = Self.gregorianCalendar()
        let scheduledDate = try #require(Self.date(2024, 1, 1, calendar: calendar))
        let expectedDate = try #require(Self.date(2024, 1, 15, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: .weekly,
            frequencyInterval: 2,
            customDays: []
        )

        #expect(schedule.followingOccurrence(after: scheduledDate, calendar: calendar) == expectedDate)
    }

    @Test
    func invalidCustomWeekdaysFallBackToTheWeeklyInterval() throws {
        let calendar = Self.gregorianCalendar()
        let scheduledDate = try #require(Self.date(2024, 1, 1, calendar: calendar))
        let expectedDate = try #require(Self.date(2024, 1, 15, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: .weekly,
            frequencyInterval: 2,
            customDays: [-1, 7, Int.max]
        )

        #expect(schedule.followingOccurrence(after: scheduledDate, calendar: calendar) == expectedDate)
    }

    @Test(arguments: [
        (2023, 2, 28),
        (2024, 2, 29)
    ])
    func monthlyOccurrenceHandlesEndOfFebruary(
        year: Int,
        expectedMonth: Int,
        expectedDay: Int
    ) throws {
        let calendar = Self.gregorianCalendar()
        let scheduledDate = try #require(Self.date(year, 1, 31, calendar: calendar))
        let expectedDate = try #require(Self.date(year, expectedMonth, expectedDay, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: .monthly
        )

        #expect(schedule.followingOccurrence(after: scheduledDate, calendar: calendar) == expectedDate)
    }

    @Test
    func monthlyCadenceReturnsToMonthEndAfterFebruary() throws {
        let calendar = Self.gregorianCalendar()
        let january = try #require(Self.date(2024, 1, 31, calendar: calendar))
        let february = try #require(Self.date(2024, 2, 29, calendar: calendar))
        let march = try #require(Self.date(2024, 3, 31, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: january,
            frequency: .monthly
        )

        #expect(schedule.followingOccurrence(after: february, calendar: calendar) == march)
    }

    @Test
    func yearlyIntervalFromLeapDayUsesCalendarRollover() throws {
        let calendar = Self.gregorianCalendar()
        let leapDay = try #require(Self.date(2024, 2, 29, calendar: calendar))
        let expectedDate = try #require(Self.date(2025, 2, 28, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: leapDay,
            frequency: .monthly,
            frequencyInterval: 12
        )

        #expect(schedule.followingOccurrence(after: leapDay, calendar: calendar) == expectedDate)
    }

    @Test
    func dailyOccurrencePreservesLocalMidnightAcrossDaylightSavingChange() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let daylightSavingDay = try #require(Self.date(2024, 3, 10, calendar: calendar))
        let nextDay = try #require(Self.date(2024, 3, 11, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: daylightSavingDay,
            frequency: .daily
        )

        let occurrence = try #require(
            schedule.followingOccurrence(after: daylightSavingDay, calendar: calendar)
        )

        #expect(occurrence == nextDay)
        #expect(occurrence.timeIntervalSince(daylightSavingDay) == 23 * 60 * 60)
        #expect(calendar.component(.hour, from: occurrence) == 0)
    }

    @Test
    func inactiveAndExpiredSchedulesDoNotReturnOccurrences() throws {
        let calendar = Self.gregorianCalendar()
        let scheduledDate = try #require(Self.date(2024, 1, 1, calendar: calendar))
        let referenceDate = try #require(Self.date(2024, 1, 2, calendar: calendar))
        let expiredSchedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: .daily,
            endDate: scheduledDate
        )
        let inactiveSchedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: .daily
        )
        inactiveSchedule.isActive = false

        #expect(expiredSchedule.nextOccurrence(from: referenceDate, calendar: calendar) == nil)
        #expect(expiredSchedule.followingOccurrence(after: scheduledDate, calendar: calendar) == nil)
        #expect(inactiveSchedule.nextOccurrence(from: referenceDate, calendar: calendar) == nil)
        #expect(inactiveSchedule.followingOccurrence(after: scheduledDate, calendar: calendar) == nil)
    }

    @Test
    func oneTimeScheduleOnlyReturnsItsPendingOccurrence() throws {
        let calendar = Self.gregorianCalendar()
        let scheduledDate = try #require(Self.date(2024, 1, 10, calendar: calendar))
        let before = try #require(Self.date(2024, 1, 9, calendar: calendar))
        let after = try #require(Self.date(2024, 1, 11, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: scheduledDate,
            frequency: .once
        )

        #expect(schedule.nextOccurrence(from: before, calendar: calendar) == scheduledDate)
        #expect(schedule.nextOccurrence(from: after, calendar: calendar) == nil)
        #expect(schedule.followingOccurrence(after: scheduledDate, calendar: calendar) == nil)
    }

    @Test
    func activeScheduleSelectsTheEarliestEffectiveDueDate() throws {
        let calendar = Self.gregorianCalendar()
        let task = CareTask(title: "Feed Mochi")
        let later = CareTaskSchedule(
            scheduledDate: try #require(Self.date(2024, 1, 3, calendar: calendar))
        )
        let inactiveEarlier = CareTaskSchedule(
            scheduledDate: try #require(Self.date(2024, 1, 1, calendar: calendar))
        )
        let activeEarlier = CareTaskSchedule(
            scheduledDate: try #require(Self.date(2024, 1, 2, calendar: calendar))
        )
        inactiveEarlier.isActive = false
        task.schedules = [later, inactiveEarlier, activeEarlier]

        #expect(task.activeSchedule?.id == activeEarlier.id)
    }

    @Test
    func activeScheduleDerivationsIgnoreInactiveHistory() {
        let task = CareTask(title: "Recurring care")
        let inactiveRecurring = CareTaskSchedule(
            scheduledDate: Date(),
            frequency: .daily
        )
        let activeOnce = CareTaskSchedule(
            scheduledDate: Date().addingTimeInterval(60),
            frequency: .once
        )
        inactiveRecurring.isActive = false
        task.schedules = [inactiveRecurring, activeOnce]

        #expect(task.activeSchedules.map(\.id) == [activeOnce.id])
        #expect(task.isRecurring == false)

        activeOnce.frequency = .weekly
        #expect(task.isRecurring)

        activeOnce.isActive = false
        #expect(task.activeSchedule == nil)
        #expect(task.activeDueDate == nil)
        #expect(task.isRecurring == false)
    }

    @Test
    func completionDerivationsUseTheMostRecentCompletion() {
        let task = CareTask(title: "Medication")
        let earlier = CareTaskCompletion(
            completedAt: Date(timeIntervalSince1970: 100),
            completedForDate: Date(timeIntervalSince1970: 100)
        )
        let latest = CareTaskCompletion(
            completedAt: Date(timeIntervalSince1970: 300),
            completedForDate: Date(timeIntervalSince1970: 300)
        )
        let middle = CareTaskCompletion(
            completedAt: Date(timeIntervalSince1970: 200),
            completedForDate: Date(timeIntervalSince1970: 200)
        )
        task.completions = [latest, earlier, middle]

        #expect(task.lastCompletion?.id == latest.id)
        #expect(task.lastCompletionDate == latest.completedAt)
        #expect(task.completionCount == 3)
    }

    /// Zones whose DST shift lands at 00:00 have no local midnight on the transition day, so the
    /// week containing it starts at 01:00. Measuring the elapsed-week gap against that offset week
    /// read one low, which burned a search slot and made the schedule return no occurrence at all —
    /// permanently, for every later reference date.
    @Test
    func weeklyScheduleAdvancesWhereTheWeekStartHasNoLocalMidnight() throws {
        let calendar = Self.zonedCalendar("Asia/Beirut", firstWeekday: 1)
        let anchor = try #require(Self.date(2025, 3, 30, hour: 9, calendar: calendar))
        let reference = try #require(Self.date(2025, 4, 6, hour: 23, minute: 59, calendar: calendar))
        let expected = try #require(Self.date(2025, 4, 13, hour: 9, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: anchor,
            frequency: .weekly,
            customDays: [0]
        )

        #expect(schedule.followingOccurrence(after: reference, calendar: calendar) == expected)
    }

    /// `Calendar.dateInterval(of: .weekOfYear, for:)` returns nil outright for weeks whose first day
    /// has no local midnight, which used to propagate out as "this schedule has no occurrences".
    @Test
    func weeklyScheduleResolvesWhereTheCalendarReportsNoWeekInterval() throws {
        let calendar = Self.zonedCalendar("America/Scoresbysund", firstWeekday: 2)
        let anchor = try #require(
            Self.date(2032, 7, 13, hour: 22, minute: 40, second: 30, calendar: calendar)
        )
        let reference = try #require(
            Self.date(2033, 4, 3, hour: 23, minute: 50, second: 22, calendar: calendar)
        )
        let expected = try #require(
            Self.date(2033, 4, 18, hour: 22, minute: 40, second: 30, calendar: calendar)
        )
        let schedule = CareTaskSchedule(
            scheduledDate: anchor,
            frequency: .weekly,
            frequencyInterval: 5,
            customDays: [0, 1, 4]
        )

        #expect(schedule.followingOccurrence(after: reference, calendar: calendar) == expected)
    }

    /// Lord Howe shifts at 02:00, so an 02:00 occurrence does not exist on the transition day.
    /// `date(bySettingHour:)` searches forward and used to cross into Monday, firing a Sunday-only
    /// schedule on a weekday the user never selected.
    @Test
    func weeklyOccurrenceKeepsItsSelectedWeekdayWhenThatTimeDoesNotExist() throws {
        let calendar = Self.zonedCalendar("Australia/Lord_Howe", firstWeekday: 1)
        let anchor = try #require(Self.date(2024, 9, 29, hour: 2, calendar: calendar))
        let reference = try #require(Self.date(2024, 9, 30, calendar: calendar))
        let schedule = CareTaskSchedule(
            scheduledDate: anchor,
            frequency: .weekly,
            customDays: [0]
        )

        let occurrence = try #require(
            schedule.followingOccurrence(after: reference, calendar: calendar)
        )

        // Weekday 1 is Sunday; the selected day must survive even though 02:00 is skipped.
        #expect(calendar.component(.weekday, from: occurrence) == 1)
        #expect(Self.date(2024, 10, 6, calendar: calendar).map {
            calendar.isDate(occurrence, inSameDayAs: $0)
        } == true)
    }

    private static func gregorianCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private static func zonedCalendar(_ identifier: String, firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = TimeZone(identifier: identifier) {
            calendar.timeZone = timeZone
        }
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0,
        calendar: Calendar
    ) -> Date? {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )
    }
}
