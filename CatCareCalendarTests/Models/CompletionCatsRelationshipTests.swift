import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

/// Regression for the History bug seen on 2026-11-07: a completion lost its cat after a later
/// completion named the same cat. `CareTaskCompletion.cats` has no `inverse:`.
@MainActor
struct CompletionCatsRelationshipTests {
    @Test
    func everyCompletionKeepsItsCatAfterLaterCompletionsForTheSameCat() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let cat = Cat(name: "Miso")
        let caregiver = Caregiver(name: "Primary Caregiver", role: .primary)
        context.insert(cat)
        context.insert(caregiver)

        let tasks = ["Daily Feeding", "Refresh Water", "Brush coat"].map { title -> CareTask in
            let task = CareTask(title: title)
            let schedule = CareTaskSchedule(
                scheduledDate: Date(),
                frequency: .daily,
                frequencyInterval: 1,
                endDate: nil,
                reminderMinutes: 15
            )
            schedule.task = task
            task.schedules = [schedule]
            task.assignedCats = [cat]
            context.insert(task)
            return task
        }
        try context.save()

        // Two tasks for the same cat, and the first task completed twice on the same day.
        for task in [tasks[0], tasks[1], tasks[2], tasks[0], tasks[1]] {
            try TaskActionService.recordCompletion(of: task, with: CareTaskCompletionInput(), in: context)
            try context.save()
        }

        let completions = try context.fetch(FetchDescriptor<CareTaskCompletion>())
        #expect(completions.count == 5)
        let catless = completions.filter { $0.cats.isEmpty }.compactMap { $0.task?.title }
        #expect(catless.isEmpty, "completions that lost their cat: \(catless)")
    }
}
