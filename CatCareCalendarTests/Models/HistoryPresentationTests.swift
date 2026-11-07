import Foundation
import Testing
@testable import CatCareCalendar

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
}
