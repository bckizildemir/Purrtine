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

    @Test
    func completionWithoutCatsFallsBackToTheTasksAssignedCats() {
        let miso = Cat(name: "Miso")
        let task = CareTask(title: "Daily Feeding")
        task.assignedCats = [miso]
        let orphaned = CareTaskCompletion()
        orphaned.task = task

        #expect(HistoryPresentation.displayCats(for: orphaned) == [miso])
        #expect(HistoryPresentation.filteredCompletions(from: [orphaned], query: "Miso") == [orphaned])
    }

    @Test
    func completionKeepsItsOwnCatsInsteadOfTheTasksAssignedCats() {
        let own = Cat(name: "Own")
        let assigned = Cat(name: "Assigned")
        let task = CareTask(title: "Daily Feeding")
        task.assignedCats = [assigned]
        let completion = CareTaskCompletion()
        completion.task = task
        completion.cats = [own]

        #expect(HistoryPresentation.displayCats(for: completion) == [own])
        #expect(HistoryPresentation.filteredCompletions(from: [completion], query: "Assigned").isEmpty)
    }

    @Test
    func completionWithoutCatsAndWithoutTaskShowsNoCats() {
        #expect(HistoryPresentation.displayCats(for: CareTaskCompletion()).isEmpty)
    }
}
