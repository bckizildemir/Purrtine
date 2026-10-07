import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@Suite
@MainActor
struct TaskAssistantInterpreterTests {
    @Test
    func exactEnglishTaskTitleCreatesCompletionConfirmation() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "complete Feed Luna", tasks: fixture.tasks)

        assertConfirmation(result, expectedTitle: "Feed Luna") { action in
            guard case .complete(let task, _, _, _) = action else {
                Issue.record("Expected a completion action.")
                return
            }

            #expect(task.title == "Feed Luna")
        }
    }

    @Test
    func englishParaphraseMatchesFeedingTask() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "I fed Luna", tasks: fixture.tasks)

        assertConfirmation(result, expectedTitle: "Feed Luna") { action in
            guard case .complete(let task, _, _, _) = action else {
                Issue.record("Expected a completion action.")
                return
            }

            #expect(task.title == "Feed Luna")
        }
    }

    @Test
    func turkishLitterParaphraseMatchesTask() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "kedilerin kumunu değiştirdim", tasks: fixture.tasks)

        assertConfirmation(result, expectedTitle: "kum değiş") { action in
            guard case .complete(let task, _, _, _) = action else {
                Issue.record("Expected a completion action.")
                return
            }

            #expect(task.title == "kum değiş")
        }
    }

    @Test
    func turkishWaterBowlParaphraseMatchesTask() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "kedilerin su kabını yıkadım", tasks: fixture.tasks)

        assertConfirmation(result, expectedTitle: "su kabı yıka") { action in
            guard case .complete(let task, _, _, _) = action else {
                Issue.record("Expected a completion action.")
                return
            }

            #expect(task.title == "su kabı yıka")
        }
    }

    @Test
    func abbreviatedTurkishPostponePhraseCreatesReminderAction() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "kum için 30 dk sonra hatırlat", tasks: fixture.tasks)

        guard case .confirmation(let confirmation) = result else {
            Issue.record("Expected a confirmation response.")
            return
        }

        guard case .postpone(let task, let minutes) = confirmation.action else {
            Issue.record("Expected a postpone action.")
            return
        }

        #expect(task.title == "kum değiş")
        #expect(minutes == 30)
    }

    @Test
    func explicitOpenPhraseCreatesOpenAction() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "open Luna feeding details", tasks: fixture.tasks)

        guard case .confirmation(let confirmation) = result else {
            Issue.record("Expected a confirmation response.")
            return
        }

        guard case .open(let task) = confirmation.action else {
            Issue.record("Expected an open action.")
            return
        }

        #expect(task.title == "Feed Luna")
    }

    @Test
    func ambiguousCategoryPhraseRequestsClarification() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "open feeding", tasks: fixture.tasks)

        guard case .clarification(let clarification) = result else {
            Issue.record("Expected a clarification response.")
            return
        }

        #expect(clarification.suggestions.count == 2)
        #expect(clarification.suggestions.map(\.title).contains("Feed Luna"))
        #expect(clarification.suggestions.map(\.title).contains("Feed Mochi"))
    }

    @Test
    func pluralFeedingPhraseAsksClarificationBetweenFeedingTasks() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "I fed the cats", tasks: fixture.tasks)

        guard case .clarification(let clarification) = result else {
            Issue.record("Expected a clarification response.")
            return
        }

        #expect(clarification.suggestions.count == 2)
        #expect(clarification.suggestions.map(\.title).contains("Feed Luna"))
        #expect(clarification.suggestions.map(\.title).contains("Feed Mochi"))
    }

    @Test
    func pluralFeedingPhraseConfirmsSingleFeedingTask() throws {
        let fixture = try makeFixture()
        let tasks = fixture.tasks.filter { $0.title != "Feed Mochi" }
        let result = fixture.interpreter.interpret(text: "I fed the cats", tasks: tasks)

        assertConfirmation(result, expectedTitle: "Feed Luna") { action in
            guard case .complete(let task, _, _, _) = action else {
                Issue.record("Expected a completion action.")
                return
            }

            #expect(task.title == "Feed Luna")
        }
    }

    @Test
    func turkishFeedingParaphraseConfirmsFeedingTask() throws {
        let fixture = try makeFixture()
        let tasks = fixture.tasks.filter { $0.title != "Feed Mochi" }
        let result = fixture.interpreter.interpret(text: "kedileri besledim", tasks: tasks)

        assertConfirmation(result, expectedTitle: "Feed Luna") { action in
            guard case .complete(let task, _, _, _) = action else {
                Issue.record("Expected a completion action.")
                return
            }

            #expect(task.title == "Feed Luna")
        }
    }

    @Test
    func irregularVerbWithCatNameConfirmsFeedingTask() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "I gave food to Mochi", tasks: fixture.tasks)

        assertConfirmation(result, expectedTitle: "Feed Mochi") { action in
            guard case .complete(let task, _, _, _) = action else {
                Issue.record("Expected a completion action.")
                return
            }

            #expect(task.title == "Feed Mochi")
        }
    }

    @Test
    func genericVerbDoesNotConfirmGeneralTask() throws {
        let fixture = try makeFixture()
        let generalTask = CareTask(title: "weekly checkup notes", category: .general)
        fixture.container.mainContext.insert(generalTask)
        try fixture.container.mainContext.save()

        let result = fixture.interpreter.interpret(text: "I finished it", tasks: fixture.tasks + [generalTask])

        assertNoMatch(result)
    }

    @Test
    func weakSingleTokenMatchReturnsNoMatch() throws {
        let fixture = try makeFixture()
        assertNoMatch(fixture.interpreter.interpret(text: "kum", tasks: fixture.tasks))
    }

    @Test
    func genericCompletionWithoutEvidenceReturnsNoMatch() throws {
        let fixture = try makeFixture()
        assertNoMatch(fixture.interpreter.interpret(text: "complete it", tasks: fixture.tasks))
    }

    @Test
    func genericPostponeWithoutEvidenceReturnsNoMatch() throws {
        let fixture = try makeFixture()
        assertNoMatch(fixture.interpreter.interpret(text: "remind me later", tasks: fixture.tasks))
    }

    @Test
    func bareCatNameWithSingleStrongMatchGoesToIntentSelection() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "Luna", tasks: fixture.tasks)

        guard case .intentSelection(let selection) = result else {
            Issue.record("Expected an intent-selection response.")
            return
        }

        #expect(selection.task.title == "Feed Luna")
    }

    @Test
    func bareCatNamesWithMultipleMatchesRequestTaskDisambiguation() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "Luna and Mochi", tasks: fixture.tasks)

        guard case .taskDisambiguation(let disambiguation) = result else {
            Issue.record("Expected a task-disambiguation response.")
            return
        }

        #expect(disambiguation.message == String(localized: .taskAssistantTaskDisambiguation))
        #expect(disambiguation.choices.count >= 2)
        #expect(disambiguation.choices.map(\.task.title).contains("Feed Luna"))
        #expect(disambiguation.choices.map(\.task.title).contains("Feed Mochi"))
    }

    @Test
    func verblessUnrelatedTextReturnsNoMatch() throws {
        let fixture = try makeFixture()
        assertNoMatch(fixture.interpreter.interpret(text: "the weather", tasks: fixture.tasks))
    }

    @Test
    func verbBearingPhraseIsUnaffectedByTheNoCommandPath() throws {
        let fixture = try makeFixture()
        let result = fixture.interpreter.interpret(text: "I fed Luna", tasks: fixture.tasks)

        guard case .confirmation(let confirmation) = result else {
            Issue.record("Expected a confirmation response, not a task/intent-selection detour.")
            return
        }

        guard case .complete(let task, _, _, _) = confirmation.action else {
            Issue.record("Expected a completion action.")
            return
        }

        #expect(task.title == "Feed Luna")
    }

    private func makeFixture() throws -> (
        container: ModelContainer,
        tasks: [CareTask],
        interpreter: TaskAssistantInterpreter
    ) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: Date())

        let luna = Cat(name: "Luna")
        let mochi = Cat(name: "Mochi")

        let overdueFeeding = CareTask(title: "Feed Luna", category: .feeding)
        overdueFeeding.assignedCats = [luna]
        let overdueSchedule = CareTaskSchedule(
            scheduledDate: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
            frequency: .daily
        )
        overdueSchedule.task = overdueFeeding
        overdueFeeding.schedules = [overdueSchedule]

        let todayFeeding = CareTask(title: "Feed Mochi", category: .feeding)
        todayFeeding.assignedCats = [mochi]
        let todayFeedingSchedule = CareTaskSchedule(scheduledDate: today, frequency: .daily)
        todayFeedingSchedule.task = todayFeeding
        todayFeeding.schedules = [todayFeedingSchedule]

        let litterTask = CareTask(title: "kum değiş", category: .litter)
        litterTask.assignedCats = [luna, mochi]
        let litterSchedule = CareTaskSchedule(scheduledDate: today, frequency: .daily)
        litterSchedule.task = litterTask
        litterTask.schedules = [litterSchedule]

        let waterTask = CareTask(title: "su kabı yıka", category: .water)
        waterTask.assignedCats = [luna, mochi]
        let waterSchedule = CareTaskSchedule(scheduledDate: today, frequency: .daily)
        waterSchedule.task = waterTask
        waterTask.schedules = [waterSchedule]

        context.insert(luna)
        context.insert(mochi)
        context.insert(overdueFeeding)
        context.insert(overdueSchedule)
        context.insert(todayFeeding)
        context.insert(todayFeedingSchedule)
        context.insert(litterTask)
        context.insert(litterSchedule)
        context.insert(waterTask)
        context.insert(waterSchedule)
        try context.save()

        return (
            container: container,
            tasks: [overdueFeeding, todayFeeding, litterTask, waterTask],
            interpreter: TaskAssistantInterpreter()
        )
    }

    private func assertConfirmation(
        _ result: TaskAssistantInterpreter.Interpretation,
        expectedTitle: String,
        validateAction: (TaskAssistantAction) -> Void
    ) {
        guard case .confirmation(let confirmation) = result else {
            Issue.record("Expected a confirmation response.")
            return
        }

        #expect(confirmation.message.contains(expectedTitle))
        validateAction(confirmation.action)
    }

    private func assertNoMatch(_ result: TaskAssistantInterpreter.Interpretation) {
        guard case .assistantMessage(let message) = result else {
            Issue.record("Expected a no-match assistant message.")
            return
        }

        #expect(message == String(localized: .taskAssistantNoMatch))
    }
}
