import Foundation
import SwiftData
import UIKit

@MainActor
@Observable
final class TaskAssistantViewModel {
    enum Outcome {
        case none
        case openTask(UUID)
    }

    var draftText: String = ""
    var messages: [TaskAssistantMessage]
    var pendingConfirmation: TaskAssistantConfirmation?
    var pendingClarification: TaskAssistantClarification?
    var pendingTaskDisambiguation: TaskAssistantTaskDisambiguation?
    var pendingIntentSelection: TaskAssistantIntentSelection?
    var taskCompletionRequest: TaskAssistantCompletionRequest?
    /// Active conversational "create a task" flow, or nil when not creating. Single-slot and
    /// mutually exclusive with the pending confirm/clarify cards.
    var taskCreationSession: TaskCreationSession?
    var isProcessing: Bool = false
    var isRecording: Bool = false

    /// Bumped whenever the user takes an action that should bring the chat to the bottom
    /// (sending a message, picking a clarification suggestion) so the view can scroll a
    /// scrolled-up user back down. The continuous "stick to the bottom" behavior is separate.
    private(set) var scrollToBottomToken = 0

    private let interpreter: TaskAssistantInterpreter
    private let cloudInterpreter: (any TaskAssistantCloudInterpreting)?
    private let taskWriter: any CareTaskWriting
    private let speechService: any SpeechRecognitionServicing
    private let userDefaults: UserDefaults
    private let photoWriter: CareTaskPhotoWriter
    private var isRequestingSpeechPermission = false

    init(
        interpreter: TaskAssistantInterpreter = TaskAssistantInterpreter(),
        cloudInterpreter: (any TaskAssistantCloudInterpreting)? = FirebaseTaskAssistantCloudInterpreter(),
        taskWriter: (any CareTaskWriting)? = nil,
        speechService: (any SpeechRecognitionServicing)? = nil,
        userDefaults: UserDefaults = .standard,
        photoWriter: CareTaskPhotoWriter = CareTaskPhotoWriter()
    ) {
        self.interpreter = interpreter
        self.cloudInterpreter = cloudInterpreter
        self.taskWriter = taskWriter ?? CareTaskWriter(scheduler: NotificationManager.shared)
        self.photoWriter = photoWriter
        self.speechService = speechService ?? SpeechRecognitionService()
        self.userDefaults = userDefaults
        self.messages = []
    }

    func sendCurrentDraft(tasks: [CareTask]) async {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // While a create flow is active, typed text feeds the flow instead of the interpreter.
        if taskCreationSession != nil {
            handleCreationTextInput(text)
            return
        }

        draftText = ""
        pendingConfirmation = nil
        pendingClarification = nil
        pendingTaskDisambiguation = nil
        pendingIntentSelection = nil
        messages.append(TaskAssistantMessage(role: .user, text: text))
        scrollToBottomToken += 1

        let heuristicResult = interpreter.interpret(text: text, tasks: tasks)
        let interpretation = await resolvedInterpretation(heuristicResult, text: text, tasks: tasks)
        apply(interpretation)
    }

    /// The heuristic interpreter runs first (instant, offline). Only when it can't
    /// resolve a match do we escalate to the cloud tier, and only its result is kept
    /// if that succeeds — any cloud failure silently keeps the heuristic's answer.
    private func resolvedInterpretation(
        _ heuristicResult: TaskAssistantInterpreter.Interpretation,
        text: String,
        tasks: [CareTask]
    ) async -> TaskAssistantInterpreter.Interpretation {
        guard
            case .assistantMessage = heuristicResult,
            let cloudInterpreter,
            SettingsPreferences.isTaskAssistantCloudConsentGranted(in: userDefaults)
        else {
            return heuristicResult
        }

        isProcessing = true
        defer { isProcessing = false }

        if let cloudResult = try? await cloudInterpreter.interpret(text: text, tasks: tasks, referenceDate: Date()) {
            return cloudResult
        }

        return heuristicResult
    }

