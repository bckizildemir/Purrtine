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
        query: String,
        fallbackCutoff: Date? = nil
    ) -> [CareTaskCompletion] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return completions }

        return completions.filter { completion in
            let taskTitle = completion.task?.title ?? ""
            let catNames = displayCats(for: completion, fallbackCutoff: fallbackCutoff)
                .map(\.name)
                .joined(separator: " ")
            let notes = completion.notes ?? ""
            return taskTitle.localizedStandardContains(trimmedQuery)
                || catNames.localizedStandardContains(trimmedQuery)
                || notes.localizedStandardContains(trimmedQuery)
        }
    }

    /// The cats a History row shows and a search matches.
    ///
    /// Schema V1 could strip a completion of its cat when a later completion named the same cat.
    /// So a completion with no cats that was recorded BEFORE `fallbackCutoff` (the first launch of
    /// schema V2, see `HistoryCatFallbackCutoff`) shows the task's assigned cats instead. A
    /// completion recorded at or after the cutoff keeps exactly its own cats, which can be empty
    /// (for example when its only cat was deleted). With no cutoff there is no fallback.
    /// Read-only: nothing is written to the store.
    static func displayCats(for completion: CareTaskCompletion, fallbackCutoff: Date?) -> [Cat] {
        guard completion.cats.isEmpty,
              let fallbackCutoff,
              completion.completedAt < fallbackCutoff else {
            return completion.cats
        }
        return completion.task?.assignedCats ?? []
    }

    static func state(
        taskCount: Int,
        completions: [CareTaskCompletion],
        searchText: String,
        isTaskScoped: Bool,
        fallbackCutoff: Date? = nil
    ) -> HistoryPresentationState {
        guard taskCount > 0 else { return .noTasks }
        guard completions.isEmpty == false else {
            return isTaskScoped ? .taskNoCompletions : .noCompletions
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else { return .content }

        let filteredCompletions = filteredCompletions(
            from: completions,
            query: trimmedQuery,
            fallbackCutoff: fallbackCutoff
        )
        return filteredCompletions.isEmpty ? .searchEmpty : .content
    }
}
