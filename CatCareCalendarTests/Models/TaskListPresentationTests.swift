import Foundation
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct TaskListPresentationTests {
    @Test
    func searchMatchesTaskTitleAndDescription() {
        let litterTask = CareTask(title: "Clean litter", description: "Deep clean the tray")
        let feedingTask = CareTask(title: "Feed Mochi", description: "Serve wet food")

        let titleResults = TaskListDerivation.filteredTasks(
            from: [litterTask, feedingTask],
            filter: .all,
            searchText: "Mochi"
        )
        let descriptionResults = TaskListDerivation.filteredTasks(
            from: [litterTask, feedingTask],
            filter: .all,
            searchText: "tray"
        )

        #expect(titleResults.map(\.id) == [feedingTask.id])
        #expect(descriptionResults.map(\.id) == [litterTask.id])
    }

    @Test
    func searchMatchesAssignedCatName() {
        let mochi = Cat(name: "Mochi")
        let luna = Cat(name: "Luna")
        let medicationTask = CareTask(title: "Give medication")
        let playTask = CareTask(title: "Play time")

        medicationTask.assignedCats = [mochi]
        playTask.assignedCats = [luna]

        let results = TaskListDerivation.filteredTasks(
            from: [medicationTask, playTask],
            filter: .all,
            searchText: "Mochi"
        )

        #expect(results.map(\.id) == [medicationTask.id])
    }

    @Test
    func searchTrimsWhitespaceBeforeMatching() {
        let groomingTask = CareTask(title: "Brush coat")
        let feedingTask = CareTask(title: "Evening meal")

        let results = TaskListDerivation.filteredTasks(
            from: [groomingTask, feedingTask],
            filter: .all,
            searchText: "  Brush  "
        )

        #expect(results.map(\.id) == [groomingTask.id])
    }

    @Test
    func searchMatchesLocalizedCategoryName() {
        let feedingTask = CareTask(title: "Breakfast", category: .feeding)
        let litterTask = CareTask(title: "Tray cleanup", category: .litter)

        let results = TaskListDerivation.filteredTasks(
            from: [feedingTask, litterTask],
            filter: .all,
            searchText: feedingTask.category.displayName
        )

        #expect(results.map(\.id) == [feedingTask.id])
    }
}