    private func apply(_ interpretation: TaskAssistantInterpreter.Interpretation) {
        switch interpretation {
        case .confirmation(let confirmation):
            pendingConfirmation = confirmation
            messages.append(TaskAssistantMessage(role: .assistant, text: confirmation.message))

        case .clarification(let clarification):
            pendingClarification = clarification
            messages.append(TaskAssistantMessage(role: .assistant, text: clarification.message))

        case .taskDisambiguation(let disambiguation):
            pendingTaskDisambiguation = disambiguation
            messages.append(TaskAssistantMessage(role: .assistant, text: disambiguation.message))

        case .intentSelection(let selection):
            pendingIntentSelection = selection
            messages.append(
                TaskAssistantMessage(
                    role: .assistant,
                    text: String(localized: .taskAssistantIntentPrompt(selection.task.title))
                )
            )

        case .assistantMessage(let message):
            let isNoMatch = message == String(localized: .taskAssistantNoMatch)
            messages.append(TaskAssistantMessage(role: .assistant, text: message, style: isNoMatch ? .failure : .normal))
        }
    }

    func chooseSuggestion(_ suggestion: TaskAssistantSuggestion) {
        pendingClarification = nil
        let message = confirmationMessage(for: suggestion.action)
        pendingConfirmation = TaskAssistantConfirmation(
            title: suggestion.title,
            message: message,
            action: suggestion.action
        )
        messages.append(TaskAssistantMessage(role: .assistant, text: message))
        scrollToBottomToken += 1
    }

    /// The user picked a task out of a `pendingTaskDisambiguation` list — settle on that task
    /// and ask what to do with it next.
    func chooseTaskChoice(_ choice: TaskAssistantTaskChoice) {
        guard let disambiguation = pendingTaskDisambiguation else { return }
        pendingTaskDisambiguation = nil

        let selection = TaskAssistantIntentSelection(
            task: choice.task,
            selectedCats: choice.selectedCats,
            completedForDate: disambiguation.completedForDate,
            notes: disambiguation.notes
        )
        pendingIntentSelection = selection
        messages.append(
            TaskAssistantMessage(
                role: .assistant,
                text: String(localized: .taskAssistantIntentPrompt(selection.task.title))
            )
        )
        scrollToBottomToken += 1
    }

    /// The user picked what to do with a `pendingIntentSelection` task — route into the same
    /// confirmation card every other action already goes through.
    func chooseIntent(_ intent: TaskAssistantIntentKind) {
        // The card only ever renders `selection.availableIntents`, but re-check here too —
        // status can change out from under a stale card (see `revalidatePendingActions`).
        guard let selection = pendingIntentSelection, selection.availableIntents.contains(intent) else { return }
        pendingIntentSelection = nil

        let action: TaskAssistantAction
        let commandKind: TaskAssistantCommandKind
        switch intent {
        case .open:
            action = .open(task: selection.task)
            commandKind = .open
        case .complete:
            action = .complete(
                task: selection.task,
                completedForDate: selection.completedForDate,
                notes: selection.notes,
                cats: selection.selectedCats
            )
            commandKind = .complete
        case .postpone:
            action = .postpone(task: selection.task, minutes: 30)
            commandKind = .postpone
        }

        let message = confirmationMessage(for: action)
        pendingConfirmation = TaskAssistantConfirmation(
            title: TaskAssistantResponseFormatting.confirmationTitle(for: commandKind),
            message: message,
            action: action
        )
        messages.append(TaskAssistantMessage(role: .assistant, text: message))
        scrollToBottomToken += 1
    }

    func endChat() {
        stopDictation()
        draftText = ""
        messages = []
        pendingConfirmation = nil
        pendingClarification = nil
        pendingTaskDisambiguation = nil
        pendingIntentSelection = nil
        taskCompletionRequest = nil
        taskCreationSession = nil
    }

    // MARK: - Create a task (conversational form)

