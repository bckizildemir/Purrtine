import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import CatCareCalendar

/// Drives the onboarding finish step through its one seam, with the real onboarding data builder,
/// the real care task writer, and a real notification manager on the fake notification center.
@MainActor
struct OnboardingTaskSetupModelTests {
    let container: ModelContainer
    let center = FakeUserNotificationCenterClient()
    let notificationManager: NotificationManager
    let onboardingManager: OnboardingManager

    init() throws {
        container = try TestModelContainerFactory.makeInMemoryContainer()
        CaregiverBootstrapper.ensureDefaultCaregiverExists(in: container.mainContext)

        let suiteName = "OnboardingTaskSetupModelTests.\(UUID().uuidString)"
        let settingsDefaults = try #require(UserDefaults(suiteName: "\(suiteName).settings"))
        let onboardingDefaults = try #require(UserDefaults(suiteName: "\(suiteName).onboarding"))
        notificationManager = NotificationManager(
            notificationCenter: center,
            settingsStore: NotificationSettingsStore(userDefaults: settingsDefaults, key: "settings")
        )
        // Wired as `CatCareCalendarApp` wires it, so the writer's full resync reads this store.
        let resyncCoordinator = NotificationResyncCoordinator(
            modelContainer: container,
            notificationManager: notificationManager
        )
        notificationManager.onFullResyncAwaited = { try await resyncCoordinator.resync() }
        onboardingManager = OnboardingManager(userDefaults: onboardingDefaults)
        onboardingManager.tempCatData.name = "Mochi"
        onboardingManager.selectedTasks = [.feeding, .water, .litterBox]
    }

