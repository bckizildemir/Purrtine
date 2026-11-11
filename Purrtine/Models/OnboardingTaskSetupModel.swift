import Foundation
import os
import SwiftData

/// Owns the onboarding finish step: it saves the first cat and its starter tasks, then marks
/// onboarding complete. `OnboardingView` holds one as `@State`, renders it, and calls `finish()`.
@MainActor
@Observable
final class OnboardingTaskSetupModel {
    enum FinishOutcome: Equatable {
        case completed
        case notSaved
        /// Another `finish()` was already running, so this call did nothing.
        case alreadyFinishing
    }

    /// What the Task Setup step should tell the caregiver about reminders, derived fresh from the
    /// notification manager's authorization status and the current task selection every time it is
    /// read — never stored, so it tracks a status change with no model rebuild.
    enum ReminderPrompt: Equatable {
        /// Nothing selected, or the current status already allows reminders.
        case none
        /// Permission was never asked, or the caregiver skipped that step.
        case askAgain
        /// Permission was asked and denied.
        case openSettings
    }

    /// True while `finish()` saves, so a second tap on Continue cannot create a second cat.
    private(set) var isFinishing = false
    /// True after a finish that saved nothing, while the caregiver chooses to retry or to continue
    /// without saving. Settable so the alert can dismiss itself.
    var isShowingSaveFailure = false

    private let notificationManager: NotificationManager
    private let taskWriter: any CareTaskWriting
    private let modelContext: ModelContext
    private let onboardingManager: OnboardingManager
    private let logger = Logger(
        subsystem: "com.berkecankizildemir.CatCareCalendar",
        category: "Onboarding"
    )

    init(
        notificationManager: NotificationManager,
        taskWriter: any CareTaskWriting,
        modelContext: ModelContext,
        onboardingManager: OnboardingManager
    ) {
        self.notificationManager = notificationManager
        self.taskWriter = taskWriter
        self.modelContext = modelContext
        self.onboardingManager = onboardingManager
    }

    /// Completes onboarding unless nothing was saved. Then onboarding stays on Task Setup with the
    /// caregiver's answers in place and `isShowingSaveFailure` set.
    ///
    /// A retry is safe: a failed first commit takes the cat and every starter task back out of the
    /// context (see `OnboardingDataBuilder`), so the next attempt cannot save a second cat.
    @discardableResult
    func finish() async -> FinishOutcome {
        guard isFinishing == false else { return .alreadyFinishing }
        isFinishing = true
        defer { isFinishing = false }
        // Cleared per attempt, so a second failure sets the flag again rather than leaving it
        // `true` over `true`, which SwiftUI would not see as a change.
        isShowingSaveFailure = false

        let outcome = await saveCatAndTasks()
        if outcome == .notSaved {
            isShowingSaveFailure = true
        } else {
            onboardingManager.completeOnboarding()
        }
        return outcome
    }

    /// The save-failure alert's "Try again": the same answers, saved again.
    @discardableResult
    func retry() async -> FinishOutcome {
        await finish()
    }

    /// The save-failure alert's "Continue without saving": onboarding ends with nothing saved.
    func continueWithoutSaving() {
        isShowingSaveFailure = false
        onboardingManager.completeOnboarding()
    }

    /// What the Task Setup step's reminder row should say right now. Reads the notification
    /// manager's authorization status live, so it needs no observer or reset when that status
    /// changes — including a return from iOS Settings, which re-checks the status on activation.
    var reminderPrompt: ReminderPrompt {
        guard onboardingManager.selectedTasks.isEmpty == false,
              notificationManager.authorizationStatus.allowsReminderConfiguration == false else {
            return .none
        }
        return notificationManager.authorizationStatus == .denied ? .openSettings : .askAgain
    }

    /// The reminder row's "Allow Notifications": the same system prompt the permission step uses,
    /// so a grant fires the existing resync.
    @discardableResult
    func requestNotificationPermission() async -> Bool {
        await notificationManager.requestPermission()
    }

    private func saveCatAndTasks() async -> FinishOutcome {
        do {
            try await OnboardingDataBuilder(taskWriter: taskWriter).createCatAndTasks(
                from: onboardingManager.tempCatData,
                selectedTasks: onboardingManager.selectedTasks,
                in: modelContext
            )
            return .completed
        } catch is CancellationError {
            // The data may already be saved. Any reminders not yet scheduled stay stale until the
            // task is next written or a notification setting changes.
            return .completed
        } catch let error as CareTaskRemindersOutOfSyncError {
            // Saved, reminders stale. Not an onboarding failure: the cat and its tasks stand, and one
            // full resync rebuilds every reminder from the store, so no UI is needed.
            logger.error(
                "Onboarding saved, reminders stale: \(String(describing: error.underlyingError), privacy: .public)"
            )
            notificationManager.requestFullReminderResync()
            return .completed
        } catch {
            logger.error("Onboarding data not saved: \(String(describing: error), privacy: .public)")
            return .notSaved
        }
    }
}