    /// Starts the create flow. `cats` decides whether the `.cats` step is asked (skipped when
    /// the user has no cats — `TaskFormPersistence` allows an unassigned task).
    func beginTaskCreation(cats: [Cat]) {
        guard taskCreationSession == nil else { return }

        // Starting a create flow supersedes any pending confirm/clarify card.
        pendingConfirmation = nil
        pendingClarification = nil
        pendingTaskDisambiguation = nil
        pendingIntentSelection = nil

        var session = TaskCreationSession()
        session.catsAvailable = cats.isEmpty == false
        taskCreationSession = session

        appendCreationQuestion(String(localized: .taskAssistantCreateAskName))
    }

    /// Sets the task name from typed input and advances to the next step.
    func submitCreationName(_ text: String) {
        guard var session = taskCreationSession, session.step == .name else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        session.title = trimmed
        taskCreationSession = session
        advanceAfterName()
    }

    func toggleCreationCat(_ cat: Cat) {
        guard var session = taskCreationSession, session.step == .cats else { return }
        if let index = session.selectedCats.firstIndex(where: { $0.id == cat.id }) {
            session.selectedCats.remove(at: index)
        } else {
            session.selectedCats.append(cat)
        }
        taskCreationSession = session
    }

    /// Advances from the cat step using the currently toggled cats (requires at least one).
    func confirmCreationCats() {
        guard let session = taskCreationSession, session.step == .cats,
              session.selectedCats.isEmpty == false else { return }
        let names = session.selectedCats.map(\.name).joined(separator: ", ")
        moveToCategoryStep(echo: names)
    }

    /// Quick path: assigns every cat and advances.
    func selectAllCats(_ cats: [Cat]) {
        guard var session = taskCreationSession, session.step == .cats else { return }
        session.selectedCats = cats
        taskCreationSession = session
        moveToCategoryStep(echo: String(localized: .tasksConfigAllCats))
    }

    func selectCreationCategory(_ category: CareTaskCategory) {
        guard var session = taskCreationSession, session.step == .category else { return }
        session.category = category
        session.step = .repeatFrequency
        taskCreationSession = session
        messages.append(TaskAssistantMessage(role: .user, text: category.displayName))
        appendCreationQuestion(String(localized: .taskAssistantCreateAskRepeat))
    }

    func selectCreationFrequency(_ frequency: CareTaskFrequency) {
        guard var session = taskCreationSession, session.step == .repeatFrequency else { return }
        session.frequency = frequency
        session.step = .time
        taskCreationSession = session
        messages.append(TaskAssistantMessage(role: .user, text: frequency.displayName))
        appendCreationQuestion(String(localized: .taskAssistantCreateAskTime))
    }

    func selectCreationTime(_ option: TaskCreationTimeOption) {
        guard var session = taskCreationSession, session.step == .time else { return }
        if let hour = option.hour {
            session.scheduledTime = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
        } else {
            session.scheduledTime = nil
        }
        session.step = .confirm
        taskCreationSession = session
        messages.append(TaskAssistantMessage(role: .user, text: timeOptionLabel(option)))
        appendCreationQuestion(creationSummary(for: session))
    }

    func cancelTaskCreation() {
        guard taskCreationSession != nil else { return }
        // Drop the trailing assistant question, mirroring cancelPendingAction.
        if messages.last?.role == .assistant {
            messages.removeLast()
        }
        taskCreationSession = nil
    }

    func confirmTaskCreation(in context: ModelContext, existingCaregivers: [Caregiver]) async {
        guard let session = taskCreationSession, session.step == .confirm else { return }
        isProcessing = true
        defer { isProcessing = false }

        let draft = session.makeDraft()
        do {
            let task = try TaskFormPersistence.createTask(
                from: draft,
                in: context,
                existingCaregivers: existingCaregivers,
                defaultCaregiverName: String(localized: .tasksConfigMyself),
                defaultCaregiverLocalizationKey: CaregiverBootstrapper.defaultCaregiverLocalizationKey
            )
            // A failed schedule leaves the user with no reminders for a task they just asked to be
            // reminded about. The task itself stands, so the failure is reported into the chat and
            // the creation is still confirmed. Any other error means nothing was saved.
            do {
                try await taskWriter.save(task, in: context)
            } catch is CancellationError {
                // The write stands and the next resync rebuilds the reminders from the store, so
                // there is no user-facing failure to report here.
            } catch let error as CareTaskRemindersOutOfSyncError {
                print("❌ Failed to schedule notifications for '\(task.title)': \(error.underlyingError)")
                messages.append(TaskAssistantMessage(
                    role: .assistant,
                    text: String(localized: .taskAssistantScheduleFailed),
                    style: .failure
                ))
            }
            taskCreationSession = nil
            messages.append(TaskAssistantMessage(
                role: .assistant,
                text: String(localized: .taskAssistantCreateSuccess(task.title))
            ))
        } catch {
            messages.append(TaskAssistantMessage(role: .assistant, text: error.localizedDescription, style: .failure))
        }
        scrollToBottomToken += 1
    }

