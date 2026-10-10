import Foundation
import SwiftData
import Testing
import UIKit
@testable import CatCareCalendar

@MainActor
struct TaskAssistantViewModelTests {
    @Test
    func endChatClearsMessagesDraftAndPendingState() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.draftText = "Feed Luna"
        sut.messages.append(TaskAssistantMessage(role: .user, text: "Feed Luna"))
        sut.pendingConfirmation = TaskAssistantConfirmation(
            title: fixture.task.title,
            message: "Open task?",
            action: .open(task: fixture.task)
        )
        sut.pendingClarification = TaskAssistantClarification(message: "Which task?", suggestions: [])
        sut.pendingTaskDisambiguation = TaskAssistantTaskDisambiguation(
            message: "Which task?",
            choices: [TaskAssistantTaskChoice(task: fixture.task, selectedCats: [])],
            completedForDate: nil,
            notes: nil
        )
        sut.pendingIntentSelection = TaskAssistantIntentSelection(
            task: fixture.task,
            selectedCats: [],
            completedForDate: nil,
            notes: nil
        )
        sut.taskCompletionRequest = TaskAssistantCompletionRequest(
            task: fixture.task,
            completedForDate: nil,
            initialNotes: nil,
            initialSelectedCats: []
        )

        sut.endChat()

