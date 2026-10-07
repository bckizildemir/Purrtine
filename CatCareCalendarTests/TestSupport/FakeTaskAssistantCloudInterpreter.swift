@testable import CatCareCalendar
import Foundation

final class FakeTaskAssistantCloudInterpreter: TaskAssistantCloudInterpreting, @unchecked Sendable {
    enum StubError: Error {
        case forcedFailure
    }

    var result: Result<TaskAssistantInterpreter.Interpretation, Error> = .failure(StubError.forcedFailure)
    private(set) var callCount = 0
    private(set) var lastText: String?

    func interpret(
        text: String,
        tasks: [CareTask],
        referenceDate: Date
    ) async throws -> TaskAssistantInterpreter.Interpretation {
        callCount += 1
        lastText = text
        return try result.get()
    }
}
