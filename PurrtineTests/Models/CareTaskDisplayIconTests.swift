import Foundation
import Testing
@testable import Purrtine

@MainActor
struct CareTaskDisplayIconTests {
    @Test(arguments: ["circle", "", "  "])
    func placeholderIconFallsBackToTheCategoryIcon(storedIcon: String) {
        let task = CareTask(title: "Custom", category: .water, iconName: storedIcon)

        #expect(task.displayIconName == CareTaskCategory.water.iconName)
    }

    @Test
    func chosenIconIsKept() {
        let task = CareTask(title: "Feed", category: .feeding, iconName: "fork.knife")

        #expect(task.displayIconName == "fork.knife")
    }

    @Test
    func customGeneralTaskShowsANonEmptySymbol() {
        let task = CareTask(title: "Brush teeth")

        #expect(task.displayIconName == CareTaskCategory.general.iconName)
        #expect(task.displayIconName != "circle")
        #expect(task.displayIconName != "circle.fill")
    }

    @Test(arguments: CareTaskCategory.allCases)
    func noCategoryUsesAPlainCircle(category: CareTaskCategory) {
        #expect(category.iconName != "circle")
        #expect(category.iconName != "circle.fill")
    }

    @Test
    func routineStatusRowUsesTheDisplayIcon() {
        let task = CareTask(title: "Custom")
        let schedule = CareTaskSchedule(scheduledDate: Date(), frequency: .weekly)
        schedule.task = task
        task.schedules = [schedule]
        let completion = CareTaskCompletion(completedAt: Date(), completedForDate: Date())
        completion.task = task
        task.completions = [completion]

        let rows = HomeRoutineStatusPresentation.rows(from: [task])

        #expect(rows.first?.iconName == task.displayIconName)
    }
}
