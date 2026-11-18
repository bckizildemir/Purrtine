import Foundation
import SwiftData
import Testing
@testable import Purrtine

@Suite
@MainActor
struct HistoryPresentationTests {
    @Test
    func zeroTasksTakesPrecedenceOverCompletionAndSearchState() {
        let state = HistoryPresentation.state(
            taskCount: 0,
            completions: [CareTaskCompletion(notes: "existing")],
            searchText: "missing",
            isTaskScoped: true
        )

        #expect(state == .noTasks)
    }

    @Test
    func tasksWithoutCompletionsUseNoCompletionsEmptyState() {
        let state = HistoryPresentation.state(
            taskCount: 2,
            completions: [],
            searchText: "",
            isTaskScoped: false
        )

        #expect(state == .noCompletions)
    }

    @Test
    func unmatchedNonEmptySearchUsesSearchEmptyState() {
        let task = CareTask(title: "Feed Mochi")
        let completion = CareTaskCompletion(notes: "Finished breakfast")
        completion.task = task
        completion.cats = [Cat(name: "Mochi")]

        let state = HistoryPresentation.state(
            taskCount: 1,
            completions: [completion],
            searchText: "litter",
            isTaskScoped: false
        )

        #expect(state == .searchEmpty)
    }

    @Test
    func scopedTaskWithoutCompletionsUsesTaskNoCompletionsEmptyState() {
        let state = HistoryPresentation.state(
            taskCount: 1,
            completions: [],
            searchText: "",
            isTaskScoped: true
        )

        #expect(state == .taskNoCompletions)
    }

    @Test
    func blankSearchWithCompletionsUsesContentState() {
        let state = HistoryPresentation.state(
            taskCount: 1,
            completions: [CareTaskCompletion()],
            searchText: " \n\t ",
            isTaskScoped: false
        )

        #expect(state == .content)
    }

    @Test(arguments: ["feed", "mochi", "breakfast"])
    func searchMatchesTaskCatAndNotes(_ query: String) {
        let matching = CareTaskCompletion(notes: "Finished breakfast")
        matching.task = CareTask(title: "Feed the cats")
        matching.cats = [Cat(name: "Mochi")]
        let unrelated = CareTaskCompletion(notes: nil)

        let filtered = HistoryPresentation.filteredCompletions(
            from: [unrelated, matching],
            query: query
        )
        let state = HistoryPresentation.state(
            taskCount: 1,
            completions: [unrelated, matching],
            searchText: query,
            isTaskScoped: false
        )

        #expect(filtered == [matching])
        #expect(state == .content)
    }

    @Test
    func blankQueryPreservesAllCompletionsAndOrder() {
        let first = CareTaskCompletion()
        let second = CareTaskCompletion()

        let filtered = HistoryPresentation.filteredCompletions(
            from: [first, second],
            query: " \n "
        )

        #expect(filtered == [first, second])
    }

    private static let cutoff = Date(timeIntervalSince1970: 1_800_000_000)

