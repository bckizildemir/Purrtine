import Foundation

enum HistoryPresentationState: Equatable {
    case noTasks
    case noCompletions
    case taskNoCompletions
    case searchEmpty
    case content
}

enum HistoryPresentation {
    static func filteredCompletions(
        from completions: [CareTaskCompletion],
        query: String
    ) -> [CareTaskCompletion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return completions }

        return completions.filter { completion in
            let taskTitle = completion.task?.title ?? ""
            let catNames = completion.cats.map(\.name).joined(separator: " ")
            let notes = completion.notes ?? ""
            return taskTitle.localizedStandardContains(trimmedQuery)
                || catNames.localizedStandardContains(trimmedQuery)
                || notes.localizedStandardContains(trimmedQuery)
        }
    }

    static func state(
        taskCount: Int,
        completions: [CareTaskCompletion],
        searchText: String,
        isTaskScoped: Bool
    ) -> HistoryPresentationState {
        guard taskCount > 0 else { return .noTasks }
        guard completions.isEmpty == false else {
            return isTaskScoped ? .taskNoCompletions : .noCompletions
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return .content }

        let filteredCompletions = filteredCompletions(from: completions, query: trimmedQuery)
        return filteredCompletions.isEmpty ? .searchEmpty : .content
    }
}
