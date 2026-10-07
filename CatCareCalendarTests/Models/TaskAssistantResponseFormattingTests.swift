import Foundation
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct TaskAssistantResponseFormattingTests {
    @Test(arguments: [
        TaskAssistantCommandKind.complete,
        TaskAssistantCommandKind.postpone,
        TaskAssistantCommandKind.open
    ])
    func everyCommandHasNonemptyConfirmationAndClarificationCopy(
        command: TaskAssistantCommandKind
    ) {
        #expect(TaskAssistantResponseFormatting.confirmationTitle(for: command).isEmpty == false)
        #expect(TaskAssistantResponseFormatting.clarificationMessage(for: command).isEmpty == false)
    }

    @Test
    func completionMessageUsesExplicitCatsAndDate() {
        let task = CareTask(title: "Feed")
        task.assignedCats = [Cat(name: "Assigned")]
        let explicitCat = Cat(name: "Explicit")
        let date = Date(timeIntervalSince1970: 1_710_000_000)

        let message = TaskAssistantResponseFormatting.confirmationMessage(
            for: .complete(task: task, completedForDate: date, notes: nil, cats: [explicitCat])
        )
        let expected = String(
            localized: .taskAssistantConfirmCompletionMessage(
                "Feed",
                "Explicit",
                date.formatted(date: .abbreviated, time: .omitted)
            )
        )

        #expect(message == expected)
    }

    @Test
    func completionMessageFallsBackToAssignedCatsAndAllCats() {
        let assignedTask = CareTask(title: "Brush")
        assignedTask.assignedCats = [Cat(name: "Mochi"), Cat(name: "Luna")]
        let allCatsTask = CareTask(title: "Clean bowls")

        let assignedMessage = TaskAssistantResponseFormatting.confirmationMessage(
            for: .complete(task: assignedTask, completedForDate: nil, notes: nil, cats: [])
        )
        let allCatsMessage = TaskAssistantResponseFormatting.confirmationMessage(
            for: .complete(task: allCatsTask, completedForDate: nil, notes: nil, cats: [])
        )

        #expect(
            assignedMessage
                == String(localized: .taskAssistantConfirmCompletionToday("Brush", "Mochi, Luna"))
        )
        #expect(
            allCatsMessage
                == String(
                    localized: .taskAssistantConfirmCompletionToday(
                        "Clean bowls",
                        String(localized: .tasksConfigAllCats)
                    )
                )
        )
    }

    @Test
    func postponeAndOpenMessagesIncludeActionDetails() {
        let task = CareTask(title: "Medication")

        #expect(
            TaskAssistantResponseFormatting.confirmationMessage(for: .postpone(task: task, minutes: 45))
                == String(localized: .taskAssistantConfirmPostponeMessage("Medication", 45))
        )
        #expect(
            TaskAssistantResponseFormatting.confirmationMessage(for: .open(task: task))
                == String(localized: .taskAssistantConfirmOpenMessage("Medication"))
        )
    }
}
