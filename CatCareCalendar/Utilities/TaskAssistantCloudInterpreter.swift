import FirebaseCore
import FirebaseFunctions
import Foundation

/// Main-actor isolated on purpose: every method takes `[CareTask]`, and SwiftData model
/// instances must stay on the actor that owns their `ModelContext`. Without this the
/// conformance is non-isolated, so the async body runs on the cooperative pool and reads
/// `task.title` / `task.assignedCats` off the main actor. Only the network call suspends;
/// the payload building either side of it is cheap.
@MainActor
protocol TaskAssistantCloudInterpreting: Sendable {
    func interpret(
        text: String,
        tasks: [CareTask],
        referenceDate: Date
    ) async throws -> TaskAssistantInterpreter.Interpretation
}

/// Calls the `interpretTaskAssistantRequest` Cloud Function to classify a free-text
/// request the local heuristic interpreter couldn't resolve. The server only ever
/// selects among the task/cat ids this client sends — never trust it beyond that.
struct FirebaseTaskAssistantCloudInterpreter: TaskAssistantCloudInterpreting {
    enum CloudInterpreterError: Error {
        case firebaseNotConfigured
        case invalidResponse
        case unknownTask
        case noMatch
    }

    private let region: String
    private let functionName = "interpretTaskAssistantRequest"

    /// `nonisolated` so callers can build one in a default argument, which Swift evaluates
    /// outside the main actor. The stored properties are immutable, so this is safe.
    nonisolated init(region: String = "europe-west1") {
        self.region = region
    }

    func interpret(
        text: String,
        tasks: [CareTask],
        referenceDate: Date
    ) async throws -> TaskAssistantInterpreter.Interpretation {
        guard FirebaseApp.app() != nil else {
            throw CloudInterpreterError.firebaseNotConfigured
        }

        let payload = requestPayload(text: text, tasks: tasks, referenceDate: referenceDate)
        let result = try await Functions.functions(region: region)
            .httpsCallable(functionName)
            .call(payload)

        guard let response = result.data as? [String: Any] else {
            throw CloudInterpreterError.invalidResponse
        }

        return try interpretation(from: response, tasks: tasks, referenceDate: referenceDate)
    }

    /// The payload is typed as `[String: any Sendable]`, not `[String: Any]`,
    /// because every value in it is a `String`, a `Bool`, or an array of those.
    /// Saying so lets the dictionary cross into the callable's async call
    /// without an annotation, and the serialized form is unchanged.
    func requestPayload(text: String, tasks: [CareTask], referenceDate: Date) -> [String: any Sendable] {
        [
            "text": text,
            "referenceDate": referenceDate.ISO8601Format(),
            "tasks": tasks.map { task -> [String: any Sendable] in
                [
                    "id": task.id.uuidString,
                    "title": task.title,
                    "category": task.category.rawValue,
                    "isOverdue": task.isOverdue,
                    "isDueToday": task.activeDueDate.map {
                        Calendar.current.isDate($0, inSameDayAs: referenceDate)
                    } ?? false,
                    "cats": task.assignedCats.map { ["id": $0.id.uuidString, "name": $0.name] }
                ]
            }
        ]
    }

    func interpretation(
        from response: [String: Any],
        tasks: [CareTask],
        referenceDate: Date
    ) throws -> TaskAssistantInterpreter.Interpretation {
        guard let match = response["match"] as? String else {
            throw CloudInterpreterError.invalidResponse
        }
        guard match != "none" else {
            throw CloudInterpreterError.noMatch
        }
        guard let commandKind = TaskAssistantCommandKind(cloudValue: response["command"] as? String) else {
            throw CloudInterpreterError.invalidResponse
        }

        switch match {
        case "confirmed":
            guard
                let taskId = response["taskId"] as? String,
                let task = tasks.first(where: { $0.id.uuidString == taskId })
            else {
                throw CloudInterpreterError.unknownTask
            }

            let action = resolvedAction(
                command: commandKind,
                task: task,
                response: response,
                referenceDate: referenceDate
            )

            return .confirmation(
                TaskAssistantConfirmation(
                    title: TaskAssistantResponseFormatting.confirmationTitle(for: commandKind),
                    message: TaskAssistantResponseFormatting.confirmationMessage(for: action),
                    action: action
                )
            )

        case "clarify":
            let candidateIds = response["candidateTaskIds"] as? [String] ?? []
            let candidateTasks = candidateIds.compactMap { id in
                tasks.first(where: { $0.id.uuidString == id })
            }

            guard candidateTasks.count >= 2 else {
                throw CloudInterpreterError.invalidResponse
            }

            let suggestions = candidateTasks.map { task -> TaskAssistantSuggestion in
                let action = resolvedAction(command: commandKind, task: task, response: [:], referenceDate: referenceDate)
                return TaskAssistantSuggestion(title: task.title, subtitle: task.assignedCatNames, action: action)
            }

            return .clarification(
                TaskAssistantClarification(
                    message: TaskAssistantResponseFormatting.clarificationMessage(for: commandKind),
                    suggestions: suggestions
                )
            )

        default:
            throw CloudInterpreterError.invalidResponse
        }
    }

    private func resolvedAction(
        command: TaskAssistantCommandKind,
        task: CareTask,
        response: [String: Any],
        referenceDate: Date
    ) -> TaskAssistantAction {
        switch command {
        case .complete:
            let catIds = response["catIds"] as? [String] ?? []
            let selectedCats = task.assignedCats.filter { catIds.contains($0.id.uuidString) }
            let completedForDate: Date? = (response["completedForDate"] as? String) == "yesterday"
                ? Calendar.current.date(byAdding: .day, value: -1, to: referenceDate)
                : nil
            let notes = response["notes"] as? String

            return .complete(task: task, completedForDate: completedForDate, notes: notes, cats: selectedCats)

        case .postpone:
            let minutes = (response["postponeMinutes"] as? Int) ?? 30
            return .postpone(task: task, minutes: minutes)

        case .open:
            return .open(task: task)
        }
    }
}

private extension TaskAssistantCommandKind {
    init?(cloudValue: String?) {
        switch cloudValue {
        case "complete": self = .complete
        case "postpone": self = .postpone
        case "open": self = .open
        default: return nil
        }
    }
}