        #expect(sut.draftText == "")
        #expect(sut.messages.isEmpty)
        #expect(sut.pendingConfirmation == nil)
        #expect(sut.pendingClarification == nil)
        #expect(sut.pendingTaskDisambiguation == nil)
        #expect(sut.pendingIntentSelection == nil)
        #expect(sut.taskCompletionRequest == nil)
    }

    @Test
    func sendCurrentDraftCreatesPendingOpenConfirmationAndClearsDraft() async throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.draftText = "open Luna feeding details"

        await sut.sendCurrentDraft(tasks: [fixture.task])

        let confirmation = try #require(sut.pendingConfirmation)
        #expect(sut.draftText == "")
        #expect(sut.pendingClarification == nil)
        #expect(sut.messages.map(\.role) == [.user, .assistant])

        guard case .open(let task) = confirmation.action else {
            Issue.record("Expected an open action.")
            return
        }

        #expect(task.id == fixture.task.id)
    }

    @Test
    func confirmingOpenActionReturnsTaskOutcomeAndClearsPendingConfirmation() async throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.draftText = "open Luna feeding details"
        await sut.sendCurrentDraft(tasks: [fixture.task])

        let outcome = await sut.confirmPendingAction(in: fixture.container.mainContext)

        guard case .openTask(let taskID) = outcome else {
            Issue.record("Expected open-task outcome.")
            return
        }

        #expect(taskID == fixture.task.id)
        #expect(sut.pendingConfirmation == nil)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantOpenSuccess(fixture.task.title)))
    }

    @Test
    func cloudInterpreterIsNotConsultedWhenHeuristicAlreadyMatches() async throws {
        let fixture = try makeFixture()
        let cloudInterpreter = FakeTaskAssistantCloudInterpreter()
        let sut = TaskAssistantViewModel(
            cloudInterpreter: cloudInterpreter,
            userDefaults: freshUserDefaults(cloudConsentGranted: true)
        )
        sut.draftText = "open Luna feeding details"

        await sut.sendCurrentDraft(tasks: [fixture.task])

        #expect(cloudInterpreter.callCount == 0)
        #expect(sut.pendingConfirmation != nil)
    }

    @Test
    func cloudInterpreterIsNotConsultedWithoutConsent() async throws {
        let fixture = try makeFixture()
        let cloudInterpreter = FakeTaskAssistantCloudInterpreter()
        cloudInterpreter.result = .success(.confirmation(
            TaskAssistantConfirmation(title: "Open task", message: "Open Feed Luna?", action: .open(task: fixture.task))
        ))
        let sut = TaskAssistantViewModel(
            cloudInterpreter: cloudInterpreter,
            userDefaults: freshUserDefaults(cloudConsentGranted: false)
        )
        sut.draftText = "this phrase matches nothing heuristically"

        await sut.sendCurrentDraft(tasks: [fixture.task])

        #expect(cloudInterpreter.callCount == 0)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantNoMatch))
        #expect(sut.messages.last?.style == .failure)
    }

    @Test
    func cloudInterpreterRescuesHeuristicNoMatch() async throws {
        let fixture = try makeFixture()
        let cloudInterpreter = FakeTaskAssistantCloudInterpreter()
        cloudInterpreter.result = .success(
            .confirmation(
                TaskAssistantConfirmation(
                    title: "Open task",
                    message: "Open Feed Luna?",
                    action: .open(task: fixture.task)
                )
            )
        )
        let sut = TaskAssistantViewModel(
            cloudInterpreter: cloudInterpreter,
            userDefaults: freshUserDefaults(cloudConsentGranted: true)
        )
        sut.draftText = "this phrase matches nothing heuristically"

        await sut.sendCurrentDraft(tasks: [fixture.task])

        #expect(cloudInterpreter.callCount == 1)
        let confirmation = try #require(sut.pendingConfirmation)
        guard case .open(let task) = confirmation.action else {
            Issue.record("Expected an open action from the cloud tier.")
            return
        }
        #expect(task.id == fixture.task.id)
    }

    @Test
    func cloudInterpreterFailureFallsBackToHeuristicNoMatchMessage() async throws {
        let fixture = try makeFixture()
        let cloudInterpreter = FakeTaskAssistantCloudInterpreter()
        cloudInterpreter.result = .failure(FakeTaskAssistantCloudInterpreter.StubError.forcedFailure)
        let sut = TaskAssistantViewModel(
            cloudInterpreter: cloudInterpreter,
            userDefaults: freshUserDefaults(cloudConsentGranted: true)
        )
        sut.draftText = "this phrase matches nothing heuristically"

        await sut.sendCurrentDraft(tasks: [fixture.task])

        #expect(cloudInterpreter.callCount == 1)
        #expect(sut.pendingConfirmation == nil)
        #expect(sut.pendingClarification == nil)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantNoMatch))
        #expect(sut.messages.last?.style == .failure)
    }

    @Test
    func forcedCompletionErrorTagsMessageAsFailure() async throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.pendingConfirmation = TaskAssistantConfirmation(
            title: fixture.task.title,
            message: "Complete?",
            action: .complete(task: fixture.task, completedForDate: nil, notes: nil, cats: [])
        )

        let outcome = await sut.confirmPendingAction(in: fixture.container.mainContext)

        guard case .none = outcome else {
            Issue.record("Expected no outcome for a failed completion.")
            return
        }
        #expect(sut.pendingConfirmation == nil)
        #expect(sut.messages.last?.style == .failure)
        #expect(sut.messages.last?.text == TaskActionError.caregiverUnavailable.localizedDescription)
    }

    /// With notifications off, the snooze cannot be scheduled. The chat says so in the caregiver's
    /// language and offers the way to fix it: the app's page in the Settings app.
    @Test
    func postponeWithNotificationsOffReportsLocalizedFailureThatOffersSettings() async throws {
        let fixture = try makeFixture()
        let spy = NotificationSchedulerSpy()
        spy.snoozeError = NotificationSchedulingError.unauthorized
        let sut = TaskAssistantViewModel(taskWriter: CareTaskWriter(scheduler: spy))
        sut.pendingConfirmation = TaskAssistantConfirmation(
            title: fixture.task.title,
            message: "Postpone?",
            action: .postpone(task: fixture.task, minutes: 30)
        )

        _ = await sut.confirmPendingAction(in: fixture.container.mainContext)

        let message = try #require(sut.messages.last)
        #expect(message.style == .failure)
        #expect(message.text == String(localized: .errorNotificationSchedulingUnauthorized))
        #expect(message.offersOpenSettings)
    }

    /// Settings cannot fix any other snooze failure, so its bubble offers no button.
    @Test
    func postponeWithOtherFailureDoesNotOfferSettings() async throws {
        let fixture = try makeFixture()
        let spy = NotificationSchedulerSpy()
        spy.snoozeError = NotificationSchedulerSpy.StubError.forcedFailure
        let sut = TaskAssistantViewModel(taskWriter: CareTaskWriter(scheduler: spy))
        sut.pendingConfirmation = TaskAssistantConfirmation(
            title: fixture.task.title,
            message: "Postpone?",
            action: .postpone(task: fixture.task, minutes: 30)
        )

        _ = await sut.confirmPendingAction(in: fixture.container.mainContext)

        let message = try #require(sut.messages.last)
        #expect(message.style == .failure)
        #expect(message.offersOpenSettings == false)
    }

    /// The completion sheet stays open on a failed save, so the request must survive and the sheet
    /// must learn that nothing was saved.
    @Test
    func failedDetailedCompletionKeepsTheRequestAndReportsTheFailure() async throws {
        let fixture = try makeFixture()
        let context = fixture.container.mainContext
        let sut = TaskAssistantViewModel()
        sut.taskCompletionRequest = TaskAssistantCompletionRequest(
            task: fixture.task,
            completedForDate: nil,
            initialNotes: nil,
            initialSelectedCats: []
        )

        // No caregiver exists and none is chosen, so the completion cannot be recorded.
        await #expect(throws: TaskActionError.caregiverUnavailable) {
            try await sut.completeDetailedTask(
                task: fixture.task,
                selectedCats: [],
                selectedCaregiver: nil,
                notes: "Ate half",
                photos: nil,
                completedForDate: nil,
                in: context
            )
        }

        #expect(sut.taskCompletionRequest?.task === fixture.task)
        #expect(fixture.task.completions.isEmpty)
        #expect(sut.messages.last?.style == .failure)
        #expect(sut.isProcessing == false)
    }

    /// A committed completion must not read as a failure, or the user completes it twice. The
    /// reminder failure follows the success message instead of replacing it.
    @Test
    func completionWithStaleRemindersConfirmsSuccessThenReportsTheReminderFailure() async throws {
        let fixture = try makeFixture()
        let context = fixture.container.mainContext
        let caregiver = Caregiver(name: "Primary", role: .primary)
        context.insert(caregiver)
        try context.save()
        let spy = NotificationSchedulerSpy()
        spy.resyncError = .forcedFailure
        let sut = TaskAssistantViewModel(taskWriter: CareTaskWriter(scheduler: spy))
        sut.taskCompletionRequest = TaskAssistantCompletionRequest(
            task: fixture.task,
            completedForDate: nil,
            initialNotes: nil,
            initialSelectedCats: []
        )

        try await sut.completeDetailedTask(
            task: fixture.task,
            selectedCats: [],
            selectedCaregiver: caregiver,
            notes: nil,
            photos: nil,
            completedForDate: nil,
            in: context
        )

        #expect(fixture.task.completions.count == 1)
        #expect(sut.taskCompletionRequest == nil)
        #expect(sut.messages.suffix(2).map(\.text) == [
            String(localized: .taskAssistantCompleteSuccess(fixture.task.title)),
            String(localized: .taskAssistantScheduleFailed)
        ])
        #expect(sut.messages.last?.style == .failure)
    }

    /// A photo that cannot be saved does not stop the completion, and the chat says it was left out.
    @Test
    func unsavedPhotoIsReportedInTheChatAndTheCompletionStands() async throws {
        let fixture = try makeFixture()
        let context = fixture.container.mainContext
        let caregiver = Caregiver(name: "Primary", role: .primary)
        context.insert(caregiver)
        try context.save()
        let folder = try CareTaskPhotoFolder(blocked: true)
        defer { folder.remove() }
        let sut = TaskAssistantViewModel(
            taskWriter: CareTaskWriter(scheduler: NotificationSchedulerSpy()),
            photoWriter: folder.sut
        )

        try await sut.completeDetailedTask(
            task: fixture.task,
            selectedCats: [],
            selectedCaregiver: caregiver,
            notes: nil,
            photos: [try CareTaskPhotoFolder.makeImage()],
            completedForDate: nil,
            in: context
        )

        let completion = try #require(fixture.task.completions.first)
        #expect(completion.photoURLs.isEmpty)
        #expect(folder.log.messages.count == 1)
        #expect(sut.messages.suffix(2).map(\.text) == [
            String(localized: .taskAssistantCompleteSuccess(fixture.task.title)),
            String(localized: .taskAssistantPhotosNotSaved(1))
        ])
        #expect(sut.messages.last?.style == .failure)
    }

    @Test
    func failedDetailedCompletionLeavesNoNewPhotoFile() async throws {
        let fixture = try makeFixture()
        let folder = try CareTaskPhotoFolder()
        defer { folder.remove() }
        let sut = TaskAssistantViewModel(photoWriter: folder.sut)

        // No caregiver exists and none is chosen, so the completion cannot be recorded.
        await #expect(throws: TaskActionError.caregiverUnavailable) {
            try await sut.completeDetailedTask(
                task: fixture.task,
                selectedCats: [],
                selectedCaregiver: nil,
                notes: nil,
                photos: [try CareTaskPhotoFolder.makeImage()],
                completedForDate: nil,
                in: fixture.container.mainContext
            )
        }

        #expect(fixture.task.completions.isEmpty)
        #expect(try folder.storedFileNames().isEmpty)
    }

    @Test
    func cancellingPendingConfirmationRemovesTheQuestionItAnswered() async throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.draftText = "open Luna feeding details"
        await sut.sendCurrentDraft(tasks: [fixture.task])
        let messageCountBeforeCancel = sut.messages.count

        sut.cancelPendingAction()

        #expect(sut.pendingConfirmation == nil)
        #expect(sut.messages.count == messageCountBeforeCancel - 1)
        #expect(sut.messages.last?.role == .user)
    }

    @Test
    func cancellingClarificationRemovesTheQuestionItAnswered() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        let suggestion = TaskAssistantSuggestion(
            title: fixture.task.title,
            subtitle: "Today",
            action: .open(task: fixture.task)
        )
        sut.messages = [TaskAssistantMessage(role: .assistant, text: "Which task?")]
        sut.pendingClarification = TaskAssistantClarification(message: "Which task?", suggestions: [suggestion])

        sut.cancelPendingAction()

        #expect(sut.pendingClarification == nil)
        #expect(sut.messages.isEmpty)
    }

    @Test
    func choosingClarificationSuggestionCreatesConfirmationAndClearsClarification() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        let suggestion = TaskAssistantSuggestion(
            title: fixture.task.title,
            subtitle: "Today",
            action: .open(task: fixture.task)
        )
        sut.pendingClarification = TaskAssistantClarification(message: "Which task?", suggestions: [suggestion])

        sut.chooseSuggestion(suggestion)

        let confirmation = try #require(sut.pendingConfirmation)
        #expect(sut.pendingClarification == nil)
        #expect(confirmation.title == fixture.task.title)
        #expect(confirmation.message == String(localized: .taskAssistantConfirmOpenMessage(fixture.task.title)))
    }

    @Test
    func sendingBareCatNameCreatesIntentSelectionWhenCommandIsAmbiguous() async throws {
        let fixture = try makeFixture()
        let schedule = CareTaskSchedule(
            scheduledDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            frequency: .daily
        )
        schedule.task = fixture.task
        fixture.task.schedules = [schedule]
        fixture.container.mainContext.insert(schedule)
        try fixture.container.mainContext.save()

        let sut = TaskAssistantViewModel()
        sut.draftText = "Luna"

        await sut.sendCurrentDraft(tasks: [fixture.task])

        let selection = try #require(sut.pendingIntentSelection)
        #expect(selection.task === fixture.task)
        #expect(sut.pendingConfirmation == nil)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantIntentPrompt(fixture.task.title)))
    }

    @Test
    func choosingTaskChoiceCreatesIntentSelectionAndClearsDisambiguation() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        let choice = TaskAssistantTaskChoice(task: fixture.task, selectedCats: [])
        sut.pendingTaskDisambiguation = TaskAssistantTaskDisambiguation(
            message: "Found a few matching tasks — which one?",
            choices: [choice],
            completedForDate: nil,
            notes: nil
        )

        sut.chooseTaskChoice(choice)

        let selection = try #require(sut.pendingIntentSelection)
        #expect(sut.pendingTaskDisambiguation == nil)
        #expect(selection.task === fixture.task)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantIntentPrompt(fixture.task.title)))
    }

    @Test
    func choosingOpenIntentCreatesConfirmationAndClearsIntentSelection() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.pendingIntentSelection = TaskAssistantIntentSelection(
            task: fixture.task,
            selectedCats: [],
            completedForDate: nil,
            notes: nil
        )

        sut.chooseIntent(.open)

        let confirmation = try #require(sut.pendingConfirmation)
        #expect(sut.pendingIntentSelection == nil)
        guard case .open(let task) = confirmation.action else {
            Issue.record("Expected an open action.")
            return
        }
        #expect(task === fixture.task)
        #expect(confirmation.message == String(localized: .taskAssistantConfirmOpenMessage(fixture.task.title)))
    }

    @Test
    func choosingCompleteIntentBuildsCompleteAction() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.pendingIntentSelection = TaskAssistantIntentSelection(
            task: fixture.task,
            selectedCats: [],
            completedForDate: nil,
            notes: nil
        )

        sut.chooseIntent(.complete)

        let confirmation = try #require(sut.pendingConfirmation)
        guard case .complete(let task, _, _, _) = confirmation.action else {
            Issue.record("Expected a complete action.")
            return
        }
        #expect(task === fixture.task)
    }

    @Test
    func choosingPostponeIntentDefaultsToThirtyMinutes() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.pendingIntentSelection = TaskAssistantIntentSelection(
            task: fixture.task,
            selectedCats: [],
            completedForDate: nil,
            notes: nil
        )

        sut.chooseIntent(.postpone)

        let confirmation = try #require(sut.pendingConfirmation)
        guard case .postpone(let task, let minutes) = confirmation.action else {
            Issue.record("Expected a postpone action.")
            return
        }
        #expect(task === fixture.task)
        #expect(minutes == 30)
    }

    @Test
    func choosingCompleteOrPostponeIntentForACompletedTaskIsIgnored() throws {
        let fixture = try makeFixture()
        fixture.task.status = .completed
        let sut = TaskAssistantViewModel()
        sut.pendingIntentSelection = TaskAssistantIntentSelection(
            task: fixture.task,
            selectedCats: [],
            completedForDate: nil,
            notes: nil
        )

        sut.chooseIntent(.complete)

        #expect(sut.pendingConfirmation == nil)
        #expect(sut.pendingIntentSelection != nil)

        sut.chooseIntent(.postpone)

        #expect(sut.pendingConfirmation == nil)
        #expect(sut.pendingIntentSelection != nil)
    }

    @Test
    func choosingOpenIntentForACompletedTaskStillWorks() throws {
        let fixture = try makeFixture()
        fixture.task.status = .completed
        let sut = TaskAssistantViewModel()
        sut.pendingIntentSelection = TaskAssistantIntentSelection(
            task: fixture.task,
            selectedCats: [],
            completedForDate: nil,
            notes: nil
        )

        sut.chooseIntent(.open)

        let confirmation = try #require(sut.pendingConfirmation)
        #expect(sut.pendingIntentSelection == nil)
        guard case .open(let task) = confirmation.action else {
            Issue.record("Expected an open action.")
            return
        }
        #expect(task === fixture.task)
    }

    @Test
    func cancellingTaskDisambiguationRemovesTheQuestionItAnswered() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        let choice = TaskAssistantTaskChoice(task: fixture.task, selectedCats: [])
        sut.messages = [TaskAssistantMessage(role: .assistant, text: "Found a few matching tasks — which one?")]
        sut.pendingTaskDisambiguation = TaskAssistantTaskDisambiguation(
            message: "Found a few matching tasks — which one?",
            choices: [choice],
            completedForDate: nil,
            notes: nil
        )

        sut.cancelPendingAction()

        #expect(sut.pendingTaskDisambiguation == nil)
        #expect(sut.messages.isEmpty)
    }

    @Test
    func cancellingIntentSelectionRemovesTheQuestionItAnswered() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.messages = [TaskAssistantMessage(role: .assistant, text: "What would you like to do?")]
        sut.pendingIntentSelection = TaskAssistantIntentSelection(
            task: fixture.task,
            selectedCats: [],
            completedForDate: nil,
            notes: nil
        )

        sut.cancelPendingAction()

        #expect(sut.pendingIntentSelection == nil)
        #expect(sut.messages.isEmpty)
    }

    @Test
    func revalidationClearsIntentSelectionForDeletedTask() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.messages = [TaskAssistantMessage(role: .assistant, text: "What would you like to do?")]
        sut.pendingIntentSelection = TaskAssistantIntentSelection(
            task: fixture.task,
            selectedCats: [],
            completedForDate: nil,
            notes: nil
        )

        sut.revalidatePendingActions(against: [])

        #expect(sut.pendingIntentSelection == nil)
        #expect(sut.messages.isEmpty)
    }

    @Test
    func revalidationKeepsOnlyTaskDisambiguationChoicesForAvailableTasks() throws {
        let fixture = try makeFixture()
        let deletedTask = CareTask(title: "Deleted Task", category: .general)
        fixture.container.mainContext.insert(deletedTask)
        try fixture.container.mainContext.save()
        let sut = TaskAssistantViewModel()
        sut.pendingTaskDisambiguation = TaskAssistantTaskDisambiguation(
            message: "Which task?",
            choices: [
                TaskAssistantTaskChoice(task: fixture.task, selectedCats: []),
                TaskAssistantTaskChoice(task: deletedTask, selectedCats: [])
            ],
            completedForDate: nil,
            notes: nil
        )

        fixture.container.mainContext.delete(deletedTask)
        try fixture.container.mainContext.save()
        sut.revalidatePendingActions(against: [fixture.task])

        let disambiguation = try #require(sut.pendingTaskDisambiguation)
        #expect(disambiguation.choices.count == 1)
        #expect(disambiguation.choices.first?.task === fixture.task)
    }

    @Test
    func revalidationClearsConfirmationForDeletedTask() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.messages = [TaskAssistantMessage(role: .assistant, text: "Open task?")]
        sut.pendingConfirmation = TaskAssistantConfirmation(
            title: fixture.task.title,
            message: "Open task?",
            action: .open(task: fixture.task)
        )

        fixture.container.mainContext.delete(fixture.task)
        try fixture.container.mainContext.save()
        sut.revalidatePendingActions(against: [])

        #expect(sut.pendingConfirmation == nil)
        #expect(sut.messages.isEmpty)
    }

    @Test
    func revalidationClearsCompletionForTaskCompletedElsewhere() throws {
        let fixture = try makeFixture()
        let sut = TaskAssistantViewModel()
        sut.messages = [TaskAssistantMessage(role: .assistant, text: "Complete task?")]
        sut.pendingConfirmation = TaskAssistantConfirmation(
            title: fixture.task.title,
            message: "Complete task?",
            action: .complete(task: fixture.task, completedForDate: nil, notes: nil, cats: [])
        )

        fixture.task.status = .completed
        fixture.task.updatedAt = Date()
        sut.revalidatePendingActions(against: [fixture.task])

        #expect(sut.pendingConfirmation == nil)
        #expect(sut.messages.isEmpty)
    }

    @Test
    func revalidationKeepsOnlyClarificationSuggestionsForAvailableTasks() throws {
        let fixture = try makeFixture()
        let deletedTask = CareTask(title: "Deleted Task", category: .general)
        fixture.container.mainContext.insert(deletedTask)
        try fixture.container.mainContext.save()
        let sut = TaskAssistantViewModel()
        sut.pendingClarification = TaskAssistantClarification(
            message: "Which task?",
            suggestions: [
                TaskAssistantSuggestion(
                    title: fixture.task.title,
                    subtitle: "Today",
                    action: .open(task: fixture.task)
                ),
                TaskAssistantSuggestion(
                    title: deletedTask.title,
                    subtitle: "Today",
                    action: .open(task: deletedTask)
                )
            ]
        )

        fixture.container.mainContext.delete(deletedTask)
        try fixture.container.mainContext.save()
        sut.revalidatePendingActions(against: [fixture.task])

        let clarification = try #require(sut.pendingClarification)
        #expect(clarification.suggestions.count == 1)
        #expect(clarification.suggestions.first?.task === fixture.task)
    }

    @Test
    func deniedSpeechPermissionKeepsDictationIdleAndExplainsHowToEnableIt() async {
        let speechService = FakeSpeechRecognitionService()
        speechService.grantsPermission = false
        let sut = TaskAssistantViewModel(speechService: speechService)

        await sut.startDictation()

        #expect(sut.isRecording == false)
        #expect(speechService.startCallCount == 0)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantVoicePermissionDenied))
    }

    @Test(arguments: [
        SpeechRecognitionServiceError.recognizerUnavailable,
        SpeechRecognitionServiceError.audioEngineStartFailed
    ])
    func dictationStartupFailureRestoresIdleState(error: SpeechRecognitionServiceError) async {
        let speechService = FakeSpeechRecognitionService()
        speechService.startError = error
        let sut = TaskAssistantViewModel(speechService: speechService)

        await sut.startDictation()

        #expect(sut.isRecording == false)
        #expect(speechService.stopCallCount == 1)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantVoiceUnavailable))
    }

    @Test
    func partialAndFinalTranscriptsUpdateDraftAndFinishRecording() async {
        let speechService = FakeSpeechRecognitionService()
        let sut = TaskAssistantViewModel(speechService: speechService)

        await sut.startDictation()
        speechService.emitTranscript("Feed", isFinal: false)

        #expect(sut.isRecording)
        #expect(sut.draftText == "Feed")

        speechService.emitTranscript("Feed Luna", isFinal: true)

        #expect(sut.isRecording == false)
        #expect(sut.draftText == "Feed Luna")
    }

    @Test
    func asynchronousRecognitionFailureRestoresIdleState() async {
        let speechService = FakeSpeechRecognitionService()
        let sut = TaskAssistantViewModel(speechService: speechService)

        await sut.startDictation()
        speechService.emitFailure()

        #expect(sut.isRecording == false)
        #expect(speechService.stopCallCount == 1)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantVoiceUnavailable))
    }

    @Test
    func manualStopEndsActiveRecording() async {
        let speechService = FakeSpeechRecognitionService()
        let sut = TaskAssistantViewModel(speechService: speechService)

        await sut.startDictation()
        sut.stopDictation()

        #expect(sut.isRecording == false)
        #expect(speechService.stopCallCount == 1)
    }

    private func freshUserDefaults(cloudConsentGranted: Bool? = nil) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "TaskAssistantViewModelTests.\(UUID().uuidString)")!
        if let cloudConsentGranted {
            defaults.set(cloudConsentGranted, forKey: SettingsPreferences.taskAssistantCloudConsentGrantedKey)
        }
        return defaults
    }

    private func makeFixture() throws -> (container: ModelContainer, task: CareTask) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let cat = Cat(name: "Luna")
        let task = CareTask(title: "Feed Luna", category: .feeding)
        task.assignedCats = [cat]

        context.insert(cat)
        context.insert(task)
        try context.save()

        return (container, task)
    }

    // MARK: - Create a task flow

    @Test
    func beginTaskCreationStartsAtNameStepAndAsksForName() throws {
        let fixture = try makeCatFixture()
        let sut = TaskAssistantViewModel()

        sut.beginTaskCreation(cats: [fixture.cat])

        #expect(sut.taskCreationSession?.step == .name)
        #expect(sut.messages.last?.role == .assistant)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantCreateAskName))
    }

    @Test
    func submittingNameAdvancesToCatsWhenCatsExist() throws {
        let fixture = try makeCatFixture()
        let sut = TaskAssistantViewModel()
        sut.beginTaskCreation(cats: [fixture.cat])

        sut.submitCreationName("Brush Luna")

        #expect(sut.taskCreationSession?.title == "Brush Luna")
        #expect(sut.taskCreationSession?.step == .cats)
    }

    @Test
    func nameStepSkipsCatsWhenNoCatsExist() throws {
        let sut = TaskAssistantViewModel()
        sut.beginTaskCreation(cats: [])

        sut.submitCreationName("Buy litter")

        #expect(sut.taskCreationSession?.step == .category)
    }

    @Test
    func typingDuringAChipStepNudgesInsteadOfAdvancing() async throws {
        let fixture = try makeCatFixture()
        let sut = TaskAssistantViewModel()
        sut.beginTaskCreation(cats: [fixture.cat])
        sut.submitCreationName("Brush Luna")  // now on .cats (a chip step)

        sut.draftText = "daily"
        await sut.sendCurrentDraft(tasks: [])

        #expect(sut.taskCreationSession?.step == .cats)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantCreatePickOption))
    }

    @Test
    func walkingEveryStepBuildsTheExpectedDraft() throws {
        let fixture = try makeCatFixture()
        let sut = TaskAssistantViewModel()

        sut.beginTaskCreation(cats: [fixture.cat])
        sut.submitCreationName("Brush Luna")
        sut.toggleCreationCat(fixture.cat)
        sut.confirmCreationCats()
        sut.selectCreationCategory(.grooming)
        sut.selectCreationFrequency(.daily)
        sut.selectCreationTime(.morning)

        let session = try #require(sut.taskCreationSession)
        #expect(session.step == .confirm)
        let draft = session.makeDraft()
        #expect(draft.title == "Brush Luna")
        #expect(draft.assignedCats.map(\.id) == [fixture.cat.id])
        #expect(draft.category == .grooming)
        #expect(draft.frequency == .daily)
        #expect(draft.scheduledTime != nil)
        #expect(draft.reminderMinutes == 0)
    }

    @Test
    func confirmTaskCreationPersistsTaskAndClearsSession() async throws {
        let fixture = try makeCatFixture()
        let sut = TaskAssistantViewModel()

        sut.beginTaskCreation(cats: [fixture.cat])
        sut.submitCreationName("Brush Luna")
        sut.toggleCreationCat(fixture.cat)
        sut.confirmCreationCats()
        sut.selectCreationCategory(.grooming)
        sut.selectCreationFrequency(.daily)
        sut.selectCreationTime(.morning)

        await sut.confirmTaskCreation(in: fixture.container.mainContext, existingCaregivers: [])

        #expect(sut.taskCreationSession == nil)
        #expect(sut.messages.last?.text == String(localized: .taskAssistantCreateSuccess("Brush Luna")))

        let tasks = try fixture.container.mainContext.fetch(FetchDescriptor<CareTask>())
        let created = try #require(tasks.first(where: { $0.title == "Brush Luna" }))
        #expect(created.category == .grooming)
        #expect(created.assignedCats.map(\.id) == [fixture.cat.id])
        let schedule = try #require(created.schedules.first)
        #expect(schedule.frequency == .daily)
        #expect(schedule.scheduledTime != nil)
        #expect(schedule.reminderMinutes == 0)
    }

    @Test
    func confirmTaskCreationWorksWithNoCats() async throws {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let sut = TaskAssistantViewModel()

        sut.beginTaskCreation(cats: [])
        sut.submitCreationName("Buy litter")   // skips cats → category
        sut.selectCreationCategory(.litter)
        sut.selectCreationFrequency(.once)
        sut.selectCreationTime(.none)

        await sut.confirmTaskCreation(in: container.mainContext, existingCaregivers: [])

        let tasks = try container.mainContext.fetch(FetchDescriptor<CareTask>())
        let created = try #require(tasks.first(where: { $0.title == "Buy litter" }))
        #expect(created.assignedCats.isEmpty)
        #expect(created.schedules.first?.frequency == .once)
        #expect(created.schedules.first?.scheduledTime == nil)
        #expect(created.schedules.first?.reminderMinutes == nil)
    }

    @Test
    func cancelTaskCreationClearsSession() throws {
        let fixture = try makeCatFixture()
        let sut = TaskAssistantViewModel()
        sut.beginTaskCreation(cats: [fixture.cat])

        sut.cancelTaskCreation()

        #expect(sut.taskCreationSession == nil)
    }

    @Test
    func endChatClearsCreationSession() throws {
        let fixture = try makeCatFixture()
        let sut = TaskAssistantViewModel()
        sut.beginTaskCreation(cats: [fixture.cat])

        sut.endChat()

        #expect(sut.taskCreationSession == nil)
        #expect(sut.messages.isEmpty)
    }

    private func makeCatFixture() throws -> (container: ModelContainer, cat: Cat) {
        let container = try TestModelContainerFactory.makeInMemoryContainer()
        let context = container.mainContext

        let cat = Cat(name: "Luna")
        context.insert(cat)
        try context.save()

        return (container, cat)
    }
}
