import Foundation
import SwiftData
import Testing
@testable import Purrtine

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

    @Test(arguments: ["Complete Brush coat", "Brush coat done", "Complete Coat grooming", "Coat grooming done"])
    func genericCompletionWordCompletesNamedGroomingTask(text: String) throws {
        let fixture = try makeFixture()
        let brush = try insertTask(title: "Brush coat", category: .grooming, into: fixture.container)
        let groom = try insertTask(title: "Coat grooming", category: .grooming, into: fixture.container)
        let grooming = text.contains("Brush") ? brush : groom

        let result = fixture.interpreter.interpret(text: text, tasks: fixture.tasks + [grooming])

        assertConfirmation(result, expectedTitle: grooming.title) { action in
            guard case .complete(let task, _, _, _) = action else {
                Issue.record("Expected a completion action.")
                return
            }

            #expect(task.title == grooming.title)
        }
    }

    @Test
    func turkishGenericCompletionWordCompletesNamedNonGeneralTask() throws {
        let fixture = try makeFixture()
        let grooming = try insertTask(title: "Fırçalama", category: .grooming, into: fixture.container)

        let result = fixture.interpreter.interpret(text: "Fırçalama tamamla", tasks: fixture.tasks + [grooming])

        assertConfirmation(result, expectedTitle: "Fırçalama") { action in
            guard case .complete(let task, _, _, _) = action else {
                Issue.record("Expected a completion action.")
                return
            }

            #expect(task.title == "Fırçalama")
        }
    }

    @Test
    func turkishVerbAliasStillCompletesGroomingTask() throws {
        let fixture = try makeFixture()
        let grooming = try insertTask(title: "Tarak", category: .grooming, into: fixture.container)

        let result = fixture.interpreter.interpret(text: "Tarak tamamla", tasks: fixture.tasks + [grooming])

        assertConfirmation(result, expectedTitle: "Tarak") { action in
            guard case .complete = action else {
                Issue.record("Expected a completion action.")
                return
            }
        }
    }

    @Test
    func genericCompletionWordAloneDoesNotCompleteAnyTask() throws {
        let fixture = try makeFixture()
        let grooming = try insertTask(title: "Brush coat", category: .grooming, into: fixture.container)
        let tasks = fixture.tasks + [grooming]

        assertNoMatch(fixture.interpreter.interpret(text: "done", tasks: tasks))
        assertNoMatch(fixture.interpreter.interpret(text: "tamamla", tasks: tasks))
    }

    @Test
    func genericCompletionWordWithManySimilarGeneralTasksAsksTaskDisambiguation() throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let tasks = try (1...18).map { number in
            try insertTask(
                title: "UI Test Long Task \(number < 10 ? "0\(number)" : "\(number)")",
                category: .general,
                into: container
            )
        }

        let result = TaskAssistantInterpreter().interpret(text: "complete long task", tasks: tasks)

        guard case .taskDisambiguation(let disambiguation) = result else {
            Issue.record("Expected a task-disambiguation response, got \(result).")
            return
        }

        #expect(disambiguation.choices.count > 1)
    }

    @Test
    func completeRequestSkipsTaskAlreadyDoneTodayAndConfirmsTheOpenOne() throws {
        let fixture = try makeWaterRefreshFixture(doneTodayIndices: [0])
        let result = fixture.interpreter.interpret(text: "complete water refresh", tasks: fixture.tasks)

        guard case .confirmation(let confirmation) = result,
              case .complete(let task, _, _, _) = confirmation.action else {
            Issue.record("Expected a completion confirmation, got \(result).")
            return
        }

        #expect(task === fixture.tasks[1])
    }

    @Test
    func completeRequestWithEveryMatchDoneTodaySaysAlreadyDone() throws {
        let fixture = try makeWaterRefreshFixture(doneTodayIndices: [0, 1])
        let result = fixture.interpreter.interpret(text: "complete water refresh", tasks: fixture.tasks)

        guard case .assistantMessage(let message) = result else {
            Issue.record("Expected an assistant message, got \(result).")
            return
        }

        #expect(message == String(localized: .taskAssistantAlreadyDoneToday))
    }

    @Test
    func completeRequestWithSeveralOpenMatchesListsOnlyTheOpenOnes() throws {
        let fixture = try makeWaterRefreshFixture(doneTodayIndices: [0], taskCount: 3)
        let result = fixture.interpreter.interpret(text: "complete water refresh", tasks: fixture.tasks)

        guard case .taskDisambiguation(let disambiguation) = result else {
            Issue.record("Expected a task-disambiguation response, got \(result).")
            return
        }

        let offered = disambiguation.choices.map(\.task)
        #expect(offered.count == 2)
        #expect(offered.contains { $0 === fixture.tasks[0] } == false)
    }

    @Test
    func postponeRequestStillOffersTasksDoneToday() throws {
        let fixture = try makeWaterRefreshFixture(doneTodayIndices: [0])
        let result = fixture.interpreter.interpret(text: "postpone water refresh", tasks: fixture.tasks)

        guard case .clarification(let clarification) = result else {
            Issue.record("Expected a clarification response, got \(result).")
            return
        }

        #expect(clarification.suggestions.count == 2)
    }

    @Test
    func completionOfAnEarlierOccurrenceDoesNotCountAsDoneToday() throws {
        let fixture = try makeWaterRefreshFixture(doneTodayIndices: [], doneYesterdayIndices: [0])
        let result = fixture.interpreter.interpret(text: "complete water refresh", tasks: fixture.tasks)

        guard case .taskDisambiguation(let disambiguation) = result else {
            Issue.record("Expected a task-disambiguation response, got \(result).")
            return
        }

        #expect(disambiguation.choices.count == 2)
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

    /// Daily general tasks with the same title, one per cat, all due today. A completion for today's
    /// occurrence marks that task done; the schedule is left untouched so it stays due today.
    private func makeWaterRefreshFixture(
        doneTodayIndices: Set<Int>,
        doneYesterdayIndices: Set<Int> = [],
        taskCount: Int = 2
    ) throws -> (container: ModelContainer, tasks: [CareTask], interpreter: TaskAssistantInterpreter) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let catNames = ["Luna", "Mochi", "Pamuk"]

        let tasks = (0..<taskCount).map { index -> CareTask in
            let cat = Cat(name: catNames[index])
            let task = CareTask(title: "Water Refresh", category: .general)
            task.assignedCats = [cat]
            let schedule = CareTaskSchedule(scheduledDate: today, frequency: .daily)
            schedule.task = task
            task.schedules = [schedule]
            context.insert(cat)
            context.insert(task)
            context.insert(schedule)

            let completionDay: Date? = doneTodayIndices.contains(index)
                ? today
                : (doneYesterdayIndices.contains(index) ? yesterday : nil)
            if let completionDay {
                let completion = CareTaskCompletion(completedAt: Date(), completedForDate: completionDay)
                completion.task = task
                task.completions.append(completion)
                context.insert(completion)
            }
            return task
        }
        try context.save()

        return (container: container, tasks: tasks, interpreter: TaskAssistantInterpreter())
    }

    private func insertTask(
        title: String,
        category: CareTaskCategory,
        into container: ModelContainer
    ) throws -> CareTask {
        let task = CareTask(title: title, category: category)
        container.mainContext.insert(task)
        try container.mainContext.save()
        return task
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
