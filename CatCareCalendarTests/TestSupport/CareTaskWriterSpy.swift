import Foundation
import SwiftData
@testable import CatCareCalendar

/// Records what a view model asked the writer to do and does nothing else. The postcondition itself
/// is covered by `CareTaskWriterTests` against a real store; suites that use this spy assert only
/// that the right write was requested for the right task.
final class CareTaskWriterSpy: CareTaskWriting {
    private(set) var savedTasks: [CareTask] = []
    private(set) var deletedTaskIds: [UUID] = []
    private(set) var completions: [(task: CareTask, input: CareTaskCompletionInput)] = []
    private(set) var snoozes: [(task: CareTask, minutes: Int)] = []
    private(set) var refreshedTaskIds: [[UUID]] = []

    func save(_ task: CareTask, in context: ModelContext) async throws {
        savedTasks.append(task)
    }

    func delete(_ task: CareTask, in context: ModelContext) async throws {
        deletedTaskIds.append(task.id)
    }

    func complete(
        _ task: CareTask,
        with input: CareTaskCompletionInput,
        in context: ModelContext
    ) async throws {
        completions.append((task, input))
    }

    func snooze(_ task: CareTask, minutes: Int) async throws {
        snoozes.append((task, minutes))
    }

    func refreshReminders(for taskIds: [UUID], in context: ModelContext) async throws {
        refreshedTaskIds.append(taskIds)
    }
}