    private func handleCreationTextInput(_ text: String) {
        guard let session = taskCreationSession else { return }
        draftText = ""
        messages.append(TaskAssistantMessage(role: .user, text: text))
        scrollToBottomToken += 1

        guard session.step == .name else {
            // A chip-driven step — the user typed instead of tapping an option.
            appendCreationQuestion(String(localized: .taskAssistantCreatePickOption))
            return
        }

        submitCreationName(text)
    }

    private func advanceAfterName() {
        guard var session = taskCreationSession else { return }
        if session.catsAvailable {
            session.step = .cats
            taskCreationSession = session
            appendCreationQuestion(String(localized: .taskAssistantCreateAskCats))
        } else {
            session.step = .category
            taskCreationSession = session
            appendCreationQuestion(String(localized: .taskAssistantCreateAskCategory))
        }
    }

    private func moveToCategoryStep(echo: String) {
        guard var session = taskCreationSession else { return }
        session.step = .category
        taskCreationSession = session
        messages.append(TaskAssistantMessage(role: .user, text: echo))
        appendCreationQuestion(String(localized: .taskAssistantCreateAskCategory))
    }

    private func appendCreationQuestion(_ text: String) {
        messages.append(TaskAssistantMessage(role: .assistant, text: text))
        scrollToBottomToken += 1
    }

    private func timeOptionLabel(_ option: TaskCreationTimeOption) -> String {
        switch option {
        case .morning: return String(localized: .taskAssistantCreateTimeMorning)
        case .noon: return String(localized: .taskAssistantCreateTimeNoon)
        case .evening: return String(localized: .taskAssistantCreateTimeEvening)
        case .none: return String(localized: .taskAssistantCreateTimeNone)
        }
    }

    private func creationSummary(for session: TaskCreationSession) -> String {
        let cats = session.selectedCats.isEmpty
            ? String(localized: .taskAssistantCreateNoCat)
            : session.selectedCats.map(\.name).joined(separator: ", ")
        let timeText: String
        if let time = session.scheduledTime {
            timeText = time.formatted(date: .omitted, time: .shortened)
        } else {
            timeText = String(localized: .taskAssistantCreateTimeNone)
        }
        return String(localized: .taskAssistantCreateConfirmSummary(
            session.trimmedTitle,
            cats,
            session.category.displayName,
            session.frequency.displayName,
            timeText
        ))
    }

    func cancelPendingAction() {
        // The confirmation/clarification question was appended as the trailing assistant
        // message right when it was created — cancelling means it never gets a follow-up,
        // so drop it rather than leaving a stale question bubble in the chat.
        let hadPendingAction = pendingConfirmation != nil
            || pendingClarification != nil
            || pendingTaskDisambiguation != nil
            || pendingIntentSelection != nil
        if hadPendingAction, messages.last?.role == .assistant {
            messages.removeLast()
        }
        pendingConfirmation = nil
        pendingClarification = nil
        pendingTaskDisambiguation = nil
        pendingIntentSelection = nil
    }

