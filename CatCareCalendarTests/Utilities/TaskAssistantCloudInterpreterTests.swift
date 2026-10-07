import Foundation
import SwiftData
import Testing
@testable import CatCareCalendar

@MainActor
struct TaskAssistantCloudInterpreterTests {
    @Test
    func requestPayloadSerializesTasksAndCats() throws {
        let fixture = try makeFixture()
        let sut = FirebaseTaskAssistantCloudInterpreter()
        let referenceDate = Date()

        let payload = sut.requestPayload(text: "I fed the cats", tasks: [fixture.feedLuna], referenceDate: referenceDate)

        #expect(payload["text"] as? String == "I fed the cats")
        let tasks = try #require(payload["tasks"] as? [[String: Any]])
        #expect(tasks.count == 1)
        #expect(tasks[0]["id"] as? String == fixture.feedLuna.id.uuidString)
        #expect(tasks[0]["category"] as? String == "feeding")
        let cats = try #require(tasks[0]["cats"] as? [[String: Any]])
        #expect(cats.first?["name"] as? String == "Luna")
    }

    @Test
    func confirmedResponseMapsToCompletionActionWithFilteredCats() throws {
        let fixture = try makeFixture()
        let sut = FirebaseTaskAssistantCloudInterpreter()
        let response: [String: Any] = [
            "match": "confirmed",
            "command": "complete",
            "taskId": fixture.feedLuna.id.uuidString,
            "catIds": [fixture.luna.id.uuidString, "unknown-cat-id"]
        ]

        let result = try sut.interpretation(from: response, tasks: [fixture.feedLuna], referenceDate: Date())

        guard case .confirmation(let confirmation) = result, case .complete(let task, _, _, let cats) = confirmation.action else {
            Issue.record("Expected a completion confirmation.")
            return
        }
        #expect(task.id == fixture.feedLuna.id)
        #expect(cats.map(\.id) == [fixture.luna.id])
    }

    @Test
    func hallucinatedTaskIdIsRejected() throws {
        let fixture = try makeFixture()
        let sut = FirebaseTaskAssistantCloudInterpreter()
        let response: [String: Any] = ["match": "confirmed", "command": "complete", "taskId": "not-a-real-id"]

        #expect(throws: FirebaseTaskAssistantCloudInterpreter.CloudInterpreterError.self) {
            try sut.interpretation(from: response, tasks: [fixture.feedLuna], referenceDate: Date())
        }
    }

    @Test
    func noneMatchThrowsNoMatch() throws {
        let fixture = try makeFixture()
        let sut = FirebaseTaskAssistantCloudInterpreter()

        #expect(throws: FirebaseTaskAssistantCloudInterpreter.CloudInterpreterError.noMatch) {
            try sut.interpretation(from: ["match": "none"], tasks: [fixture.feedLuna], referenceDate: Date())
        }
    }

    @Test
    func clarifyMapsOnlyKnownCandidatesToSuggestions() throws {
        let fixture = try makeFixture()
        let sut = FirebaseTaskAssistantCloudInterpreter()
        let response: [String: Any] = [
            "match": "clarify",
            "command": "complete",
            "candidateTaskIds": [fixture.feedLuna.id.uuidString, fixture.feedMochi.id.uuidString, "unknown-id"]
        ]

        let result = try sut.interpretation(from: response, tasks: [fixture.feedLuna, fixture.feedMochi], referenceDate: Date())

        guard case .clarification(let clarification) = result else {
            Issue.record("Expected a clarification response.")
            return
        }
        #expect(clarification.suggestions.count == 2)
    }

    @Test
    func postponeUsesProvidedMinutes() throws {
        let fixture = try makeFixture()
        let sut = FirebaseTaskAssistantCloudInterpreter()
        let response: [String: Any] = [
            "match": "confirmed",
            "command": "postpone",
            "taskId": fixture.feedLuna.id.uuidString,
            "postponeMinutes": 45
        ]

        let result = try sut.interpretation(from: response, tasks: [fixture.feedLuna], referenceDate: Date())

        guard case .confirmation(let confirmation) = result, case .postpone(_, let minutes) = confirmation.action else {
            Issue.record("Expected a postpone confirmation.")
            return
        }
        #expect(minutes == 45)
    }

    private func makeFixture() throws -> (
        container: ModelContainer,
        luna: Cat,
        feedLuna: CareTask,
        feedMochi: CareTask
    ) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let luna = Cat(name: "Luna")
        let mochi = Cat(name: "Mochi")
        let feedLuna = CareTask(title: "Feed Luna", category: .feeding)
        feedLuna.assignedCats = [luna]
        let feedMochi = CareTask(title: "Feed Mochi", category: .feeding)
        feedMochi.assignedCats = [mochi]

        context.insert(luna)
        context.insert(mochi)
        context.insert(feedLuna)
        context.insert(feedMochi)
        try context.save()

        return (container, luna, feedLuna, feedMochi)
    }
}
