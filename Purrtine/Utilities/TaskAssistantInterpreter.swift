import Foundation
import NaturalLanguage

struct TaskAssistantInterpreter {
    enum Interpretation {
        case confirmation(TaskAssistantConfirmation)
        case clarification(TaskAssistantClarification)
        case taskDisambiguation(TaskAssistantTaskDisambiguation)
        case intentSelection(TaskAssistantIntentSelection)
        case assistantMessage(String)
    }

    private enum Command {
        case complete
        case postpone(minutes: Int)
        case open

        var kind: TaskAssistantCommandKind {
            switch self {
            case .complete: return .complete
            case .postpone: return .postpone
            case .open: return .open
            }
        }
    }

    private struct QueryAnalysis {
        let normalizedText: String
        let dominantLanguage: NLLanguage
        let significantTokens: [String]
        let expandedTokens: Set<String>
        let phrases: Set<String>
    }

    private struct RankedTask {
        let task: CareTask
        let score: Int
        let explicitMatchScore: Int
        let selectedCats: [Cat]
    }

    func interpret(
        text: String,
        tasks: [CareTask],
        referenceDate: Date = Date()
    ) -> Interpretation {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return .assistantMessage(String(localized: .taskAssistantEmptyInput))
        }

        let analysis = analyze(trimmedText)
        let explicitCommand = detectExplicitCommand(in: analysis)
        let completedForDate = detectCompletionDate(in: analysis, referenceDate: referenceDate)
        let extractedNotes = notes(in: trimmedText)

        // No recognizable action verb anywhere in the text (no open/postpone keyword, no
        // completion verb for any candidate task's category) — the command itself is
        // ambiguous, not just the task. Ask which task, then what to do with it, rather than
        // silently assuming `.complete`.
        guard explicitCommand != nil || hasCompletionVerbEvidence(in: analysis, tasks: tasks) else {
            return interpretWithoutCommand(
                analysis: analysis,
                tasks: tasks,
                referenceDate: referenceDate,
                completedForDate: completedForDate,
                notes: extractedNotes
            )
        }

        let command = explicitCommand ?? .complete
        let candidates = rankedTasks(
            for: analysis,
            tasks: tasks,
            command: command,
            referenceDate: referenceDate
        )

        guard let bestCandidate = candidates.first, isEligibleMatch(bestCandidate, for: command) else {
            return .assistantMessage(String(localized: .taskAssistantNoMatch))
        }

        let relevantCandidates = candidates.filter { candidate in
            candidate.explicitMatchScore >= minimumClarificationExplicitScore(for: command)
                && candidate.score >= minimumClarificationScore(for: command)
        }
        let topCandidates = Array(relevantCandidates.prefix(3))

        if shouldClarify(topCandidates, bestCandidate: bestCandidate, for: command) {
            let suggestions = topCandidates.map { candidate in
                TaskAssistantSuggestion(
                    title: candidate.task.title,
                    subtitle: candidate.task.assignedCatNames,
                    action: action(
                        for: command,
                        task: candidate.task,
                        completedForDate: completedForDate,
                        notes: extractedNotes,
                        selectedCats: candidate.selectedCats
                    )
                )
            }

            return .clarification(
                TaskAssistantClarification(
                    message: clarificationMessage(for: command),
                    suggestions: suggestions
                )
            )
        }

        guard isHighConfidenceMatch(bestCandidate, for: command) else {
            return .assistantMessage(String(localized: .taskAssistantNoMatch))
        }

        let resolvedAction = action(
            for: command,
            task: bestCandidate.task,
            completedForDate: completedForDate,
            notes: extractedNotes,
            selectedCats: bestCandidate.selectedCats
        )

