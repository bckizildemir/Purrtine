import Foundation
import SwiftData
import Testing
@testable import Purrtine

/// A completion filled in late (typed in today for an earlier day) counts for the day the care was
/// done, not the day it was recorded: History, "Last done", Home recency and the weekly count.
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

    private func completion(recordedAt: Date, forDay: Date) -> CareTaskCompletion {
        CareTaskCompletion(completedAt: recordedAt, completedForDate: forDay)
    }

    @Test
    func aSameDayCompletionKeepsItsRealTime() {
        let done = completion(recordedAt: day(0, hour: 8), forDay: day(0))

        #expect(done.isFillIn() == false)
        #expect(done.performedAt() == day(0, hour: 8))
    }

    @Test
    func aFillInIsPlacedAtTheStartOfItsOwnDay() {
        let fillIn = completion(recordedAt: day(0, hour: 11), forDay: day(-1))

        #expect(fillIn.isFillIn())
        #expect(fillIn.performedAt() == day(-1))
    }

    @Test
    func wasOnTimeIsLeftAlone() {
        let fillIn = CareTaskCompletion(
            completedAt: day(0, hour: 11),
            completedForDate: day(-1),
            wasOnTime: false
        )

        #expect(fillIn.wasOnTime == false)
    }

    @Test
    func historyListsAYesterdayFillInUnderYesterdayBelowTodaysRealCompletion() {
        let todays = completion(recordedAt: day(0, hour: 8), forDay: day(0))
        // Recorded AFTER today's completion, but for yesterday.
        let fillIn = completion(recordedAt: day(0, hour: 11), forDay: day(-1))

        let sorted = HistoryPresentation.sortedNewestFirst([fillIn, todays])

        #expect(sorted.map(\.id) == [todays.id, fillIn.id])
        #expect(calendar.isDate(sorted[1].performedAt(), inSameDayAs: day(-1)))
        #expect(calendar.isDate(sorted[0].performedAt(), inSameDayAs: day(0)))
    }

    @Test
    func lastCompletionIsTheOneDoneLastNotTheOneRecordedLast() {
        let task = CareTask(title: "Brush Coat")
        let todays = completion(recordedAt: day(0, hour: 8), forDay: day(0))
        let fillIn = completion(recordedAt: day(0, hour: 11), forDay: day(-1))
        task.completions = [fillIn, todays]

        #expect(task.lastCompletion?.id == todays.id)
        #expect(task.lastCompletionDate == day(0, hour: 8))
    }

    @Test
    func aLoneFillInMakesTheLastDoneLabelAnEarlierDay() {
        let task = CareTask(title: "Brush Coat")
        task.completions = [completion(recordedAt: day(0, hour: 11), forDay: day(-3))]

        #expect(task.lastCompletionDate == day(-3))
        #expect(task.lastCompletionDisplayText().contains(String(localized: .generalToday)) == false)
        #expect(task.lastCompletionDisplayText().contains(String(localized: .timeYesterday)) == false)
    }

    @Test
    func aYesterdayFillInLabelSaysYesterdayWithoutATime() {
        let task = CareTask(title: "Brush Coat")
        task.completions = [completion(recordedAt: day(0, hour: 11), forDay: day(-1))]

        #expect(task.lastCompletionDisplayText() == String(localized: .tasksRowLastCompletedDay(
            String(localized: .timeYesterday)
        )))
    }

    @Test
    func theWeeklyCountReadsTheDayTheCareWasDone() throws {
        // Keep the container alive: a context does not own it.
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let startOfWeek = day(-2)
        let inWeek = completion(recordedAt: day(0, hour: 8), forDay: day(0))
        let fillInInWeek = completion(recordedAt: day(0, hour: 9), forDay: day(-1))
        // Typed in this week, but the care was done the week before.
        let fillInBeforeWeek = completion(recordedAt: day(0, hour: 10), forDay: day(-5))
        let oldCompletion = completion(recordedAt: day(-6, hour: 8), forDay: day(-6))
        for item in [inWeek, fillInInWeek, fillInBeforeWeek, oldCompletion] {
            context.insert(item)
        }
        try context.save()

        let count = try context.fetchCount(
            FetchDescriptor<CareTaskCompletion>(
                predicate: CareTaskCompletion.performed(onOrAfter: startOfWeek)
            )
        )

        // The real completion and the fill-in for a day inside the week; not the other two.
        #expect(count == 2)
    }
}