    @Test
    func goodSaveWithPermissionGrantedCompletesWithRemindersForEveryStarterTask() async throws {
        await grantPermission()
        let sut = makeSUT()

        let outcome = await sut.finish()

        let tasks = try container.mainContext.fetch(FetchDescriptor<CareTask>())
        #expect(outcome == .completed)
        #expect(onboardingManager.hasCompletedOnboarding)
        #expect(tasks.count == 3)
        for task in tasks {
            #expect(
                center.addedRequests.contains { $0.identifier.hasPrefix(task.id.uuidString) },
                "No pending reminder for \(task.title)"
            )
        }
    }

    @Test
    func savedWithReminderFailureCompletesAndRequestsOneFullResync() async throws {
        await grantPermission()
        var fullResyncRequestCount = 0
        notificationManager.onFullResyncRequested = { fullResyncRequestCount += 1 }
        center.addError = ReminderFailure.addRejected
        let sut = makeSUT()

        let outcome = await sut.finish()

        let cats = try container.mainContext.fetch(FetchDescriptor<Cat>())
        let tasks = try container.mainContext.fetch(FetchDescriptor<CareTask>())
        #expect(outcome == .completed)
        #expect(onboardingManager.hasCompletedOnboarding)
        #expect(cats.map(\.name) == ["Mochi"])
        #expect(tasks.count == 3)
        #expect(fullResyncRequestCount == 1)
    }

    @Test(.timeLimit(.minutes(1)))
    func secondFinishIsIgnoredWhileOneRuns() async throws {
        await grantPermission()
        let scheduleStarted = Gate()
        let scheduleRelease = Gate()
        center.addHandler = {
            scheduleStarted.open()
            await scheduleRelease.wait()
        }
        let sut = makeSUT()

        let firstFinish = Task { await sut.finish() }
        await scheduleStarted.wait()
        #expect(sut.isFinishing)

        let secondOutcome = await sut.finish()
        scheduleRelease.open()
        let firstOutcome = await firstFinish.value

        let cats = try container.mainContext.fetch(FetchDescriptor<Cat>())
        #expect(secondOutcome == .alreadyFinishing)
        #expect(firstOutcome == .completed)
        #expect(sut.isFinishing == false)
        #expect(cats.count == 1)
    }

    @Test
    func failedCommitKeepsTheCaregiverInOnboardingWithTheAlertUp() async throws {
        let sut = makeFailingSUT()

        let outcome = await sut.finish()

        #expect(outcome == .notSaved)
        #expect(onboardingManager.hasCompletedOnboarding == false)
        #expect(try container.mainContext.fetch(FetchDescriptor<Cat>()).isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<CareTask>()).isEmpty)
        #expect(sut.isFinishing == false)
        #expect(sut.isShowingSaveFailure)
    }

    @Test
    func retryAfterAFailedCommitSavesExactlyOneCatAndOneSetOfStarterTasks() async throws {
        var shouldFailCommit = true
        let sut = makeSUT(taskWriter: CareTaskWriter(
            scheduler: notificationManager,
            saveContext: { context in
                guard shouldFailCommit == false else { throw CommitFailure.diskFull }
                try context.save()
            }
        ))
        await sut.finish()
        shouldFailCommit = false

        let outcome = await sut.retry()

        let cats = try container.mainContext.fetch(FetchDescriptor<Cat>())
        let tasks = try container.mainContext.fetch(FetchDescriptor<CareTask>())
        #expect(outcome == .completed)
        #expect(onboardingManager.hasCompletedOnboarding)
        #expect(cats.map(\.name) == ["Mochi"])
        #expect(tasks.count == 3)
        #expect(Set(tasks.map(\.title)).count == 3)
        #expect(sut.isShowingSaveFailure == false)
    }

    @Test
    func aSecondFailedCommitShowsTheAlertAgainAndStillSavesNothing() async throws {
        let sut = makeFailingSUT()
        await sut.finish()

        let outcome = await sut.retry()

        #expect(outcome == .notSaved)
        #expect(onboardingManager.hasCompletedOnboarding == false)
        #expect(try container.mainContext.fetch(FetchDescriptor<Cat>()).isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<CareTask>()).isEmpty)
        #expect(sut.isFinishing == false)
        #expect(sut.isShowingSaveFailure)
    }

    @Test
    func continueWithoutSavingAfterAFailedCommitCompletesWithNothingSaved() async throws {
        let sut = makeFailingSUT()
        await sut.finish()
        try #require(onboardingManager.hasCompletedOnboarding == false)

        sut.continueWithoutSaving()

        // A later save of the same context must not commit anything the failed finish staged.
        try container.mainContext.save()
        #expect(onboardingManager.hasCompletedOnboarding)
        #expect(try container.mainContext.fetch(FetchDescriptor<Cat>()).isEmpty)
        #expect(try container.mainContext.fetch(FetchDescriptor<CareTask>()).isEmpty)
        #expect(sut.isShowingSaveFailure == false)
    }

    @Test(
        arguments: [
            (UNAuthorizationStatus.notDetermined, true, OnboardingTaskSetupModel.ReminderPrompt.askAgain),
            (UNAuthorizationStatus.denied, true, OnboardingTaskSetupModel.ReminderPrompt.openSettings),
            (UNAuthorizationStatus.authorized, true, OnboardingTaskSetupModel.ReminderPrompt.none),
            (UNAuthorizationStatus.denied, false, OnboardingTaskSetupModel.ReminderPrompt.none)
        ]
    )
    func reminderPromptReflectsAuthorizationStatusAndTaskSelection(
        status: UNAuthorizationStatus,
        hasTaskSelected: Bool,
        expected: OnboardingTaskSetupModel.ReminderPrompt
    ) {
        notificationManager.authorizationStatus = status
        if hasTaskSelected == false {
            onboardingManager.selectedTasks = []
        }
        let sut = makeSUT()

        #expect(sut.reminderPrompt == expected)
    }

    @Test
    func reminderPromptBecomesNoneAfterAStatusChangeWithNoModelRebuild() throws {
        notificationManager.authorizationStatus = .denied
        let sut = makeSUT()
        try #require(sut.reminderPrompt == .openSettings)

        notificationManager.authorizationStatus = .authorized

        #expect(sut.reminderPrompt == .none)
    }

    @Test
    func requestNotificationPermissionDelegatesToTheNotificationManager() async {
        center.requestAuthorizationResult = true
        let sut = makeSUT()

        let granted = await sut.requestNotificationPermission()

        #expect(granted)
        #expect(notificationManager.authorizationStatus == .authorized)
    }

    // MARK: - Helpers

    private func grantPermission() async {
        center.requestAuthorizationResult = true
        _ = await notificationManager.requestPermission()
    }

    /// Every commit fails, as on a full disk.
    private func makeFailingSUT() -> OnboardingTaskSetupModel {
        makeSUT(taskWriter: CareTaskWriter(
            scheduler: notificationManager,
            saveContext: { _ in throw CommitFailure.diskFull }
        ))
    }

    private func makeSUT(taskWriter: (any CareTaskWriting)? = nil) -> OnboardingTaskSetupModel {
        OnboardingTaskSetupModel(
            notificationManager: notificationManager,
            taskWriter: taskWriter ?? CareTaskWriter(scheduler: notificationManager),
            modelContext: container.mainContext,
            onboardingManager: onboardingManager
        )
    }
}

private enum ReminderFailure: Error {
    case addRejected
}

private enum CommitFailure: Error {
    case diskFull
}

/// A one-shot signal: `wait()` returns once `open()` has been called, however many callers wait.
@MainActor
private final class Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard isOpen == false else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        waiters.forEach { $0.resume() }
        waiters = []
    }
}