        return .confirmation(
            TaskAssistantConfirmation(
                title: confirmationTitle(for: command),
                message: confirmationMessage(for: resolvedAction),
                action: resolvedAction
            )
        )
    }

    /// Ranks tasks by name/cat match alone (no command yet), then either asks which task was
    /// meant or — once a single task is settled — hands back an `.intentSelection` for the
    /// caller to ask what to do with it. Reuses `.complete`'s clarification/confirmation
    /// thresholds since this is the same name-matching domain.
    private func interpretWithoutCommand(
        analysis: QueryAnalysis,
        tasks: [CareTask],
        referenceDate: Date,
        completedForDate: Date?,
        notes: String?
    ) -> Interpretation {
        let candidates = rankedTasks(
            for: analysis,
            tasks: tasks,
            command: nil,
            referenceDate: referenceDate
        )

        guard let bestCandidate = candidates.first, isEligibleMatch(bestCandidate, for: .complete) else {
            return .assistantMessage(String(localized: .taskAssistantNoMatch))
        }

        let relevantCandidates = candidates.filter { candidate in
            candidate.explicitMatchScore >= minimumClarificationExplicitScore(for: .complete)
                && candidate.score >= minimumClarificationScore(for: .complete)
        }
        let topCandidates = Array(relevantCandidates.prefix(3))

        if shouldClarify(topCandidates, bestCandidate: bestCandidate, for: .complete) {
            let choices = topCandidates.map { candidate in
                TaskAssistantTaskChoice(task: candidate.task, selectedCats: candidate.selectedCats)
            }

            return .taskDisambiguation(
                TaskAssistantTaskDisambiguation(
                    message: String(localized: .taskAssistantTaskDisambiguation),
                    choices: choices,
                    completedForDate: completedForDate,
                    notes: notes
                )
            )
        }

        guard isHighConfidenceMatch(bestCandidate, for: .complete) else {
            return .assistantMessage(String(localized: .taskAssistantNoMatch))
        }

        return .intentSelection(
            TaskAssistantIntentSelection(
                task: bestCandidate.task,
                selectedCats: bestCandidate.selectedCats,
                completedForDate: completedForDate,
                notes: notes
            )
        )
    }

    private func analyze(_ text: String) -> QueryAnalysis {
        let dominantLanguage = dominantLanguage(in: text)
        let normalizedText = normalize(text)
        let tokens = tokenize(text)
        let significantTokens = tokens.filter { token in
            isSignificantToken(token, language: dominantLanguage)
        }

        return QueryAnalysis(
            normalizedText: normalizedText,
            dominantLanguage: dominantLanguage,
            significantTokens: significantTokens,
            expandedTokens: expand(tokens: significantTokens, language: dominantLanguage),
            phrases: phrases(from: significantTokens)
        )
    }

    private func action(
        for command: Command,
        task: CareTask,
        completedForDate: Date?,
        notes: String?,
        selectedCats: [Cat]
    ) -> TaskAssistantAction {
        switch command {
        case .complete:
            return .complete(
                task: task,
                completedForDate: completedForDate,
                notes: notes,
                cats: selectedCats
            )
        case .postpone(let minutes):
            return .postpone(task: task, minutes: minutes)
        case .open:
            return .open(task: task)
        }
    }

    /// `command` is `nil` when no action verb was detected yet — every task is eligible
    /// (status-based restrictions apply later, once an intent is actually chosen) and the
    /// completion-verb scoring bonus below is skipped (there is no verb to match).
    private func rankedTasks(
        for analysis: QueryAnalysis,
        tasks: [CareTask],
        command: Command?,
        referenceDate: Date
    ) -> [RankedTask] {
        let mentionedCatIDs = mentionedCatIDs(in: analysis, tasks: tasks)
        let allCatsRequested = requestsAllCats(in: analysis)

        return tasks.compactMap { task in
            if let command, supports(command, for: task) == false { return nil }

            let normalizedTitle = normalize(task.title)
            let titleTokens = tokenize(task.title).filter { isSignificantToken($0, language: analysis.dominantLanguage) }
            let titleExpandedTokens = expand(tokens: titleTokens, language: analysis.dominantLanguage)
            let titlePhrases = phrases(from: titleTokens)

            let aliasTerms = taskAliases(for: task)
            let aliasTokens = aliasTerms.flatMap(tokenize)
            let aliasExpandedTokens = expand(tokens: aliasTokens, language: analysis.dominantLanguage)
            let verbAliasTokens = taskVerbAliases(for: task.category).flatMap(tokenize)
            let verbAliasExpandedTokens = expand(tokens: verbAliasTokens, language: analysis.dominantLanguage)
            let aliasPhrases = Set(aliasTerms.compactMap { term in
                let normalizedTerm = normalize(term)
                return normalizedTerm.contains(" ") ? normalizedTerm : nil
            })

            let selectedCats = selectedCats(
                for: task,
                mentionedCatIDs: mentionedCatIDs,
                allCatsRequested: allCatsRequested
            )

            var score = 0
            var explicitMatchScore = 0

            if analysis.normalizedText.contains(normalizedTitle) {
                score += 90
                explicitMatchScore += 70
            }

            let exactTitleOverlap = analysis.expandedTokens.intersection(titleExpandedTokens)
            score += exactTitleOverlap.count * 18
            explicitMatchScore += exactTitleOverlap.count * 14

            let exactAliasOverlap = analysis.expandedTokens.intersection(aliasExpandedTokens)
            score += exactAliasOverlap.count * 12
            explicitMatchScore += exactAliasOverlap.count * 8

            let titlePhraseOverlap = analysis.phrases.intersection(titlePhrases)
            score += titlePhraseOverlap.count * 24
            explicitMatchScore += titlePhraseOverlap.count * 18

            let aliasPhraseOverlap = analysis.phrases.intersection(aliasPhrases)
            score += aliasPhraseOverlap.count * 18
            explicitMatchScore += aliasPhraseOverlap.count * 12

            // Completion verbs ("fed", "besle") are strong category evidence, but generic
            // verbs ("done", "finish") on .general tasks must not manufacture a match.
            if case .complete? = command,
               task.category != .general,
               analysis.expandedTokens.isDisjoint(with: verbAliasExpandedTokens) == false {
                score += 24
                explicitMatchScore += 16
            }

            let titlePrefixMatches = prefixMatchCount(
                queryTokens: analysis.significantTokens,
                targetTokens: titleTokens,
                excluding: exactTitleOverlap
            )
            score += titlePrefixMatches * 12
            explicitMatchScore += titlePrefixMatches * 9

            let aliasPrefixMatches = prefixMatchCount(
                queryTokens: analysis.significantTokens,
                targetTokens: aliasTokens,
                excluding: exactAliasOverlap
            )
            score += aliasPrefixMatches * 7
            explicitMatchScore += aliasPrefixMatches * 5

            if !selectedCats.isEmpty {
                let catMatchScore = selectedCats.count == task.assignedCats.count ? 22 : 16
                score += catMatchScore
                explicitMatchScore += catMatchScore
            } else if !mentionedCatIDs.isEmpty {
                score -= 18
                explicitMatchScore -= 10
            }

            if let dueDate = task.activeDueDate {
                if task.isOverdue {
                    score += 16
                } else if Calendar.current.isDate(dueDate, inSameDayAs: referenceDate) {
                    score += 10
                } else if let twoDaysAhead = Calendar.current.date(byAdding: .day, value: 2, to: referenceDate),
                          dueDate <= twoDaysAhead {
                    score += 4
                }
            }

            return RankedTask(
                task: task,
                score: score,
                explicitMatchScore: explicitMatchScore,
                selectedCats: selectedCats
            )
        }
        .sorted { first, second in
            if first.score == second.score {
                if first.explicitMatchScore == second.explicitMatchScore {
                    return first.task.updatedAt > second.task.updatedAt
                }
                return first.explicitMatchScore > second.explicitMatchScore
            }
            return first.score > second.score
        }
    }

    private func supports(_ command: Command, for task: CareTask) -> Bool {
        switch command {
        case .complete:
            return task.status != .completed || task.isRecurring
        case .postpone:
            return task.status != .completed || task.isRecurring
        case .open:
            return true
        }
    }

    /// Only the postpone/open aliases — returns `nil` (instead of defaulting to `.complete`)
    /// when the text carries no explicit command keyword at all.
    private func detectExplicitCommand(in analysis: QueryAnalysis) -> Command? {
        let normalizedText = analysis.normalizedText

        if matchesAlias(in: analysis, aliases: postponeAliases) || containsAny(normalizedText, phrases: postponeAliases) {
            return .postpone(minutes: detectDuration(in: normalizedText) ?? 30)
        }

        if matchesAlias(in: analysis, aliases: openAliases) || containsAny(normalizedText, phrases: openAliases) {
            return .open
        }

        return nil
    }

    /// Whether the text contains a completion verb ("fed", "done", "cleaned", …) tied to any
    /// candidate task's category — evidence the user meant `.complete` even without an
    /// explicit open/postpone keyword.
    private func hasCompletionVerbEvidence(in analysis: QueryAnalysis, tasks: [CareTask]) -> Bool {
        let categories = Set(tasks.map(\.category)).subtracting([.general])

        return categories.contains { category in
            let verbTokens = taskVerbAliases(for: category).flatMap(tokenize)
            let expandedVerbTokens = expand(tokens: verbTokens, language: analysis.dominantLanguage)
            return analysis.expandedTokens.isDisjoint(with: expandedVerbTokens) == false
        }
    }

    private func detectDuration(in normalizedText: String) -> Int? {
        let minutePatterns = [
            "(\\d+)\\s*(min|mins|minute|minutes|dk|dakika)",
            "(\\d+)\\s*(hr|hrs|hour|hours|saat)"
        ]

        for pattern in minutePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(normalizedText.startIndex..<normalizedText.endIndex, in: normalizedText)

            guard let match = regex.firstMatch(in: normalizedText, range: range),
                  let valueRange = Range(match.range(at: 1), in: normalizedText),
                  let value = Int(normalizedText[valueRange]) else {
                continue
            }

            if pattern.contains("hour") || pattern.contains("saat") || pattern.contains("hr") {
                return value * 60
            }

            return value
        }

        return nil
    }

    private func detectCompletionDate(in analysis: QueryAnalysis, referenceDate: Date) -> Date? {
        let calendar = Calendar.current
        let normalizedText = analysis.normalizedText

        if containsAny(normalizedText, phrases: ["yesterday", "dun", "dün"]) {
            return calendar.date(byAdding: .day, value: -1, to: referenceDate)
        }

        if containsAny(
            normalizedText,
            phrases: ["today", "tonight", "this morning", "this evening", "bugun", "bugün", "bu sabah", "bu aksam", "bu akşam"]
        ) {
            return referenceDate
        }

        return nil
    }

    private func notes(in text: String) -> String? {
        let separators = ["note:", "notes:", "because", "çünkü", "not:"]

        for separator in separators {
            if let range = text.range(of: separator, options: [.caseInsensitive, .diacriticInsensitive]) {
                let note = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                return note.isEmpty ? nil : note
            }
        }

        return nil
    }

    private func selectedCats(
        for task: CareTask,
        mentionedCatIDs: Set<UUID>,
        allCatsRequested: Bool
    ) -> [Cat] {
        guard !task.assignedCats.isEmpty else { return [] }

        if allCatsRequested {
            return task.assignedCats
        }

        return task.assignedCats.filter { cat in
            mentionedCatIDs.contains(cat.id)
        }
    }

    private func mentionedCatIDs(in analysis: QueryAnalysis, tasks: [CareTask]) -> Set<UUID> {
        let allCats = tasks
            .flatMap(\.assignedCats)
            .reduce(into: [UUID: Cat]()) { result, cat in
                result[cat.id] = cat
            }
            .values

        return Set(allCats.compactMap { cat in
            matches(cat: cat, in: analysis) ? cat.id : nil
        })
    }

    private func matches(cat: Cat, in analysis: QueryAnalysis) -> Bool {
        let normalizedName = normalize(cat.name)
        if analysis.normalizedText.contains(normalizedName) {
            return true
        }

        let nameTokens = tokenize(cat.name).filter { isSignificantToken($0, language: analysis.dominantLanguage) }
        guard !nameTokens.isEmpty else { return false }

        let nameTokenSet = expand(tokens: nameTokens, language: analysis.dominantLanguage)
        if !analysis.expandedTokens.intersection(nameTokenSet).isEmpty {
            return true
        }

        return nameTokens.allSatisfy { nameToken in
            analysis.significantTokens.contains { queryToken in
                tokensSharePrefix(queryToken, nameToken)
            }
        }
    }

    private func requestsAllCats(in analysis: QueryAnalysis) -> Bool {
        containsAny(
            analysis.normalizedText,
            phrases: ["all cats", "every cat", "tum kediler", "tüm kediler", "hepsi", "all of them"]
        )
    }

    private func minimumClarificationScore(for command: Command) -> Int {
        switch command {
        case .open:
            return 18
        case .complete, .postpone:
            return 22
        }
    }

    private func minimumClarificationExplicitScore(for command: Command) -> Int {
        switch command {
        case .open:
            return 8
        case .complete, .postpone:
            return 10
        }
    }

    private func minimumConfirmationScore(for command: Command) -> Int {
        switch command {
        case .open:
            return 40
        case .postpone:
            return 40
        case .complete:
            return 44
        }
    }

    private func minimumConfirmationExplicitScore(for command: Command) -> Int {
        switch command {
        case .open:
            return 18
        case .complete, .postpone:
            return 22
        }
    }

    private func minimumScoreGap(for command: Command) -> Int {
        switch command {
        case .open:
            return 8
        case .complete, .postpone:
            return 10
        }
    }

    private func minimumExplicitGap(for command: Command) -> Int {
        switch command {
        case .open:
            return 4
        case .complete, .postpone:
            return 6
        }
    }

    private func isEligibleMatch(_ candidate: RankedTask, for command: Command) -> Bool {
        candidate.explicitMatchScore >= minimumClarificationExplicitScore(for: command)
            && candidate.score >= minimumClarificationScore(for: command)
    }

    private func isHighConfidenceMatch(_ candidate: RankedTask, for command: Command) -> Bool {
        candidate.explicitMatchScore >= minimumConfirmationExplicitScore(for: command)
            && candidate.score >= minimumConfirmationScore(for: command)
    }

    private func shouldClarify(
        _ candidates: [RankedTask],
        bestCandidate: RankedTask,
        for command: Command
    ) -> Bool {
        guard candidates.count > 1 else { return false }
        guard let secondCandidate = candidates.dropFirst().first else { return false }

        if bestCandidate.score < minimumConfirmationScore(for: command) {
            return true
        }

        let scoreGap = bestCandidate.score - secondCandidate.score
        let explicitGap = bestCandidate.explicitMatchScore - secondCandidate.explicitMatchScore

        return scoreGap < minimumScoreGap(for: command) || explicitGap < minimumExplicitGap(for: command)
    }

    private func confirmationTitle(for command: Command) -> String {
        TaskAssistantResponseFormatting.confirmationTitle(for: command.kind)
    }

    private func clarificationMessage(for command: Command) -> String {
        TaskAssistantResponseFormatting.clarificationMessage(for: command.kind)
    }

    private func confirmationMessage(for action: TaskAssistantAction) -> String {
        TaskAssistantResponseFormatting.confirmationMessage(for: action)
    }

    private func dominantLanguage(in text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let dominantLanguage = recognizer.dominantLanguage,
           dominantLanguage == .turkish || dominantLanguage == .english {
            return dominantLanguage
        }

        return .english
    }

    private func tokenize(_ text: String) -> [String] {
        let normalizedText = normalize(text)
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = normalizedText

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: normalizedText.startIndex..<normalizedText.endIndex) { range, _ in
            let token = normalizedText[range].trimmingCharacters(in: .punctuationCharacters)
            if !token.isEmpty {
                tokens.append(String(token))
            }
            return true
        }

        return tokens
    }

    private func normalize(_ text: String) -> String {
        let mappedText = text
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "Ş", with: "s")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "Ğ", with: "g")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "Ü", with: "u")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "Ö", with: "o")
            .replacingOccurrences(of: "ç", with: "c")
            .replacingOccurrences(of: "Ç", with: "c")

        let loweredText = mappedText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()

        return loweredText
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isSignificantToken(_ token: String, language: NLLanguage) -> Bool {
        guard token.count > 1 else { return false }
        guard Int(token) == nil else { return false }
        return !helperWords(for: language).contains(token)
    }

    private func helperWords(for language: NLLanguage) -> Set<String> {
        let commonWords: Set<String> = [
            "the", "a", "an", "please", "me", "my", "for", "to", "with", "and", "it",
            "i", "we", "you", "this", "that", "these", "those", "just", "about", "of",
            "bir", "bu", "beni", "bana", "icin", "ile", "ve", "da",
            "de", "mi", "mu", "ben", "biz", "sen", "siz", "onu", "bunu"
        ]

        let englishWords: Set<String> = [
            "can", "could", "would", "should", "is", "are", "was", "were", "be", "been",
            "do", "did", "does", "done", "mark", "task", "tasks", "their",
            "them", "all", "again", "later", "today", "yesterday"
        ]

        let turkishWords: Set<String> = [
            "gorev", "tamam", "olarak", "sonra", "bugun",
            "dun", "icin", "tum", "hepsi", "olan", "olanlari"
        ]

        switch language {
        case .turkish:
            return commonWords.union(turkishWords)
        default:
            return commonWords.union(englishWords)
        }
    }

    private func expand(tokens: [String], language: NLLanguage) -> Set<String> {
        Set(tokens.flatMap { token in
            tokenVariants(for: token, language: language)
        })
    }

    private func tokenVariants(for token: String, language: NLLanguage) -> Set<String> {
        guard token.count > 2 else { return [token] }

        var variants: Set<String> = [token]

        if let baseForm = englishIrregularBaseForms[token] {
            variants.insert(baseForm)
        }

        let suffixes = language == .turkish ? turkishSuffixes : englishSuffixes

        for suffix in suffixes where token.hasSuffix(suffix) && token.count - suffix.count >= 3 {
            let stripped = String(token.dropLast(suffix.count))
            variants.insert(stripped)
        }

        return variants
    }

    private func phrases(from tokens: [String]) -> Set<String> {
        guard tokens.count >= 2 else { return [] }

        var result: Set<String> = []

        for size in 2...min(3, tokens.count) {
            for startIndex in 0...(tokens.count - size) {
                let phrase = tokens[startIndex..<(startIndex + size)].joined(separator: " ")
                result.insert(phrase)
            }
        }

        return result
    }

    private func prefixMatchCount(
        queryTokens: [String],
        targetTokens: [String],
        excluding exactMatches: Set<String>
    ) -> Int {
        let excludedTokens = Set(exactMatches)

        return queryTokens.reduce(into: 0) { count, queryToken in
            guard excludedTokens.contains(queryToken) == false else { return }

            if targetTokens.contains(where: { targetToken in
                excludedTokens.contains(targetToken) == false && tokensSharePrefix(queryToken, targetToken)
            }) {
                count += 1
            }
        }
    }

    private func tokensSharePrefix(_ lhs: String, _ rhs: String) -> Bool {
        guard lhs != rhs else { return false }
        guard min(lhs.count, rhs.count) >= 3 else { return false }

        return lhs.hasPrefix(rhs) || rhs.hasPrefix(lhs)
    }

    private func matchesAlias(in analysis: QueryAnalysis, aliases: [String]) -> Bool {
        let aliasTokens = Set(aliases.flatMap(tokenize))
        return analysis.expandedTokens.isDisjoint(with: aliasTokens) == false
    }

    private func taskAliases(for task: CareTask) -> [String] {
        categoryAliases(for: task.category) + taskVerbAliases(for: task.category)
    }

    private func categoryAliases(for category: CareTaskCategory) -> [String] {
        switch category {
        case .feeding:
            return ["feed", "feeding", "food", "meal", "mama", "besle", "beslenme", "yemek"]
        case .water:
            return ["water", "fresh water", "su", "water bowl", "su kabi", "drink"]
        case .medication:
            return ["medication", "medicine", "med", "pill", "ilac", "hap", "tedavi"]
        case .grooming:
            return ["groom", "brush", "comb", "bakim", "tara", "fircala", "fircala"]
        case .health:
            return ["health", "check", "monitor", "saglik", "kontrol", "muayene"]
        case .exercise:
            return ["play", "exercise", "toy", "oyun", "egzersiz", "hareket"]
        case .litter:
            return ["litter", "litter box", "tray", "box", "kum", "kum kabi", "tuvalet"]
        case .vet:
            return ["vet", "veterinarian", "appointment", "veteriner", "randevu", "doktor"]
        case .general:
            return ["task", "care", "bakim", "general", "genel"]
        }
    }

    private func taskVerbAliases(for category: CareTaskCategory) -> [String] {
        switch category {
        case .feeding:
            return ["fed", "serve", "gave food", "besle", "yedir", "doyur", "ver", "verdim"]
        case .water:
            return ["fill", "refill", "freshen", "wash", "rinse", "clean", "tazele", "yika", "yikadim"]
        case .medication:
            return ["give medicine", "administer", "dose", "ilac ver", "uygula", "verdim"]
        case .grooming:
            return ["brush", "comb", "clean", "tara", "taradim", "temizle"]
        case .health:
            return ["check", "inspect", "monitor", "kontrol et", "gozlemle", "baktim"]
        case .exercise:
            return ["play", "exercise", "move", "oyna", "oynadim", "kostur"]
        case .litter:
            return ["clean", "change", "replace", "scoop", "temizle", "degis", "degistir", "degistirdim"]
        case .vet:
            return ["visit", "book", "schedule", "git", "ayarla", "planla"]
        case .general:
            return ["complete", "done", "finish", "tamamla", "bitir", "yaptim"]
        }
    }

    private func containsAny(_ text: String, phrases: [String]) -> Bool {
        phrases.contains { phrase in
            text.contains(normalize(phrase))
        }
    }

    private let englishIrregularBaseForms: [String: String] = [
        "fed": "feed",
        "gave": "give",
        "ate": "eat",
        "drank": "drink",
        "took": "take"
    ]
    private let postponeAliases = ["remind", "snooze", "postpone", "later", "hatirlat", "hatırlat", "ertele", "sonra"]
    private let openAliases = ["open", "show", "view", "details", "detail", "ac", "aç", "goster", "göster", "incele"]
    private let englishSuffixes = ["ing", "ed", "es", "s", "d"]
    private let turkishSuffixes = [
        "lerini", "larini", "lerden", "lardan", "lerin", "larin", "leri", "lari",
        "lere", "lara", "ler", "lar", "unu", "ini", "ni", "nu", "de", "da", "te", "ta",
        "dim", "dum", "tim", "tum", "dir", "tir", "di", "du", "ti", "tu", "mis", "mus", "yor"
    ]
}