    func revalidatePendingActions(against tasks: [CareTask]) {
        if let pendingConfirmation, isValid(pendingConfirmation.action, among: tasks) == false {
            cancelPendingAction()
        }

        if let pendingClarification {
            let validSuggestions = pendingClarification.suggestions.filter {
                isValid($0.action, among: tasks)
            }

            if validSuggestions.isEmpty {
                cancelPendingAction()
            } else if validSuggestions.count != pendingClarification.suggestions.count {
                self.pendingClarification = TaskAssistantClarification(
                    message: pendingClarification.message,
                    suggestions: validSuggestions
                )
            }
        }

        if let pendingTaskDisambiguation {
            let validChoices = pendingTaskDisambiguation.choices.filter { choice in
                tasks.contains { $0 === choice.task }
            }

            if validChoices.isEmpty {
                cancelPendingAction()
            } else if validChoices.count != pendingTaskDisambiguation.choices.count {
                self.pendingTaskDisambiguation = TaskAssistantTaskDisambiguation(
                    message: pendingTaskDisambiguation.message,
                    choices: validChoices,
                    completedForDate: pendingTaskDisambiguation.completedForDate,
                    notes: pendingTaskDisambiguation.notes
                )
            }
        }

        if let pendingIntentSelection,
           tasks.contains(where: { $0 === pendingIntentSelection.task }) == false {
            cancelPendingAction()
        }

        if let taskCompletionRequest,
           tasks.contains(where: { $0 === taskCompletionRequest.task }) == false {
            self.taskCompletionRequest = nil
        }
    }

    func confirmPendingAction(in context: ModelContext) async -> Outcome {
        guard let pendingConfirmation else { return .none }

        self.pendingConfirmation = nil
        pendingClarification = nil
        isProcessing = true
        defer { isProcessing = false }

        switch pendingConfirmation.action {
        case .complete(let task, let completedForDate, let notes, let cats):
            let selectedCats = cats.isEmpty ? task.assignedCats : cats

            if requiresDetailedCompletion(for: task, selectedCats: selectedCats) {
                taskCompletionRequest = TaskAssistantCompletionRequest(
                    task: task,
                    completedForDate: completedForDate,
                    initialNotes: notes,
                    initialSelectedCats: selectedCats
                )
                messages.append(
                    TaskAssistantMessage(
                        role: .assistant,
                        text: String(localized: .taskAssistantDetailedCompletion)
                    )
                )
                return .none
            }

            // A failure is already in the chat; this path has no sheet to keep open.
            try? await complete(
                task,
                with: CareTaskCompletionInput(cats: selectedCats, completedForDate: completedForDate, notes: notes),
                in: context
            )
            return .none

        case .postpone(let task, let minutes):
            do {
                try await taskWriter.snooze(task, minutes: minutes)
                messages.append(
                    TaskAssistantMessage(
                        role: .assistant,
                        text: String(localized: .taskAssistantPostponeSuccess(task.title, Int32(minutes)))
                    )
                )
            } catch {
                messages.append(
                    TaskAssistantMessage(
                        role: .assistant,
                        text: error.localizedDescription,
                        style: .failure
                    )
                )
            }

            return .none

        case .open(let task):
            messages.append(
                TaskAssistantMessage(
                    role: .assistant,
                    text: String(localized: .taskAssistantOpenSuccess(task.title))
                )
            )
            return .openTask(task.id)
        }
    }

    func completeDetailedTask(
        task: CareTask,
        selectedCats: [Cat],
        selectedCaregiver: Caregiver?,
        notes: String?,
        photos: [UIImage]?,
        completedForDate: Date?,
        in context: ModelContext
    ) async throws {
        isProcessing = true
        defer { isProcessing = false }

        // A photo that cannot be saved does not stop the completion: the chat reports it instead.
        var savedPhotos = CareTaskPhotoSaveResult()
        if let photos, photos.isEmpty == false {
            savedPhotos = await photoWriter.save(photos)
        }

        do {
            try await complete(
                task,
                with: CareTaskCompletionInput(
                    cats: selectedCats,
                    caregiver: selectedCaregiver,
                    completedForDate: completedForDate,
                    notes: notes,
                    photoURLs: savedPhotos.fileNames
                ),
                in: context
            )
        } catch {
            // `complete` throws only when nothing was committed, so no completion owns these files.
            await photoWriter.delete(savedPhotos.fileNames)
            throw error
        }
        if savedPhotos.failures.isEmpty == false {
            messages.append(
                TaskAssistantMessage(
                    role: .assistant,
                    text: String(localized: .taskAssistantPhotosNotSaved(Int32(savedPhotos.failures.count))),
                    style: .failure
                )
            )
        }
        taskCompletionRequest = nil
    }

