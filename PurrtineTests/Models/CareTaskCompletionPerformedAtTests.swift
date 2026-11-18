import Foundation
import SwiftData
import Testing
@testable import Purrtine

/// A completion keeps two facts apart: `completedAt` is when the care was done, `completedForDate`
/// is the day it counts for. A plain late tap (due Monday, tapped Wednesday) is a real Wednesday
/// time that counts for Monday. A fill-in has no real time: `completedAt == completedForDate`.
@Suite
@MainActor
struct CareTaskCompletionPerformedAtTests {
    private let calendar = Calendar.current
    private let now: Date

    init() {
        now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 12)) ?? Date()
    }

    private func day(_ offset: Int, hour: Int = 0) -> Date {
        let start = calendar.startOfDay(for: now)
        let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
        return calendar.date(byAdding: .hour, value: hour, to: day) ?? day
    }

    /// A completion done at `recordedAt` that counts for `forDay`: a plain late tap when they differ.
    private func completion(recordedAt: Date, forDay: Date) -> CareTaskCompletion {
        CareTaskCompletion(completedAt: recordedAt, completedForDate: forDay)
    }

    /// A day filled in with no real time: both stored dates are the same start-of-day instant.
    private func fillIn(forDay: Date) -> CareTaskCompletion {
        let fillIn = CareTaskCompletion(completedForDate: forDay)
        fillIn.completedAt = fillIn.completedForDate
        return fillIn
    }

    @Test
    func aSameDayCompletionKeepsItsRealTimeAndIsNotAFillIn() {
        let done = completion(recordedAt: day(0, hour: 8), forDay: day(0))

        #expect(done.isFillIn() == false)
        #expect(done.completedAt == day(0, hour: 8))
    }

    @Test
    func aPlainLateTapKeepsItsRealTimeAndIsNotAFillIn() {
        // Due Monday (-2), tapped Wednesday at 11:00.
        let late = completion(recordedAt: day(0, hour: 11), forDay: day(-2))

        #expect(late.isFillIn() == false)
        #expect(late.completedAt == day(0, hour: 11))
        #expect(late.completedForDate == day(-2))
    }

    @Test
    func aFillInIsMarkedByTheTwoStoredDatesBeingEqual() {
        let marked = fillIn(forDay: day(-1))

        #expect(marked.isFillIn())
        #expect(marked.completedAt == marked.completedForDate)
    }

    @Test
    func wasOnTimeIsLeftAlone() {
        let late = CareTaskCompletion(
            completedAt: day(0, hour: 11),
            completedForDate: day(-1),
            wasOnTime: false
        )

        #expect(late.wasOnTime == false)
    }

    @Test
    func lastCompletionIsTheOneWithTheLatestCompletedAt() {
        let task = CareTask(title: "Brush Coat")
        let todays = completion(recordedAt: day(0, hour: 8), forDay: day(0))
        // Done after today's completion, for an earlier day: still the last one done.
        let lateTap = completion(recordedAt: day(0, hour: 11), forDay: day(-1))
        task.completions = [todays, lateTap]

        #expect(task.lastCompletion?.id == lateTap.id)
        #expect(task.lastCompletionDate == day(0, hour: 11))
    }

    @Test
    func aFillInDoesNotOutrankARealCompletionDoneAfterIt() {
        let task = CareTask(title: "Brush Coat")
        let todays = completion(recordedAt: day(0, hour: 8), forDay: day(0))
        task.completions = [fillIn(forDay: day(-1)), todays]

        #expect(task.lastCompletion?.id == todays.id)
        #expect(task.lastCompletionDate == day(0, hour: 8))
    }

    @Test
    func aLoneFillInMakesTheLastDoneLabelAnEarlierDayWithoutATime() {
        let task = CareTask(title: "Brush Coat")
        task.completions = [fillIn(forDay: day(-3))]

        #expect(task.lastCompletionDate == day(-3))
        let label = task.lastCompletionDisplayText(relativeTo: now)
        #expect(label.contains(String(localized: .generalToday)) == false)
        #expect(label.contains(String(localized: .timeYesterday)) == false)
    }

    @Test
    func aYesterdayFillInLabelSaysYesterdayWithoutATime() {
        let task = CareTask(title: "Brush Coat")
        task.completions = [fillIn(forDay: day(-1))]

        #expect(task.lastCompletionDisplayText(relativeTo: now) == String(localized: .tasksRowLastCompletedDay(
            String(localized: .timeYesterday)
        )))
    }

    @Test
    func aPlainLateTapLabelShowsTheDayAndTimeItWasDone() {
        let task = CareTask(title: "Brush Coat")
        // Due two days ago, tapped today at 11:00.
        task.completions = [completion(recordedAt: day(0, hour: 11), forDay: day(-2))]

        let label = task.lastCompletionDisplayText(relativeTo: now)

        #expect(label == String(localized: .tasksRowLastCompleted(
            String(localized: .generalToday),
            day(0, hour: 11).formatted(date: .omitted, time: .shortened)
        )))
    }

    @Test
    func theWeeklyCountReadsWhenTheCareWasDone() throws {
        // Keep the container alive: a context does not own it.
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let startOfWeek = day(-2)
        let inWeek = completion(recordedAt: day(0, hour: 8), forDay: day(0))
        let fillInInWeek = fillIn(forDay: day(-1))
        // Tapped this week for last week's open day: it was done this week, so it counts.
        let lateTapThisWeek = completion(recordedAt: day(0, hour: 10), forDay: day(-5))
        // A fill-in for a day before the week stays out.
        let fillInBeforeWeek = fillIn(forDay: day(-5))
        let oldCompletion = completion(recordedAt: day(-6, hour: 8), forDay: day(-6))
        for item in [inWeek, fillInInWeek, lateTapThisWeek, fillInBeforeWeek, oldCompletion] {
            context.insert(item)
        }
        try context.save()

        let counted = try context.fetch(
            FetchDescriptor<CareTaskCompletion>(
                predicate: CareTaskCompletion.performed(onOrAfter: startOfWeek)
            )
        )

        #expect(Set(counted.map(\.id)) == [inWeek.id, fillInInWeek.id, lateTapThisWeek.id])
    }
}