    @Test
    func oldCompletionWithoutCatsFallsBackToTheTasksAssignedCats() {
        let miso = Cat(name: "Miso")
        let task = CareTask(title: "Daily Feeding")
        task.assignedCats = [miso]
        let old = CareTaskCompletion(completedAt: Self.cutoff.addingTimeInterval(-3_600))
        old.task = task

        #expect(HistoryPresentation.displayCats(for: old, fallbackCutoff: Self.cutoff) == [miso])
        #expect(HistoryPresentation.filteredCompletions(
            from: [old], query: "Miso", fallbackCutoff: Self.cutoff
        ) == [old])
    }

    @Test
    func newCompletionWithoutCatsGetsNoFallback() {
        // The deleted-cat case: completed for Miso only, Miso deleted, Luna still assigned.
        let luna = Cat(name: "Luna")
        let task = CareTask(title: "Daily Feeding")
        task.assignedCats = [luna]
        let new = CareTaskCompletion(completedAt: Self.cutoff.addingTimeInterval(3_600))
        new.task = task

        #expect(HistoryPresentation.displayCats(for: new, fallbackCutoff: Self.cutoff).isEmpty)
        #expect(HistoryPresentation.filteredCompletions(
            from: [new], query: "Luna", fallbackCutoff: Self.cutoff
        ).isEmpty)
    }

    @Test
    func noStoredCutoffMeansNoFallback() {
        let task = CareTask(title: "Daily Feeding")
        task.assignedCats = [Cat(name: "Miso")]
        let completion = CareTaskCompletion(completedAt: Self.cutoff.addingTimeInterval(-3_600))
        completion.task = task

        #expect(HistoryPresentation.displayCats(for: completion, fallbackCutoff: nil).isEmpty)
        #expect(HistoryPresentation.filteredCompletions(from: [completion], query: "Miso").isEmpty)
    }

    @Test
    func completionKeepsItsOwnCatsInsteadOfTheTasksAssignedCats() {
        let own = Cat(name: "Own")
        let assigned = Cat(name: "Assigned")
        let task = CareTask(title: "Daily Feeding")
        task.assignedCats = [assigned]
        let completion = CareTaskCompletion(completedAt: Self.cutoff.addingTimeInterval(-3_600))
        completion.task = task
        completion.cats = [own]

        #expect(HistoryPresentation.displayCats(for: completion, fallbackCutoff: Self.cutoff) == [own])
        #expect(HistoryPresentation.filteredCompletions(
            from: [completion], query: "Assigned", fallbackCutoff: Self.cutoff
        ).isEmpty)
    }

    @Test
    func oldCompletionWithoutCatsAndWithoutTaskShowsNoCats() {
        let completion = CareTaskCompletion(completedAt: Self.cutoff.addingTimeInterval(-3_600))
        #expect(HistoryPresentation.displayCats(for: completion, fallbackCutoff: Self.cutoff).isEmpty)
    }

    // MARK: - The row's date and time (#163)

    /// Due two days ago, tapped now with no day named: a late completion. The row shows the day and
    /// time it was really done, not the day it was due.
    @Test
    func aLateTapShowsWhenItWasDoneWithItsTime() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(bySettingHour: 15, minute: 20, second: 0, of: Date()))
        let openDay = try #require(calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now)))
        let fixture = try makeFixture(openDay: openDay)

        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(), in: fixture.context, now: now
        )

        let completion = try #require(fixture.task.completions.first)
        let timestamp = HistoryPresentation.rowTimestamp(for: completion)
        #expect(timestamp.day == now)
        #expect(timestamp.time == now)
    }

    /// A past day named on a task with no time of its own: no real time is known, so the row shows
    /// the day alone.
    @Test
    func aFillInShowsTheDayAndNoTime() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(bySettingHour: 15, minute: 20, second: 0, of: Date()))
        let today = calendar.startOfDay(for: now)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let fixture = try makeFixture(openDay: today)

        try TaskActionService.recordCompletion(
            of: fixture.task, with: CareTaskCompletionInput(completedForDate: yesterday),
            in: fixture.context, now: now
        )

        let completion = try #require(fixture.task.completions.first)
        let timestamp = HistoryPresentation.rowTimestamp(for: completion)
        #expect(timestamp.day == yesterday)
        #expect(timestamp.time == nil)
    }

    private func makeFixture(openDay: Date) throws -> (container: ModelContainer, context: ModelContext, task: CareTask) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let task = CareTask(title: "Feed Mochi")
        task.createdAt = try #require(Calendar.current.date(byAdding: .day, value: -30, to: openDay))
        let schedule = CareTaskSchedule(
            scheduledDate: Calendar.current.startOfDay(for: openDay),
            frequency: .daily,
            frequencyInterval: 1
        )
        schedule.task = task
        task.schedules = [schedule]
        context.insert(Caregiver(name: "Primary Caregiver", role: .primary))
        context.insert(task)
        context.insert(schedule)
        try context.save()
        return (container, context, task)
    }
}