    /// Completes `task` through the writer and reports the outcome into the chat.
    ///
    /// A committed completion returns normally, including when only its reminders failed. A committed
    /// completion must not look unsuccessful, or the user retries and records it twice, so a reminder
    /// failure is reported after the success message rather than instead of it.
    ///
    /// - Throws: the error when nothing was saved, after the failure message is in the chat.
    private func complete(
        _ task: CareTask,
        with input: CareTaskCompletionInput,
        in context: ModelContext
    ) async throws {
        let taskTitle = task.title
        var hasStaleReminders = false
        do {
            try await taskWriter.complete(task, with: input, in: context)
        } catch is CancellationError {
            // The completion stands and the next resync rebuilds the reminders from the store.
        } catch let error as CareTaskRemindersOutOfSyncError {
            print("❌ Failed to update reminders after completing '\(taskTitle)': \(error.underlyingError)")
            hasStaleReminders = true
        } catch {
            messages.append(
                TaskAssistantMessage(
                    role: .assistant,
                    text: error.localizedDescription,
                    style: .failure
                )
            )
            throw error
        }

        messages.append(
            TaskAssistantMessage(
                role: .assistant,
                text: String(localized: .taskAssistantCompleteSuccess(taskTitle))
            )
        )
        if hasStaleReminders {
            messages.append(
                TaskAssistantMessage(
                    role: .assistant,
                    text: String(localized: .taskAssistantScheduleFailed),
                    style: .failure
                )
            )
        }
    }

    func startDictation() async {
        guard !isRecording, !isRequestingSpeechPermission else { return }

        isRequestingSpeechPermission = true
        let granted = await speechService.requestPermissions()
        isRequestingSpeechPermission = false

        guard !Task.isCancelled else { return }
        guard granted else {
            messages.append(TaskAssistantMessage(
                role: .assistant,
                text: String(localized: .taskAssistantVoicePermissionDenied)
            ))
            return
        }

        do {
            try speechService.startRecording { [weak self] text, isFinal in
                guard let self else { return }
                draftText = text
                if isFinal {
                    isRecording = false
                }
            } onFailure: { [weak self] in
                // `stopRecording()` cancels the recognition task, and the cancellation comes
                // back through this same callback one hop later. Without the `isRecording`
                // check, a deliberate stop (or `endChat`/`onDisappear`) posts a "voice
                // unavailable" bubble for a failure the user never hit.
                guard let self, isRecording else { return }
                handleDictationFailure()
            }
            isRecording = true
        } catch {
            handleDictationFailure()
        }
    }

    func stopDictation() {
        guard isRecording else { return }
        speechService.stopRecording()
        isRecording = false
    }

    private func handleDictationFailure() {
        speechService.stopRecording()
        isRecording = false
        messages.append(TaskAssistantMessage(
            role: .assistant,
            text: String(localized: .taskAssistantVoiceUnavailable)
        ))
    }

    private func requiresDetailedCompletion(for task: CareTask, selectedCats: [Cat]) -> Bool {
        if task.assignedCats.count > 1 && selectedCats.isEmpty {
            return true
        }

        return false
    }

    private func confirmationMessage(for action: TaskAssistantAction) -> String {
        TaskAssistantResponseFormatting.confirmationMessage(for: action)
    }

    private func isValid(_ action: TaskAssistantAction, among tasks: [CareTask]) -> Bool {
        guard let currentTask = tasks.first(where: { $0 === action.task }) else {
            return false
        }

        switch action {
        case .complete, .postpone:
            return currentTask.status != .completed && currentTask.status != .cancelled
        case .open:
            return true
        }
    }
}
