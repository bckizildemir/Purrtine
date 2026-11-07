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
            let catNames = displayCats(for: completion).map(\.name).joined(separator: " ")
            let notes = completion.notes ?? ""
            return taskTitle.localizedStandardContains(trimmedQuery)
                || catNames.localizedStandardContains(trimmedQuery)
                || notes.localizedStandardContains(trimmedQuery)
        }
    }

    /// The cats a History row shows and a search matches. Completions saved before schema V2 may
    /// have lost their cat link (a later completion took it away), so an empty list falls back to
    /// the task's assigned cats. Read-only: nothing is written to the store.
    static func displayCats(for completion: CareTaskCompletion) -> [Cat] {
        completion.cats.isEmpty ? (completion.task?.assignedCats ?? []) : completion.cats
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
