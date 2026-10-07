import SwiftUI

/// The Task Setup step of onboarding: `TaskSetupView`, driven by the onboarding Task Setup model.
/// A finish that saved nothing keeps the caregiver here and shows the save-failure alert.
struct OnboardingTaskSetupStep: View {
    @Bindable var model: OnboardingTaskSetupModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        TaskSetupView(
            reminderPrompt: model.reminderPrompt,
            onAllowNotifications: {
                Task {
                    await model.requestNotificationPermission()
                }
            },
            onOpenNotificationSettings: {
                guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                openURL(url)
            },
            onContinue: {
                Task {
                    await model.finish()
                }
            }
        )
        .alert(String(localized: .onboardingSaveFailureTitle), isPresented: $model.isShowingSaveFailure) {
            Button(String(localized: .onboardingSaveFailureTryAgain)) {
                Task {
                    await model.retry()
                }
            }
            Button(String(localized: .onboardingSaveFailureContinueWithoutSaving), role: .destructive) {
                model.continueWithoutSaving()
            }
        } message: {
            Text(.onboardingSaveFailureMessage)
        }
    }
}
